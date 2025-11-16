import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";
import * as clack from "@clack/prompts";
import { setTimeout } from "timers/promises";

/**
 * Interactive demo script - shows how to use @clack/prompts
 *
 * @example
 * interactive
 */
@Script({
  emoji: "✨",
  tags: ["demo", "interactive"],
  args: {
    // No required args - everything is interactive
    skipIntro: {
      type: "boolean",
      flag: "--skip-intro",
      description: "Skip intro message",
    },
  },
})
export class InteractiveScript extends ScriptBase {
  async run(ctx: Context): Promise<void> {
    const { skipIntro } = ctx.args;

    // Beautiful intro
    if (!skipIntro) {
      clack.intro("✨ Interactive Script Demo");
    }

    // Spinner example
    const spinner = clack.spinner();
    spinner.start("Loading...");
    await setTimeout(1000);
    spinner.stop("Loaded!");

    // Text input
    const name = await clack.text({
      message: "What's your name?",
      placeholder: "John Doe",
      validate: (value) => {
        if (!value) return "Name is required";
      },
    });

    if (clack.isCancel(name)) {
      clack.cancel("Operation cancelled");
      process.exit(0);
    }

    // Confirm
    const shouldContinue = await clack.confirm({
      message: "Continue with configuration?",
    });

    if (clack.isCancel(shouldContinue) || !shouldContinue) {
      clack.cancel("Configuration cancelled");
      process.exit(0);
    }

    // Select
    const framework = await clack.select({
      message: "Pick a framework",
      options: [
        { value: "react", label: "React", hint: "Popular choice" },
        { value: "vue", label: "Vue" },
        { value: "svelte", label: "Svelte", hint: "Lightweight" },
        { value: "solid", label: "Solid" },
      ],
    });

    if (clack.isCancel(framework)) {
      clack.cancel("Operation cancelled");
      process.exit(0);
    }

    // Multi-select
    const features = await clack.multiselect({
      message: "Select features",
      options: [
        { value: "typescript", label: "TypeScript" },
        { value: "eslint", label: "ESLint" },
        { value: "prettier", label: "Prettier" },
        { value: "testing", label: "Testing" },
      ],
      required: false,
    });

    if (clack.isCancel(features)) {
      clack.cancel("Operation cancelled");
      process.exit(0);
    }

    // Group prompts together (cleaner API)
    const config = await clack.group(
      {
        port: () =>
          clack.text({
            message: "What port?",
            placeholder: "3000",
            validate: (value) => {
              const num = parseInt(value);
              if (isNaN(num) || num < 1000 || num > 65535) {
                return "Port must be between 1000 and 65535";
              }
            },
          }),

        https: () =>
          clack.confirm({
            message: "Enable HTTPS?",
          }),
      },
      {
        onCancel: () => {
          clack.cancel("Operation cancelled");
          process.exit(0);
        },
      }
    );

    // Show results in a nice note
    clack.note(
      `
Name:      ${name}
Framework: ${framework}
Features:  ${(features as string[]).join(", ") || "none"}
Port:      ${config.port}
HTTPS:     ${config.https ? "yes" : "no"}
    `.trim(),
      "Configuration"
    );

    // Final outro
    clack.outro(`Thanks, ${name}! 🎉`);
  }
}
