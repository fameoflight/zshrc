import { stat, readFile, writeFile, exists } from "fs/promises";
import { Glob } from "bun";
import type { FileSystem as FileSystemInterface, FileStats } from "../types";

/**
 * File system operations
 *
 * Wraps Node.js fs/promises + Bun's Glob
 */
export class FileSystem implements FileSystemInterface {
  async exists(path: string): Promise<boolean> {
    try {
      await stat(path);
      return true;
    } catch {
      return false;
    }
  }

  async isDirectory(path: string): Promise<boolean> {
    try {
      const stats = await stat(path);
      return stats.isDirectory();
    } catch {
      return false;
    }
  }

  async isFile(path: string): Promise<boolean> {
    try {
      const stats = await stat(path);
      return stats.isFile();
    } catch {
      return false;
    }
  }

  async readFile(path: string): Promise<string> {
    return readFile(path, "utf-8");
  }

  async writeFile(path: string, content: string): Promise<void> {
    await writeFile(path, content, "utf-8");
  }

  async stat(path: string): Promise<FileStats> {
    const stats = await stat(path);

    return {
      size: stats.size,
      isFile: stats.isFile(),
      isDirectory: stats.isDirectory(),
      mtime: stats.mtime,
    };
  }

  async glob(params: {
    pattern: string;
    cwd?: string;
    ignore?: string[];
  }): Promise<string[]> {
    const { pattern, cwd, ignore } = params;

    const glob = new Glob(pattern);
    const files: string[] = [];

    // Scan the directory
    const scanner = glob.scan({
      cwd: cwd || process.cwd(),
      onlyFiles: true,
    });

    for await (const file of scanner) {
      // Check if file matches ignore patterns
      if (ignore && this.shouldIgnore(file, ignore)) {
        continue;
      }

      files.push(file);
    }

    return files;
  }

  /**
   * Check if file should be ignored
   */
  private shouldIgnore(file: string, patterns: string[]): boolean {
    return patterns.some((pattern) => {
      // Simple pattern matching (can be enhanced)
      const regex = pattern
        .replace(/\*\*/g, ".*")
        .replace(/\*/g, "[^/]*")
        .replace(/\?/g, ".");

      return new RegExp(regex).test(file);
    });
  }
}
