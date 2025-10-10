/**
 * Reusable Frameworks for Interactive CLI Applications
 *
 * This package provides generic, reusable components for building interactive
 * terminal applications with streaming, keyboard shortcuts, and command systems.
 */

export * from './streaming/index.js';
export * from './terminal/index.js';
export * from './commands/index.js';

// Re-export commonly used command helpers
export {
	createActionCommand,
	createValidatedCommand,
	createSafeCommand,
	createFullCommand,
	createUtilityCommands,
	createInfoCommands,
	createCommandGroup,
	createToggleCommand,
	createNavigationCommand,
	CommandRegistry,
	type GenericCommand,
	type CommandContext,
	type CommandRegistryOptions,
} from './commands/index.js';
