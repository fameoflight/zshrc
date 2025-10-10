import {GenericCommand, CommandContext} from './types.js';

/**
 * Helper functions for creating common command types
 */

/**
 * Create a simple action command
 */
export function createActionCommand<T = any>(
	id: string,
	label: string,
	description: string,
	action: (context: CommandContext<T>) => void | Promise<void>,
): GenericCommand<T> {
	return {
		id,
		label,
		description,
		execute: action,
	};
}

/**
 * Create a command with validation
 */
export function createValidatedCommand<T = any>(
	id: string,
	label: string,
	description: string,
	action: (context: CommandContext<T>) => void | Promise<void>,
	validator: (context: CommandContext<T>) => boolean,
): GenericCommand<T> {
	return {
		id,
		label,
		description,
		execute: action,
		validate: validator,
	};
}

/**
 * Create a command with error handling
 */
export function createSafeCommand<T = any>(
	id: string,
	label: string,
	description: string,
	action: (context: CommandContext<T>) => void | Promise<void>,
	errorHandler?: (error: Error, context: CommandContext<T>) => void,
): GenericCommand<T> {
	return {
		id,
		label,
		description,
		execute: action,
		onError: errorHandler,
	};
}

/**
 * Create a command with success and error callbacks
 */
export function createFullCommand<T = any>(config: {
	id: string;
	label: string;
	description: string;
	category?: string;
	keybinding?: string;
	action: (context: CommandContext<T>) => void | Promise<void>;
	validator?: (context: CommandContext<T>) => boolean;
	onSuccess?: (context: CommandContext<T>) => void;
	onError?: (error: Error, context: CommandContext<T>) => void;
}): GenericCommand<T> {
	return {
		id: config.id,
		label: config.label,
		description: config.description,
		category: config.category,
		keybinding: config.keybinding,
		execute: config.action,
		validate: config.validator,
		onSuccess: config.onSuccess,
		onError: config.onError,
	};
}

/**
 * Create a utility command category (clear, reset, exit, etc.)
 */
export function createUtilityCommands<T = any>(
	clearAction?: (context: CommandContext<T>) => void,
	resetAction?: (context: CommandContext<T>) => void,
	exitAction?: (context: CommandContext<T>) => void,
): GenericCommand<T>[] {
	const commands: GenericCommand<T>[] = [];

	if (clearAction) {
		commands.push(
			createActionCommand(
				'clear',
				'Clear',
				'Clear all data and start fresh',
				clearAction,
			),
		);
	}

	if (resetAction) {
		commands.push(
			createActionCommand(
				'reset',
				'Reset',
				'Reset application state',
				resetAction,
			),
		);
	}

	if (exitAction) {
		commands.push(
			createActionCommand('exit', 'Exit', 'Exit the application', exitAction),
		);
	}

	return commands;
}

/**
 * Create information commands (help, status, about, etc.)
 */
export function createInfoCommands<T = any>(
	showHelpAction?: (context: CommandContext<T>) => void,
	showStatusAction?: (context: CommandContext<T>) => void,
	showAboutAction?: (context: CommandContext<T>) => void,
): GenericCommand<T>[] {
	const commands: GenericCommand<T>[] = [];

	if (showHelpAction) {
		commands.push(
			createActionCommand(
				'help',
				'Help',
				'Show help information',
				showHelpAction,
			),
		);
	}

	if (showStatusAction) {
		commands.push(
			createActionCommand(
				'status',
				'Status',
				'Show current status',
				showStatusAction,
			),
		);
	}

	if (showAboutAction) {
		commands.push(
			createActionCommand(
				'about',
				'About',
				'Show about information',
				showAboutAction,
			),
		);
	}

	return commands;
}

/**
 * Create a command group with common functionality
 */
export function createCommandGroup<T = any>(
	groupName: string,
	commands: Array<{
		id: string;
		label: string;
		description: string;
		action: (context: CommandContext<T>) => void | Promise<void>;
		keybinding?: string;
	}>,
): GenericCommand<T>[] {
	return commands.map(({id, label, description, action, keybinding}) =>
		createFullCommand({
			id,
			label,
			description,
			category: groupName,
			keybinding,
			action,
		}),
	);
}

/**
 * Create a toggle command (enable/disable functionality)
 */
export function createToggleCommand<T = any>(
	id: string,
	label: string,
	description: string,
	getState: (context: CommandContext<T>) => boolean,
	setState: (context: CommandContext<T>, enabled: boolean) => void,
): GenericCommand<T> {
	return createFullCommand({
		id,
		label,
		description,
		action: async (context: CommandContext<T>) => {
			const currentState = getState(context);
			setState(context, !currentState);
			const newState = !currentState;
			if (context.addMessage) {
				context.addMessage(
					'system',
					`${label} ${newState ? 'enabled' : 'disabled'}`,
				);
			}
		},
	});
}

/**
 * Create a navigation command (change views, pages, etc.)
 */
export function createNavigationCommand<T = any>(
	id: string,
	label: string,
	description: string,
	targetView: string,
	navigateAction: (context: CommandContext<T>, view: string) => void,
): GenericCommand<T> {
	return createFullCommand({
		id,
		label,
		description,
		category: 'Navigation',
		action: async (context: CommandContext<T>) => {
			navigateAction(context, targetView);
		},
	});
}
