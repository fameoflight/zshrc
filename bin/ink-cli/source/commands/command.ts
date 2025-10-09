import {ReactElement} from 'react';

export interface CommandFlags {
	[key: string]: any;
}

export interface CommandConfig {
	name: string;
	description: string;
	flags?: {
		[key: string]: {
			type: 'string' | 'number' | 'boolean';
			description?: string;
			default?: any;
			required?: boolean;
		};
	};
}

/**
 * Base Command interface - similar to Rust's CommandTrait
 * All commands must implement these methods
 */
export interface Command {
	/**
	 * Return unique command name
	 */
	name(): string;

	/**
	 * Return help text for the command
	 */
	description(): string;

	/**
	 * Get command configuration including flags
	 */
	config(): CommandConfig;

	/**
	 * Execute the command with parsed flags
	 */
	execute(flags: CommandFlags): ReactElement;
}