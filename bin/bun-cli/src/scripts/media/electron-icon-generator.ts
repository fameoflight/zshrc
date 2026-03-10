import path from "path";
import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { IconService } from "../../core/services/IconService";

@Script({
  emoji: "⚛️",
  tags: ["media", "icons", "electron"],
  args: {
    input: {
      type: "string",
      position: 0,
      flag: "-i, --input",
      required: false,
      description: "Input SVG file",
    },
    output: {
      type: "string",
      flag: "-o, --output",
      default: "./icons",
      description: "Output directory",
    },
    platform: {
      type: "string",
      flag: "-p, --platform",
      default: "all",
      enum: ["windows", "macos", "linux", "all"],
      description: "Target platform",
    },
    theme: {
      type: "string",
      flag: "-t, --theme",
      default: "modern",
      enum: ["modern", "minimal"],
      description: "Generated theme",
    },
    color: {
      type: "string",
      flag: "-c, --color",
      description: "Background color",
    },
    accent: {
      type: "string",
      flag: "-a, --accent",
      description: "Accent color",
    },
    ico: {
      type: "boolean",
      flag: "--ico",
      description: "Generate .ico file",
    },
    icns: {
      type: "boolean",
      flag: "--icns",
      description: "Generate .icns file",
    },
  },
})
export class ElectronIconGenerator extends ScriptBase {
  private iconService = new IconService();

  async validate(ctx: Context): Promise<void> {
    if (ctx.args.input) {
      await this.requireFile(path.resolve(ctx.args.input), `SVG file not found: ${ctx.args.input}`);
    }
    if (ctx.args.ico) {
      if (!this.shell.commandExists("convert") && !this.shell.commandExists("magick")) {
        throw new Error("ImageMagick is required to generate .ico files");
      }
    }
    if (ctx.args.icns) {
      this.requireCommand("iconutil", "iconutil is required to generate .icns files");
    }
  }

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Electron Icon Generator");

    const outputDir = path.resolve(ctx.args.output);
    const inputSvg = ctx.args.input ? path.resolve(ctx.args.input) : undefined;
    const theme = ctx.args.theme as "modern" | "minimal";
    const platform = ctx.args.platform as "windows" | "macos" | "linux" | "all";
    const backgroundColor = (ctx.args.color as string | undefined) || "#2D2D2D";
    const accentColor = (ctx.args.accent as string | undefined) || "#0096FF";

    const sizes = {
      windows: [16, 24, 32, 48, 64, 128, 256],
      macos: [16, 32, 64, 128, 256, 512, 1024],
      linux: [16, 24, 32, 48, 64, 128, 256, 512],
    };

    const platforms = platform === "all" ? ["windows", "macos", "linux"] : [platform];

    for (const platformName of platforms) {
      const targetDir = path.join(outputDir, platformName);
      for (const size of sizes[platformName as keyof typeof sizes]) {
        const file = path.join(targetDir, `icon-${size}x${size}.png`);
        await this.iconService.generatePng({
          size,
          outputPath: file,
          inputSvg,
          theme,
          backgroundColor,
          accentColor,
        });
      }
      this.logger.success(`Generated ${sizes[platformName as keyof typeof sizes].length} ${platformName} icons`);
    }

    if (ctx.args.ico) {
      const windowsDir = path.join(outputDir, "windows");
      const pngs = await this.iconService.listPngFiles(windowsDir);
      if (pngs.length > 0) {
        await this.iconService.buildIco(pngs, path.join(outputDir, "icon.ico"));
        this.logger.success(`Generated ${path.join(outputDir, "icon.ico")}`);
      }
    }

    if (ctx.args.icns) {
      const macosDir = path.join(outputDir, "macos");
      const sizesForIcns = (await this.iconService.listPngFiles(macosDir)).map((file) => ({
        file,
        size: parseInt(path.basename(file).match(/icon-(\d+)x/)?.[1] || "0", 10),
      }));
      if (sizesForIcns.length > 0) {
        await this.iconService.buildIcns(sizesForIcns, path.join(outputDir, "icon.icns"));
        this.logger.success(`Generated ${path.join(outputDir, "icon.icns")}`);
      }
    }
  }
}
