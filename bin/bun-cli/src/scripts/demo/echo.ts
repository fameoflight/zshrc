import { Script } from "../../core/decorators/Script";
import { Script as ScriptBase } from "../../core/base/Script";
import type { Context } from "../../core/types";

/**
 * Simple echo script - demonstrates basic usage
 *
 * @example
 * echo "Hello, world!"
 * echo "Test message" --uppercase
 */
@Script({
  emoji: "💬",
  tags: ["demo", "simple"],
  args: {
    message: {
      type: "string",
      position: 0,
      required: true,
      description: "Message to echo",
    },
    uppercase: {
      type: "boolean",
      flag: "-u, --uppercase",
      description: "Convert to uppercase",
    },
    repeat: {
      type: "integer",
      flag: "-r, --repeat",
      min: 1,
      max: 10,
      default: 1,
      description: "Number of times to repeat",
    },
  },
})
export class EchoScript extends ScriptBase {
  async run(ctx: Context): Promise<void> {
    const { message, uppercase, repeat } = ctx.args;

    // Transform message
    let output = message;
    if (uppercase) {
      output = output.toUpperCase();
    }

    // Repeat
    for (let i = 0; i < repeat; i++) {
      console.log(output);
    }

    this.logger.success(`Echoed message ${repeat} time(s)`);
  }
}
