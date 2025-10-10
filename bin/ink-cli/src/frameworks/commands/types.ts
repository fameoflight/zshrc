/**
 * Generic command system types
 */

export interface CommandContext<T = any> {
	state?: T;
	setError?: (error: string | null) => void;
	addMessage?: (role: string, content: string) => void;
	clearMessages?: () => void;
	[key: string]: any;
}

export interface GenericCommand<T = any> {
	id: string;
	label: string;
	description: string;
	category?: string;
	keybinding?: string;
	hidden?: boolean;
	disabled?: boolean;
	execute: (context: CommandContext<T>) => void | Promise<void>;
	validate?: (context: CommandContext<T>) => boolean;
	onSuccess?: (context: CommandContext<T>) => void;
	onError?: (error: Error, context: CommandContext<T>) => void;
}

export interface CommandRegistryOptions {
	caseSensitive?: boolean;
	allowDuplicates?: boolean;
	onCommandRegistered?: (command: GenericCommand) => void;
	onCommandExecuted?: (command: GenericCommand, context: CommandContext) => void;
	onCommandError?: (command: GenericCommand, error: Error, context: CommandContext) => void;
}

export interface CommandExecutionResult {
	command: GenericCommand;
	success: boolean;
	error?: Error;
	duration: number;
}

export interface CommandCategory {
	id: string;
	label: string;
	description?: string;
	icon?: string;
	commands: GenericCommand[];
}