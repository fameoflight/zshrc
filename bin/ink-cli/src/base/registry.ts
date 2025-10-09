import {Command, CommandConfig} from './command.js';

/**
 * Command registry - manages all available commands
 * Similar to Rust's global HashMap registry
 */
class CommandRegistry {
	private commands = new Map<string, Command>();

	/**
	 * Register a new command
	 */
	register(command: Command): void {
		const name = command.name();
		if (this.commands.has(name)) {
			throw new Error(`Command '${name}' is already registered`);
		}
		this.commands.set(name, command);
	}

	/**
	 * Get all registered command names
	 */
	getCommandNames(): string[] {
		return Array.from(this.commands.keys());
	}

	/**
	 * Get a specific command by name
	 */
	getCommand(name: string): Command | undefined {
		return this.commands.get(name);
	}

	/**
	 * Check if a command exists
	 */
	hasCommand(name: string): boolean {
		return this.commands.has(name);
	}

	/**
	 * Get all command configurations for CLI setup
	 */
	getAllCommandConfigs(): Array<{name: string; config: CommandConfig}> {
		return Array.from(this.commands.entries()).map(([name, command]) => ({
			name,
			config: command.config(),
		}));
	}

	/**
	 * Ensure all command names are unique (already guaranteed by Map)
	 */
	checkUniqueNames(names: string[]): void {
		for (const name of names) {
			if (!this.commands.has(name)) {
				throw new Error(`Command not registered: ${name}`);
			}
		}
	}
}

export default CommandRegistry;
