import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import { XcodeService } from "../../core/services/XcodeService";

@Script({
  emoji: "📋",
  tags: ["xcode", "project"],
  args: {
    category: {
      type: "string",
      position: 0,
      required: false,
      description: "Specific category to inspect",
    },
    detailed: {
      type: "boolean",
      flag: "-d, --detailed",
      description: "Show detailed information",
    },
    json: {
      type: "boolean",
      flag: "-j, --json",
      description: "Output JSON",
    },
    patterns: {
      type: "boolean",
      flag: "-p, --patterns",
      description: "Show path matching patterns",
    },
  },
})
export class XcodeListCategories extends ScriptBase {
  async run(ctx: Context): Promise<void> {
    const categories = XcodeService.listCategories();
    const specificCategory = ctx.args.category as string | undefined;

    this.logger.banner("Xcode List Categories");

    if (!(await XcodeService.projectExists())) {
      this.logger.warn("No Xcode project found in current directory");
      this.logger.info("Categories will be shown for reference");
    }

    if (ctx.args.json) {
      if (specificCategory) {
        const category = XcodeService.getCategoryInfo(specificCategory);
        if (!category) {
          throw new Error(`Category '${specificCategory}' not found`);
        }
        console.log(JSON.stringify(category, null, 2));
        return;
      }

      console.log(JSON.stringify(categories, null, 2));
      return;
    }

    if (specificCategory) {
      const category = XcodeService.getCategoryInfo(specificCategory);
      if (!category) {
        throw new Error(`Category '${specificCategory}' not found`);
      }

      console.log(`Name: ${category.name}`);
      console.log(`Group: ${category.groupName}`);
      console.log(`Build Phase: ${category.buildPhase}`);
      console.log(`Description: ${category.description}`);
      if (ctx.args.patterns || ctx.args.detailed) {
        console.log(`Patterns: ${category.pathMatch.join(", ")}`);
      }
      if (ctx.args.detailed && (await XcodeService.projectExists())) {
        const targetDir = await XcodeService.getTargetDirectory(category.name);
        console.log(`Target Directory: ${targetDir}`);
      }
      return;
    }

    for (const category of categories) {
      if (ctx.args.detailed) {
        console.log(`${category.name.toUpperCase()}`);
        console.log(`  Group: ${category.groupName}`);
        console.log(`  Phase: ${category.buildPhase}`);
        console.log(`  Desc: ${category.description}`);
        if (ctx.args.patterns) {
          console.log(`  Match: ${category.pathMatch.join(", ")}`);
        }
      } else {
        console.log(`${category.name.padEnd(15)} - ${category.description}`);
      }
    }

    console.log(`\nTotal categories: ${categories.length}`);
  }
}
