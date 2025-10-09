#!/usr/bin/env node
import React from 'react';
import {render} from 'ink';
import meow from 'meow';
import {registerCommands, getCommandNames, getRegistry} from './commands/index.js';
import App from './app.js';

// Register all available commands
registerCommands();
const commandNames = getCommandNames();
const registry = getRegistry();

// Build help text dynamically from commands
const commandsHelp = commandNames
	.map(name => {
		const command = registry.getCommand(name);
		if (!command) return '';
		const config = command.config();
		const flags = Object.entries(config.flags || {})
			.map(([flagName, flagConfig]) => {
				const required = flagConfig.required ? ' (required)' : '';
				const defaultValue = flagConfig.default !== undefined ? ` [default: ${flagConfig.default}]` : '';
				return `    --${flagName}  ${flagConfig.description}${required}${defaultValue}`;
			})
			.join('\n');

		return `  ${name}\n    ${config.description}\n${flags ? flags + '\n' : ''}`;
	})
	.join('\n');

const cli = meow(
	`
	Usage
	  $ ink-cli <command> [options]

	Commands
${commandsHelp}
	Examples
	  $ ink-cli add --a=5 --b=3
	  🧮 Adding two numbers:
	  5 + 3 = 8
`,
	{
		importMeta: import.meta,
		flags: {
			name: {
				type: 'string',
			},
		},
	},
);

// Determine which command to execute
const commandName = cli.input[0];
const flags = cli.flags;

if (commandName && registry.hasCommand(commandName)) {
	const command = registry.getCommand(commandName);
	if (command) {
		const result = command.execute(flags);
		render(result);
	}
} else {
	// Show help or default app
	if (commandName) {
		console.error(`Unknown command: ${commandName}`);
	}

	// Show available commands if no command provided
	if (!commandName) {
		render(
			<App name={cli.flags.name} />
		);
	} else {
		cli.showHelp();
	}
}
