import path from "path";
import { mkdir, readdir, rm, copyFile, writeFile } from "fs/promises";
import sharp from "sharp";
import { exec } from "../utils/shell";

export type IconTheme = "modern" | "minimal";
export type IconVariant = "normal" | "dark" | "tinted";

export interface GeneratedIconOptions {
  size: number;
  outputPath: string;
  inputSvg?: string;
  theme?: IconTheme;
  backgroundColor?: string;
  accentColor?: string;
  variant?: IconVariant;
}

export class IconService {
  async generatePng(options: GeneratedIconOptions): Promise<void> {
    const {
      size,
      outputPath,
      inputSvg,
      theme = "modern",
      backgroundColor = "#2D2D2D",
      accentColor = "#0096FF",
      variant = "normal",
    } = options;

    await mkdir(path.dirname(outputPath), { recursive: true });

    const source = inputSvg
      ? await Bun.file(inputSvg).arrayBuffer()
      : Buffer.from(this.buildGeneratedSvg(size, theme, backgroundColor, accentColor, variant));

    await sharp(source)
      .resize(size, size)
      .png()
      .toFile(outputPath);
  }

  async buildIco(pngFiles: string[], outputPath: string): Promise<void> {
    const command = Bun.which("magick")
      ? `magick convert ${pngFiles.map(this.quote).join(" ")} ${this.quote(outputPath)}`
      : `convert ${pngFiles.map(this.quote).join(" ")} ${this.quote(outputPath)}`;

    await exec(command, { description: "Generating .ico file" });
  }

  async buildIcns(sourcePngs: Array<{ size: number; file: string }>, outputPath: string): Promise<void> {
    const iconsetDir = path.join(path.dirname(outputPath), "icon.iconset");
    await rm(iconsetDir, { recursive: true, force: true });
    await mkdir(iconsetDir, { recursive: true });

    const iconMappings: Record<number, string[]> = {
      16: ["icon_16x16.png"],
      32: ["icon_16x16@2x.png", "icon_32x32.png"],
      64: ["icon_32x32@2x.png"],
      128: ["icon_128x128.png"],
      256: ["icon_128x128@2x.png", "icon_256x256.png"],
      512: ["icon_256x256@2x.png", "icon_512x512.png"],
      1024: ["icon_512x512@2x.png"],
    };

    for (const source of sourcePngs) {
      const targets = iconMappings[source.size] || [];
      for (const targetName of targets) {
        await copyFile(source.file, path.join(iconsetDir, targetName));
      }
    }

    await exec(
      `iconutil -c icns ${this.quote(iconsetDir)} -o ${this.quote(outputPath)}`,
      { description: "Generating .icns file" }
    );

    await rm(iconsetDir, { recursive: true, force: true });
  }

  async writeJson(filePath: string, content: unknown): Promise<void> {
    await mkdir(path.dirname(filePath), { recursive: true });
    await writeFile(filePath, JSON.stringify(content, null, 2) + "\n", "utf-8");
  }

  async listPngFiles(directoryPath: string): Promise<string[]> {
    const entries = await readdir(directoryPath, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".png"))
      .map((entry) => path.join(directoryPath, entry.name))
      .sort((a, b) => a.localeCompare(b));
  }

  private buildGeneratedSvg(
    size: number,
    theme: IconTheme,
    backgroundColor: string,
    accentColor: string,
    variant: IconVariant
  ): string {
    const adjustedBackground =
      variant === "dark" ? "#1E1E1E" : variant === "tinted" ? "#3C3C50" : backgroundColor;

    const rounded = Math.max(24, Math.floor(size * 0.22));
    const stroke = Math.max(8, Math.floor(size * 0.045));
    const center = size / 2;

    if (theme === "minimal") {
      return `
<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <rect width="${size}" height="${size}" rx="${rounded}" fill="${adjustedBackground}" />
  <circle cx="${center}" cy="${center}" r="${size * 0.24}" fill="none" stroke="${accentColor}" stroke-width="${stroke}" />
  <path d="M${size * 0.34} ${center}h${size * 0.32}" stroke="${accentColor}" stroke-width="${stroke}" stroke-linecap="round" />
</svg>`;
    }

    return `
<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <defs>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="${accentColor}" />
      <stop offset="100%" stop-color="#6EE7F9" />
    </linearGradient>
  </defs>
  <rect width="${size}" height="${size}" rx="${rounded}" fill="${adjustedBackground}" />
  <rect x="${size * 0.18}" y="${size * 0.18}" width="${size * 0.64}" height="${size * 0.64}" rx="${rounded * 0.5}" fill="url(#accent)" opacity="0.18" />
  <path d="M${size * 0.32} ${size * 0.66}L${size * 0.46} ${size * 0.38}L${size * 0.56} ${size * 0.52}L${size * 0.68} ${size * 0.3}" stroke="url(#accent)" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round" fill="none" />
  <circle cx="${size * 0.68}" cy="${size * 0.3}" r="${stroke * 0.7}" fill="${accentColor}" />
</svg>`;
  }

  private quote(value: string): string {
    return `'${value.replace(/'/g, `'\\''`)}'`;
  }
}
