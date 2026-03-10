import path from "path";
import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { XcodeService } from "../../core/services/XcodeService";

@Script({
  emoji: "🗑️",
  tags: ["xcode", "project"],
  args: {
    fileName: {
      type: "string",
      position: 0,
      required: true,
      description: "File name to locate or delete",
    },
    findOnly: {
      type: "boolean",
      flag: "-f, --find-only",
      description: "Only locate files",
    },
    fileSystemOnly: {
      type: "boolean",
      flag: "--file-system-only",
      description: "Accepted for compatibility; Bun version always removes from filesystem only",
    },
  },
})
export class XcodeDeleteFile extends ScriptBase {
  async validate(): Promise<void> {
    if (!(await XcodeService.projectExists())) {
      throw new Error("No Xcode project found in current directory");
    }
  }

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Xcode Delete File");

    const fileName = ctx.args.fileName as string;
    const matches = await XcodeService.findFilesInProject(fileName);

    if (matches.length === 0) {
      this.logger.warn(`File '${fileName}' not found in project directories`);
      return;
    }

    console.log(`Found ${matches.length} matching file(s):`);
    matches.forEach((match, index) => {
      console.log(
        `  ${index + 1}. ${match.path}${match.size ? ` (${this.formatSize(match.size)})` : ""}${match.exists ? "" : " (missing)"}`
      );
    });

    if (ctx.args.findOnly) {
      return;
    }

    const shouldDelete = await ctx.confirm(`Delete ${matches.length} file(s) from disk?`);
    if (!shouldDelete) {
      return;
    }

    for (const match of matches) {
      if (!match.exists) {
        continue;
      }
      await XcodeService.removePath(match.path);
      this.logger.success(`Deleted: ${path.basename(match.path)}`);
    }

    this.logger.info("Xcode will remove synchronized references after refresh/build.");
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }
}
