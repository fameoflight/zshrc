// Export command interfaces and registry
export {Command, CommandFlags, CommandConfig} from './command.js';
export {CommandRegistry, registry} from './registry.js';

// Export individual commands
export {AddCommand} from './add.js';

// Import and register all commands
import {registry} from './registry.js';
import {AddCommand} from './add.js';

/**
 * Register all available commands - add new commands here
 */
export function registerCommands(): void {
	// Register add command
	registry.register(new AddCommand());

	// Add new commands here:
	// registry.register(new AnotherCommand());
}

/**
 * Get all registered command names
 */
export function getCommandNames(): string[] {
	return registry.getCommandNames();
}

/**
 * Get command registry instance
 */
export function getRegistry() {
	return registry;
}