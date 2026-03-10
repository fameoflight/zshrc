import path from "path";
import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { XcodeService } from "../../core/services/XcodeService";

@Script({
  emoji: "👀",
  tags: ["xcode", "project"],
  args: {
    category: {
      type: "string",
      position: 0,
      flag: "-c, --category",
      required: false,
      description: "Category to filter by",
    },
    summary: {
      type: "boolean",
      flag: "-s, --summary",
      description: "Show project summary only",
    },
  },
})
export class XcodeViewFiles extends ScriptBase {
  async validate(ctx: Context): Promise<void> {
    if (!(await XcodeService.projectExists())) {
      throw new Error("No Xcode project found in current directory");
    }

    const category = ctx.args.category as string | undefined;
    if (category && !XcodeService.validCategory(category)) {
      throw new Error(`Unknown category '${category}'`);
    }
  }

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Xcode View Files");

    if (ctx.args.summary) {
      const summary = await XcodeService.projectSummary();
      if (!summary) return;
      console.log(`Project: ${summary.projectName}`);
      console.log(`Project File: ${summary.projectFile}`);
      console.log(`Project Path: ${summary.projectPath}`);
      console.log(`Root Groups: ${summary.rootGroupsCount}`);
      console.log(`Categories Available: ${summary.categoriesAvailable}`);
      return;
    }

    const category = ctx.args.category as string | undefined;
    const project = await XcodeService.currentProject();
    if (!project) {
      return;
    }

    console.log(`Project Files - ${project.name}`);
    console.log("=".repeat(60));

    const rootGroups = await XcodeService.getRootGroups();
    for (const group of rootGroups) {
      if (category && !this.groupMatchesCategory(group.name, group.path, category)) {
        continue;
      }

      console.log(`\n📁 ${group.name} -> ${group.path}`);
      const files = await XcodeService.listDirectoryFiles(path.resolve(group.path));
      if (files.length === 0) {
        console.log("    (empty directory)");
        continue;
      }

      for (const file of files) {
        if (file.type === "directory") {
          console.log(`    📁 ${file.name}/`);
        } else {
          console.log(`    📄 ${file.name}${file.size ? ` (${this.formatSize(file.size)})` : ""}`);
        }
      }
    }
  }

  private groupMatchesCategory(groupName: string, groupPath: string, categoryName: string): boolean {
    const category = XcodeService.getCategoryInfo(categoryName);
    if (!category) {
      return false;
    }

    const lowerName = groupName.toLowerCase();
    const lowerPath = groupPath.toLowerCase();
    return category.pathMatch.some(
      (pattern) => lowerName.includes(pattern.toLowerCase()) || lowerPath.includes(pattern.toLowerCase())
    );
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }
}
