import CommandRegistry from './registry.js';
export {Command, CommandFlags, CommandConfig} from './command.js';

// Global registry instance
const registry = new CommandRegistry();

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
