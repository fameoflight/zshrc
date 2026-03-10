import path from "path";
import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";

/**
 * Extract clips from videos using ffmpeg
 *
 * Preserves quality by default via re-encoding, or can do a faster codec-copy
 * clip when `--no-preserve-quality` is provided.
 *
 * @example
 * clip-video video.mp4
 * clip-video video.mp4 -s 01:30 -d 60
 * clip-video video.mp4 -s 30 -d 15 -o clip.mp4
 */
@Script({
  emoji: "🎬",
  tags: ["media", "video", "ffmpeg"],
  args: {
    inputFile: {
      type: "string",
      position: 0,
      required: true,
      description: "Input video file",
    },
    start: {
      type: "string",
      flag: "-s, --start",
      default: "00:00:00",
      description: "Start time in HH:MM:SS, MM:SS, or seconds",
    },
    duration: {
      type: "string",
      flag: "-d, --duration",
      default: "30",
      description: "Clip duration in seconds",
    },
    output: {
      type: "string",
      flag: "-o, --output",
      description: "Output file path",
    },
    noPreserveQuality: {
      type: "boolean",
      flag: "-q, --no-preserve-quality",
      description: "Copy codecs directly instead of re-encoding for quality",
    },
  },
})
export class ClipVideo extends ScriptBase {
  async validate(ctx: Context): Promise<void> {
    const inputFile = path.resolve(ctx.args.inputFile);
    await this.requireFile(inputFile, `Input file does not exist: ${inputFile}`);
    this.requireCommand("ffmpeg", "FFmpeg is not installed. Install with: brew install ffmpeg");

    const start = ctx.args.start as string;
    if (!this.isValidTimeFormat(start)) {
      throw new Error(`Invalid start time format: ${start}. Use HH:MM:SS, MM:SS, or seconds`);
    }

    const duration = String(ctx.args.duration);
    if (!/^\d+(\.\d+)?$/.test(duration)) {
      throw new Error(`Invalid duration: ${duration}. Use seconds, for example 30 or 15.5`);
    }
  }

  async run(ctx: Context): Promise<void> {
    const inputFile = path.resolve(ctx.args.inputFile);
    const start = ctx.args.start as string;
    const duration = String(ctx.args.duration);
    const preserveQuality = !ctx.args.noPreserveQuality;
    const outputFile = this.resolveOutputFile(inputFile, ctx.args.output);

    this.logger.banner("Video Clipper");
    this.logger.section("Video Clipping");
    this.logger.info(`Input file: ${inputFile}`);
    this.logger.info(`Start time: ${start}`);
    this.logger.info(`Duration: ${duration} seconds`);
    this.logger.info(`Output file: ${outputFile}`);
    this.logger.info(`Mode: ${preserveQuality ? "re-encode for quality" : "copy codecs"}`);

    const commandParts = [
      "ffmpeg",
      "-i",
      this.quoteShellArg(inputFile),
      "-ss",
      this.quoteShellArg(start),
      "-t",
      this.quoteShellArg(duration),
    ];

    if (preserveQuality) {
      commandParts.push("-c:v", "libx264", "-crf", "18", "-c:a", "aac", "-b:a", "192k");
    } else {
      commandParts.push("-c", "copy");
    }

    commandParts.push(
      "-avoid_negative_ts",
      "1",
      "-y",
      this.quoteShellArg(outputFile)
    );

    const result = await this.shell.exec({
      command: commandParts.join(" "),
      description: "Clipping video",
    });

    if (!result.success) {
      throw new Error(result.stderr || "Failed to clip video");
    }

    await this.requireFile(outputFile, "Output file was not created");
    const stats = await this.fs.stat(outputFile);
    const outputSizeMb = stats.size / (1024 * 1024);

    this.logger.success(`Created clip: ${outputFile}`);
    this.logger.info(`Output video: ${outputSizeMb.toFixed(2)} MB`);
  }

  private resolveOutputFile(inputFile: string, output?: string): string {
    if (output && output.trim().length > 0) {
      return path.resolve(output);
    }

    const inputDirectory = path.dirname(inputFile);
    const inputExtension = path.extname(inputFile);
    const inputBasename = path.basename(inputFile, inputExtension);
    const timestamp = this.timestamp();

    return path.join(inputDirectory, `${inputBasename}_clip_${timestamp}${inputExtension}`);
  }

  private timestamp(): string {
    const now = new Date();
    const pad = (value: number) => String(value).padStart(2, "0");

    return [
      now.getFullYear(),
      pad(now.getMonth() + 1),
      pad(now.getDate()),
      "_",
      pad(now.getHours()),
      pad(now.getMinutes()),
      pad(now.getSeconds()),
    ].join("");
  }

  private isValidTimeFormat(time: string): boolean {
    return /^\d+$/.test(time) || /^\d{1,2}:\d{2}$/.test(time) || /^\d{1,2}:\d{2}:\d{2}$/.test(time);
  }

  private quoteShellArg(value: string): string {
    return `'${value.replace(/'/g, `'\\''`)}'`;
  }
}
