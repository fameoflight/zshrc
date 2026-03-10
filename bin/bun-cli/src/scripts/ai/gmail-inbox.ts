import path from "path";
import os from "os";
import { mkdir, rm } from "fs/promises";
import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";

interface GmailCredentials {
  installed?: {
    client_id: string;
    client_secret: string;
    token_uri?: string;
  };
  web?: {
    client_id: string;
    client_secret: string;
    token_uri?: string;
  };
}

interface GmailToken {
  access_token?: string;
  refresh_token?: string;
  expiry_date?: number;
}

@Script({
  emoji: "📥",
  tags: ["gmail", "email", "google"],
  args: {
    limit: {
      type: "integer",
      flag: "-l, --limit",
      default: 10,
      description: "Number of recent messages to list",
    },
    setup: {
      type: "boolean",
      flag: "-s, --setup",
      description: "Show setup instructions",
    },
    resetAuth: {
      type: "boolean",
      flag: "--reset-auth",
      description: "Delete the stored token file",
    },
    summaryOnly: {
      type: "boolean",
      flag: "--summary",
      description: "Show inbox summary only",
    },
    credentialsFile: {
      type: "string",
      flag: "--credentials-file",
      description: "Path to Google OAuth client credentials JSON",
    },
    tokenFile: {
      type: "string",
      flag: "--token-file",
      description: "Path to OAuth token JSON",
    },
  },
})
export class GmailInbox extends ScriptBase {
  async run(ctx: Context): Promise<void> {
    this.logger.banner("Gmail Inbox");

    if (ctx.args.setup) {
      this.showSetupInstructions(this.resolveCredentialsFile(ctx));
      return;
    }

    const tokenFile = this.resolveTokenFile(ctx);
    if (ctx.args.resetAuth) {
      await rm(tokenFile, { force: true });
      this.logger.success(`Removed token file: ${tokenFile}`);
      return;
    }

    const accessToken = await this.getAccessToken(ctx);

    if (ctx.args.summaryOnly) {
      await this.showSummary(accessToken);
      return;
    }

    await this.showSummary(accessToken);
    await this.showRecentMessages(accessToken, ctx.args.limit);
  }

  private async showSummary(accessToken: string): Promise<void> {
    const inboxLabel = await this.gmailRequest("/users/me/labels/INBOX", accessToken);
    const unreadLabel = await this.gmailRequest("/users/me/labels/UNREAD", accessToken);

    console.log(`Inbox total: ${inboxLabel.messagesTotal ?? "unknown"}`);
    console.log(`Inbox unread: ${unreadLabel.messagesUnread ?? "unknown"}`);
  }

  private async showRecentMessages(accessToken: string, limit: number): Promise<void> {
    const response = await this.gmailRequest(
      `/users/me/messages?labelIds=INBOX&maxResults=${limit}`,
      accessToken
    );

    const messages = response.messages || [];
    if (messages.length === 0) {
      this.logger.info("No inbox messages found.");
      return;
    }

    console.log("\nRecent messages:");
    for (const message of messages) {
      const detail = await this.gmailRequest(
        `/users/me/messages/${message.id}?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=Date`,
        accessToken
      );
      const headers = new Map<string, string>();
      for (const header of detail.payload?.headers || []) {
        headers.set(header.name, header.value);
      }

      console.log(`- ${headers.get("Date") || "Unknown date"}`);
      console.log(`  From: ${headers.get("From") || "Unknown sender"}`);
      console.log(`  Subject: ${headers.get("Subject") || "(no subject)"}`);
      if (detail.snippet) {
        console.log(`  Snippet: ${detail.snippet}`);
      }
    }
  }

  private async getAccessToken(ctx: Context): Promise<string> {
    if (process.env.GMAIL_ACCESS_TOKEN) {
      return process.env.GMAIL_ACCESS_TOKEN;
    }

    const tokenFile = this.resolveTokenFile(ctx);
    const credentialsFile = this.resolveCredentialsFile(ctx);

    if (!(await this.fs.exists(tokenFile))) {
      throw new Error(
        `No Gmail token file found at ${tokenFile}. Use --setup and create a token file with a refresh_token.`
      );
    }

    const token = JSON.parse(await this.fs.readFile(tokenFile)) as GmailToken;
    if (token.access_token && token.expiry_date && token.expiry_date > Date.now() + 60_000) {
      return token.access_token;
    }

    if (!token.refresh_token) {
      throw new Error(`Token file ${tokenFile} does not contain a refresh_token.`);
    }

    if (!(await this.fs.exists(credentialsFile))) {
      throw new Error(`Credentials file not found: ${credentialsFile}`);
    }

    const credentials = JSON.parse(await this.fs.readFile(credentialsFile)) as GmailCredentials;
    const oauth = credentials.installed || credentials.web;
    if (!oauth) {
      throw new Error(`Could not parse client credentials from ${credentialsFile}`);
    }

    const refreshResponse = await fetch(oauth.token_uri || "https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: oauth.client_id,
        client_secret: oauth.client_secret,
        refresh_token: token.refresh_token,
        grant_type: "refresh_token",
      }),
    });

    if (!refreshResponse.ok) {
      throw new Error(`Failed to refresh Gmail token: ${refreshResponse.status} ${refreshResponse.statusText}`);
    }

    const refreshed = await refreshResponse.json();
    const nextToken: GmailToken = {
      ...token,
      access_token: refreshed.access_token,
      expiry_date: Date.now() + (refreshed.expires_in || 3600) * 1000,
    };

    await mkdir(path.dirname(tokenFile), { recursive: true });
    await Bun.write(tokenFile, JSON.stringify(nextToken, null, 2) + "\n");
    return nextToken.access_token!;
  }

  private async gmailRequest(endpoint: string, accessToken: string): Promise<any> {
    const response = await fetch(`https://gmail.googleapis.com/gmail/v1${endpoint}`, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error(`Gmail API request failed: ${response.status} ${response.statusText}`);
    }

    return response.json();
  }

  private resolveCredentialsFile(ctx: Context): string {
    return path.resolve(
      (ctx.args.credentialsFile as string | undefined) ||
        process.env.GMAIL_CREDENTIALS_FILE ||
        path.join(process.cwd(), "credentials", "gmail.json")
    );
  }

  private resolveTokenFile(ctx: Context): string {
    return path.resolve(
      (ctx.args.tokenFile as string | undefined) ||
        process.env.GMAIL_TOKEN_FILE ||
        path.join(
          process.env.XDG_CONFIG_HOME || path.join(os.homedir(), ".config"),
          "zsh",
          "gmail",
          "token.json"
        )
    );
  }

  private showSetupInstructions(credentialsFile: string): void {
    console.log("Gmail Inbox Setup");
    console.log("");
    console.log("1. Enable Gmail API in Google Cloud Console.");
    console.log("2. Create an OAuth desktop client.");
    console.log(`3. Save the client JSON at: ${credentialsFile}`);
    console.log("4. Create a token JSON file containing a refresh_token.");
    console.log("   Default token path: ~/.config/zsh/gmail/token.json");
    console.log("5. Run gmail-inbox again.");
    console.log("");
    console.log("Token file format:");
    console.log(
      JSON.stringify(
        {
          refresh_token: "your-refresh-token",
          access_token: "optional-cached-access-token",
          expiry_date: 0,
        },
        null,
        2
      )
    );
  }
}
