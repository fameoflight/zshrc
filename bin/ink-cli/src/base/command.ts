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

export interface CommandHelp {
	description: string;
	examples: string[];
	usage?: string;
	notes?: string[];
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
	 * Return brief description for the command
	 */
	description(): string;

	/**
	 * Get command configuration including flags
	 */
	config(): CommandConfig;

	/**
	 * Return detailed help information with examples
	 */
	help(): CommandHelp;

	/**
	 * Execute the command with parsed flags
	 */
	execute(flags: CommandFlags): ReactElement;
}