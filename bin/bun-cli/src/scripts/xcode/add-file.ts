import path from "path";
import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { XcodeService } from "../../core/services/XcodeService";

@Script({
  emoji: "📁",
  tags: ["xcode", "project"],
  args: {
    filePath: {
      type: "string",
      position: 0,
      required: false,
      description: "File path to add",
    },
    category: {
      type: "string",
      position: 1,
      flag: "-c, --category",
      required: false,
      description: "Category override",
    },
    listCategories: {
      type: "boolean",
      flag: "-l, --list-categories",
      description: "List available categories",
    },
  },
})
export class XcodeAddFile extends ScriptBase {
  async validate(ctx: Context): Promise<void> {
    if (ctx.args.listCategories) {
      return;
    }

    if (!(await XcodeService.projectExists())) {
      throw new Error("No Xcode project found in current directory");
    }

    if (!ctx.args.filePath) {
      throw new Error("File path is required");
    }
  }

  async run(ctx: Context): Promise<void> {
    this.logger.banner("Xcode Add File");

    if (ctx.args.listCategories) {
      for (const category of XcodeService.listCategories()) {
        console.log(`${category.name.padEnd(15)} - ${category.description}`);
      }
      return;
    }

    const filePath = path.resolve(ctx.args.filePath);
    await this.requireFile(filePath, `File '${filePath}' does not exist`);

    const fileName = path.basename(filePath);
    const categoryName = (ctx.args.category as string | undefined) || XcodeService.inferCategoryFromPath(filePath);

    if (!XcodeService.validCategory(categoryName)) {
      throw new Error(`Unknown category '${categoryName}'`);
    }

    const category = XcodeService.getCategoryInfo(categoryName)!;
    const targetDir = await XcodeService.getTargetDirectory(categoryName);

    if (await XcodeService.fileExistsInProject(fileName)) {
      this.logger.warn(`File '${fileName}' may already exist in the project`);
      const continueAnyway = await ctx.confirm("Continue anyway?");
      if (!continueAnyway) {
        return;
      }
    }

    this.logger.info(`Auto-detected category: ${categoryName}`);
    this.logger.info(`Group: ${category.groupName}`);
    this.logger.info(`Build Phase: ${XcodeService.getBuildPhase(filePath, categoryName)}`);
    this.logger.info(`File Type: ${XcodeService.getFileType(filePath)}`);

    if (XcodeService.isResourceFile(filePath)) {
      const resourceInfo = XcodeService.getResourceHandlingInfo(filePath, categoryName);
      console.log(`Resource Type: ${resourceInfo.type}`);
      console.log(`Recommended Location: ${targetDir}`);
      for (const [index, instruction] of resourceInfo.instructions.entries()) {
        console.log(`  ${index + 1}. ${instruction}`);
      }

      if (XcodeService.isAssetCatalog(filePath)) {
        const shouldCopy = await ctx.confirm(`Copy ${filePath} to ${targetDir}?`);
        if (shouldCopy) {
          const destination = path.join(targetDir, path.basename(filePath));
          await XcodeService.copyDirectoryRecursive(filePath, destination);
          this.logger.success(`Copied asset catalog to ${destination}`);
        }
      }
      return;
    }

    const shouldCreate = await ctx.confirm(`Create directory '${targetDir}' if needed?`);
    if (shouldCreate) {
      await XcodeService.ensureDirectoryExists(targetDir);
      this.logger.success(`Ensured directory exists: ${targetDir}`);
    }

    this.logger.success("File will be managed by Xcode's synchronized file system groups");
    this.logger.info(`Move the file into: ${targetDir}`);
  }
}
