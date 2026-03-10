import path from "path";
import { mkdtemp, rm } from "fs/promises";
import os from "os";
import { Glob } from "bun";
import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { LLMService } from "../../core/services/LLMService";
import { ConversationService } from "../../core/services/ConversationService";

interface TranscriptData {
  videoInfo: {
    title: string;
    duration: string;
    uploader?: string;
    uploadDate?: string;
    viewCount?: number;
    description?: string;
  };
  fullText: string;
  segments: Array<{ text: string; startTime: number; formattedTime: string }>;
  wordCount: number;
  language: string;
}

@Script({
  emoji: "🎥",
  tags: ["ai", "youtube", "transcript"],
  args: {
    url: {
      type: "string",
      position: 0,
      required: false,
      description: "YouTube URL",
    },
    language: {
      type: "string",
      flag: "-l, --language",
      default: "en",
      description: "Transcript language",
    },
    summaryOnly: {
      type: "boolean",
      flag: "-s, --summary-only",
      description: "Only generate summary",
    },
    output: {
      type: "string",
      flag: "-o, --output",
      description: "Write transcript text to file",
    },
    forceRefresh: {
      type: "boolean",
      flag: "--force-refresh",
      description: "Ignore cache",
    },
    model: {
      type: "string",
      flag: "-m, --model",
      description: "Model spec, e.g. ollama:llama3:70b",
    },
    listModels: {
      type: "boolean",
      flag: "--list-models",
      description: "List available models",
    },
    temperature: {
      type: "number",
      flag: "--temp",
      default: 0.3,
      description: "Model temperature",
    },
    maxTokens: {
      type: "integer",
      flag: "--max-tokens",
      default: 1000,
      description: "Maximum tokens",
    },
    chunkSize: {
      type: "integer",
      flag: "--chunk-size",
      default: 12000,
      description: "Chunk size for long transcripts",
    },
    noChunking: {
      type: "boolean",
      flag: "--no-chunking",
      description: "Disable chunking",
    },
  },
})
export class YouTubeTranscriptChat extends ScriptBase {
  async validate(ctx: Context): Promise<void> {
    this.requireCommand("yt-dlp", "yt-dlp is required. Install it with: brew install yt-dlp");
    if (!ctx.args.listModels && !ctx.args.url) {
      throw new Error("YouTube URL is required");
    }
    if (ctx.args.url && !this.isValidYouTubeUrl(ctx.args.url)) {
      throw new Error(`Invalid YouTube URL: ${ctx.args.url}`);
    }
  }

  async run(ctx: Context): Promise<void> {
    const llm = new LLMService({
      logger: this.logger,
      model: (ctx.args.model as string | undefined) || process.env.MODEL,
      temperature: ctx.args.temperature,
      maxTokens: ctx.args.maxTokens,
    });

    if (ctx.args.listModels) {
      const models = await llm.listModels();
      if (models.length === 0) {
        this.logger.warn("No models available");
        return;
      }
      models.forEach((model, index) => console.log(`${index + 1}. ${model}`));
      return;
    }

    if (!(await llm.available())) {
      throw new Error("LLM service is not available. Start LM Studio or Ollama and try again.");
    }

    this.logger.banner("YouTube Transcript Chat");
    const transcript = await this.downloadTranscript(
      ctx.args.url,
      ctx.args.language,
      ctx.args.output
    );

    const summary = await this.generateSummary(
      llm,
      transcript,
      ctx.args.chunkSize,
      !ctx.args.noChunking,
      ctx.args.temperature,
      ctx.args.maxTokens
    );

    console.log("\n" + "=".repeat(50));
    console.log("VIDEO SUMMARY");
    console.log("=".repeat(50));
    console.log(summary);
    console.log("=".repeat(50) + "\n");

    if (ctx.args.summaryOnly) {
      return;
    }

    const conversation = new ConversationService(
      llm,
      [
        "You are helping the user discuss a YouTube video transcript.",
        `Title: ${transcript.videoInfo.title}`,
        `Uploader: ${transcript.videoInfo.uploader || "Unknown"}`,
        `Duration: ${transcript.videoInfo.duration}`,
        `Summary:\n${summary}`,
        `Transcript:\n${transcript.fullText.slice(0, 12000)}`,
        "Answer based on the transcript. If information is missing, say so clearly.",
      ].join("\n\n")
    );

    console.log("Ask about the transcript. Type 'exit' to quit.");
    while (true) {
      const question = await ctx.prompt("You");
      const normalized = question.trim().toLowerCase();
      if (!normalized) {
        continue;
      }
      if (["exit", "quit", "q"].includes(normalized)) {
        break;
      }
      if (normalized === "summary") {
        console.log(summary);
        continue;
      }

      const response = await conversation.sendMessage(question, {
        temperature: ctx.args.temperature,
        maxTokens: ctx.args.maxTokens,
      });
      console.log(`\nAI:\n${response}\n`);
    }
  }

  private async downloadTranscript(
    url: string,
    language: string,
    outputFile?: string
  ): Promise<TranscriptData> {
    const tempDir = await mkdtemp(path.join(os.tmpdir(), "youtube-transcript-"));
    try {
      const infoResult = await this.shell.exec({
        command: `yt-dlp --dump-json --no-download ${this.quote(url)}`,
        silent: true,
      });
      if (!infoResult.success || !infoResult.stdout) {
        throw new Error("Failed to fetch video metadata");
      }
      const info = JSON.parse(infoResult.stdout);

      let transcriptFile = await this.fetchTranscriptFile(url, language, tempDir);
      if (!transcriptFile && language !== "en") {
        this.logger.warn(`No transcript found for '${language}', falling back to English`);
        transcriptFile = await this.fetchTranscriptFile(url, "en", tempDir);
      }
      if (!transcriptFile) {
        throw new Error("Failed to download transcript");
      }

      const transcriptJson = JSON.parse(await Bun.file(transcriptFile).text());
      const segments: TranscriptData["segments"] = [];
      let fullText = "";

      for (const event of transcriptJson.events || []) {
        if (!event.segs) continue;
        const text = event.segs.map((segment: { utf8?: string }) => segment.utf8 || "").join("").trim();
        if (!text) continue;
        const startTime = (event.tStartMs || 0) / 1000;
        segments.push({
          text,
          startTime,
          formattedTime: this.formatTime(startTime),
        });
        fullText += `${text} `;
      }

      if (outputFile) {
        await Bun.write(path.resolve(outputFile), fullText.trim());
      }

      return {
        videoInfo: {
          title: info.title,
          duration: this.formatDuration(info.duration),
          uploader: info.uploader,
          uploadDate: info.upload_date,
          viewCount: info.view_count,
          description: info.description,
        },
        fullText: fullText.trim(),
        segments,
        wordCount: fullText.trim().split(/\s+/).filter(Boolean).length,
        language,
      };
    } finally {
      await rm(tempDir, { recursive: true, force: true });
    }
  }

  private async fetchTranscriptFile(url: string, language: string, tempDir: string): Promise<string | null> {
    const command = [
      "yt-dlp",
      "--write-auto-subs",
      "--sub-langs",
      this.quote(language),
      "--sub-format",
      "json3",
      "--skip-download",
      "--output",
      this.quote(path.join(tempDir, "%(title)s.%(ext)s")),
      this.quote(url),
    ].join(" ");

    const result = await this.shell.exec({ command, silent: true });
    if (!result.success) {
      return null;
    }

    const glob = new Glob("*.json3");
    for await (const match of glob.scan({ cwd: tempDir, onlyFiles: true })) {
      return path.join(tempDir, match);
    }
    return null;
  }

  private async generateSummary(
    llm: LLMService,
    transcript: TranscriptData,
    chunkSize: number,
    useChunking: boolean,
    temperature: number,
    maxTokens: number
  ): Promise<string> {
    const basePrompt = (text: string) => [
      "Summarize this YouTube transcript clearly.",
      `Title: ${transcript.videoInfo.title}`,
      `Uploader: ${transcript.videoInfo.uploader || "Unknown"}`,
      "Focus on the main arguments, concrete takeaways, and notable details.",
      "",
      text,
    ].join("\n");

    if (!useChunking || transcript.fullText.length <= chunkSize) {
      return llm.complete(basePrompt(transcript.fullText), { temperature, maxTokens });
    }

    const chunkSummaries: string[] = [];
    for (let index = 0; index < transcript.fullText.length; index += chunkSize) {
      const chunk = transcript.fullText.slice(index, index + chunkSize);
      const summary = await llm.complete(
        [
          `Summarize transcript chunk ${Math.floor(index / chunkSize) + 1}.`,
          "Focus on facts and key ideas only.",
          "",
          chunk,
        ].join("\n"),
        { temperature, maxTokens }
      );
      chunkSummaries.push(summary);
    }

    return llm.complete(
      [
        "Synthesize these chunk summaries into one coherent summary.",
        `Title: ${transcript.videoInfo.title}`,
        "",
        chunkSummaries.join("\n\n"),
      ].join("\n"),
      { temperature, maxTokens }
    );
  }

  private isValidYouTubeUrl(url: string): boolean {
    return /(youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)/.test(url);
  }

  private formatDuration(seconds?: number): string {
    if (!seconds) return "Unknown";
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return hours > 0
      ? `${hours}:${String(minutes).padStart(2, "0")}:${String(remainingSeconds).padStart(2, "0")}`
      : `${minutes}:${String(remainingSeconds).padStart(2, "0")}`;
  }

  private formatTime(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return `${minutes}:${String(remainingSeconds).padStart(2, "0")}`;
  }

  private quote(value: string): string {
    return `'${value.replace(/'/g, `'\\''`)}'`;
  }
}
