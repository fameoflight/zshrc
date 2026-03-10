import path from "path";
import { Glob } from "bun";
import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { XcodeService } from "../../core/services/XcodeService";
import { IconService } from "../../core/services/IconService";

@Script({
  emoji: "🎨",
  tags: ["xcode", "icons"],
  args: {
    theme: {
      type: "string",
      flag: "-t, --theme",
      default: "modern",
      enum: ["modern", "minimal"],
      description: "Icon theme",
    },
    input: {
      type: "string",
      flag: "-i, --input",
      description: "Input SVG file",
    },
    includeLogo: {
      type: "boolean",
      flag: "--include-logo",
      description: "Also generate AppLogo images",
    },
    iosOnly: {
      type: "boolean",
      flag: "--ios-only",
      description: "Generate iOS icon files only",
    },
    macosOnly: {
      type: "boolean",
      flag: "--macos-only",
      description: "Generate macOS icon files only",
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
  },
})
export class XcodeIconGenerator extends ScriptBase {
  private iconService = new IconService();

  async validate(ctx: Context): Promise<void> {
    if (!(await XcodeService.projectExists())) {
      throw new Error("No Xcode project found in current directory");
    }
    if (ctx.args.iosOnly && ctx.args.macosOnly) {
      throw new Error("Cannot specify both --ios-only and --macos-only");
    }
    if (ctx.args.input) {
      await this.requireFile(path.resolve(ctx.args.input), `SVG file not found: ${ctx.args.input}`);
    }
  }

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Xcode Icon Generator");
    const iconSetDir = await this.findDirectory("AppIcon.appiconset");
    if (!iconSetDir) {
      throw new Error("Could not find AppIcon.appiconset in the project");
    }

    const inputSvg = ctx.args.input ? path.resolve(ctx.args.input) : undefined;
    const theme = ctx.args.theme as "modern" | "minimal";
    const backgroundColor = (ctx.args.color as string | undefined) || "#2D2D2D";
    const accentColor = (ctx.args.accent as string | undefined) || "#0096FF";

    const generatedFiles: Array<{ idiom: string; size: string; scale?: string; filename: string }> = [];

    if (!ctx.args.macosOnly) {
      const iosIcons = [
        { filename: "Icon-1024.png", variant: "normal" as const },
        { filename: "Icon-1024-Dark.png", variant: "dark" as const },
        { filename: "Icon-1024-Tinted.png", variant: "tinted" as const },
      ];

      for (const icon of iosIcons) {
        await this.iconService.generatePng({
          size: 1024,
          outputPath: path.join(iconSetDir, icon.filename),
          inputSvg,
          theme,
          backgroundColor,
          accentColor,
          variant: icon.variant,
        });
        generatedFiles.push({ idiom: "universal", size: "1024x1024", filename: icon.filename });
      }
    }

    if (!ctx.args.iosOnly) {
      const macosIcons = [
        { size: 16, filename: "Icon-16.png", scale: "1x", sizeStr: "16x16" },
        { size: 32, filename: "Icon-16@2x.png", scale: "2x", sizeStr: "16x16" },
        { size: 32, filename: "Icon-32.png", scale: "1x", sizeStr: "32x32" },
        { size: 64, filename: "Icon-32@2x.png", scale: "2x", sizeStr: "32x32" },
        { size: 128, filename: "Icon-128.png", scale: "1x", sizeStr: "128x128" },
        { size: 256, filename: "Icon-128@2x.png", scale: "2x", sizeStr: "128x128" },
        { size: 256, filename: "Icon-256.png", scale: "1x", sizeStr: "256x256" },
        { size: 512, filename: "Icon-256@2x.png", scale: "2x", sizeStr: "256x256" },
        { size: 512, filename: "Icon-512.png", scale: "1x", sizeStr: "512x512" },
        { size: 1024, filename: "Icon-512@2x.png", scale: "2x", sizeStr: "512x512" },
      ];

      for (const icon of macosIcons) {
        await this.iconService.generatePng({
          size: icon.size,
          outputPath: path.join(iconSetDir, icon.filename),
          inputSvg,
          theme,
          backgroundColor,
          accentColor,
        });
        generatedFiles.push({
          idiom: "mac",
          size: icon.sizeStr,
          scale: icon.scale,
          filename: icon.filename,
        });
      }
    }

    await this.iconService.writeJson(path.join(iconSetDir, "Contents.json"), {
      images: generatedFiles.map((file) => ({
        idiom: file.idiom,
        size: file.size,
        scale: file.scale,
        filename: file.filename,
      })),
      info: { version: 1, author: "xcode" },
    });

    if (ctx.args.includeLogo) {
      const logoDir = await this.findDirectory("AppLogo.imageset");
      if (logoDir) {
        const logos = [
          { size: 1024, filename: "AppLogo-1024.png", scale: "1x" },
          { size: 2048, filename: "AppLogo-2048.png", scale: "2x" },
          { size: 3072, filename: "AppLogo-3072.png", scale: "3x" },
        ];

        for (const logo of logos) {
          await this.iconService.generatePng({
            size: logo.size,
            outputPath: path.join(logoDir, logo.filename),
            inputSvg,
            theme,
            backgroundColor,
            accentColor,
          });
        }

        await this.iconService.writeJson(path.join(logoDir, "Contents.json"), {
          images: logos.map((logo) => ({
            idiom: "universal",
            scale: logo.scale,
            filename: logo.filename,
          })),
          info: { version: 1, author: "xcode" },
        });
      } else {
        this.logger.warn("AppLogo.imageset not found; skipping AppLogo generation");
      }
    }

    this.logger.success(`Updated icon set at ${iconSetDir}`);
  }

  private async findDirectory(targetName: string): Promise<string | null> {
    const glob = new Glob(`**/${targetName}`);
    for await (const match of glob.scan({ cwd: process.cwd(), onlyFiles: false })) {
      return path.resolve(match);
    }
    return null;
  }
}
