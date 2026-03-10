import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { HomebrewService } from "../../core/services/HomebrewService";

interface PackageGroup {
  title: string;
  formulae?: string[];
  casks?: string[];
  postInstall?: () => Promise<void>;
}

const PACKAGE_GROUPS: Record<string, PackageGroup> = {
  "core-utils": {
    title: "core utilities",
    formulae: ["tree", "wget", "watch", "ripgrep", "fd", "bat", "eza", "htop", "jq", "yq"],
  },
  "dev-utils": {
    title: "development utilities",
    formulae: ["duti", "fswatch", "ssh-copy-id", "rmtrash", "sleepwatcher", "pkgconf", "dockutil", "librsvg"],
  },
  "modern-cli": {
    title: "modern CLI tools",
    formulae: ["zoxide", "starship", "fzf", "claude-code", "gemini-cli", "yt-dlp"],
    postInstall: async () => {
      if (Bun.which("claude")) {
        await Bun.$`sh -c ${"claude config set autoUpdates false >/dev/null 2>&1 || true"}`.quiet();
      }
    },
  },
  editors: {
    title: "editors and IDEs",
    formulae: ["vim", "neovim"],
    casks: ["visual-studio-code", "zed", "lm-studio"],
  },
};

/**
 * Install Homebrew packages for development categories
 *
 * @example
 * setup-dev-tools
 * setup-dev-tools core-utils
 * setup-dev-tools modern-cli
 */
@Script({
  emoji: "🛠️",
  tags: ["utils", "brew", "setup"],
  args: {
    category: {
      type: "string",
      position: 0,
      required: false,
      default: "all",
      enum: ["all", "core-utils", "dev-utils", "modern-cli", "editors"],
      description: "Package category to install",
    },
  },
})
export class SetupDevTools extends ScriptBase {
  async validate(ctx: Context): Promise<void> {
    this.requireCommand("brew", "Homebrew is required. Install it first with: make brew");
    const category = ctx.args.category as string;
    if (category !== "all" && !PACKAGE_GROUPS[category]) {
      throw new Error(`Invalid category: ${category}`);
    }
  }

  async run(ctx: Context): Promise<void> {
    const category = ctx.args.category as string;
    const categories = category === "all" ? Object.keys(PACKAGE_GROUPS) : [category];

    this.logger.banner(`Setup Development Tools: ${category}`);

    for (const key of categories) {
      const group = PACKAGE_GROUPS[key];
      if (!group) {
        continue;
      }

      this.logger.section(`Installing ${group.title}`);
      await this.installFormulae(group.formulae || []);
      await this.installCasks(group.casks || []);

      if (group.postInstall) {
        await group.postInstall();
      }
    }

    this.logger.success("Development tools setup complete");
  }

  private async installFormulae(formulae: string[]): Promise<void> {
    if (formulae.length === 0) {
      return;
    }

    this.logger.progress(`Installing formulae: ${formulae.join(" ")}`);
    for (const formula of formulae) {
      await this.installFormula(formula);
    }
  }

  private async installCasks(casks: string[]): Promise<void> {
    if (casks.length === 0) {
      return;
    }

    this.logger.progress(`Installing casks: ${casks.join(" ")}`);
    for (const cask of casks) {
      await this.installCask(cask);
    }
  }

  private async installFormula(formula: string): Promise<void> {
    if (await HomebrewService.isFormulaInstalled(formula)) {
      this.logger.success(`${formula} already installed`);
      return;
    }

    const result = await this.shell.exec({
      command: `brew install ${this.quoteShellArg(formula)}`,
      description: `Installing ${formula}`,
      silent: true,
    });

    if (result.success) {
      this.logger.success(`${formula} installed`);
    } else {
      this.logger.warn(`Could not install ${formula} (${result.stderr || "unknown error"})`);
    }
  }

  private async installCask(cask: string): Promise<void> {
    if (await HomebrewService.isCaskInstalled(cask)) {
      this.logger.success(`${cask} already installed`);
      return;
    }

    const result = await this.shell.exec({
      command: `brew install --cask ${this.quoteShellArg(cask)}`,
      description: `Installing ${cask}`,
      silent: true,
    });

    if (result.success) {
      this.logger.success(`${cask} installed`);
    } else {
      this.logger.warn(`Could not install ${cask} (${result.stderr || "unknown error"})`);
    }
  }

  private quoteShellArg(value: string): string {
    return `'${value.replace(/'/g, `'\\''`)}'`;
  }
}
