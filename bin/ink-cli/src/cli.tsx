#!/usr/bin/env node
import React from 'react';
import {render} from 'ink';
import meow from 'meow';
import {getRegistry} from './base/index.js';
import Help from './Help.js';
import {registerAllCommands} from './commands/index.js';

import {isDebugMode} from './common/utils.js';

registerAllCommands();

const cli = meow(
	`
	Usage
	  $ ink-cli <command> [options]

	Examples
	  $ ink-cli help
`,
	{
		importMeta: import.meta,
		flags: {},
	},
);

// Execute command or show help
const commandName = cli.input[0];
const registry = getRegistry();

if (commandName === 'help' || !commandName) {
	render(<Help />, {
		exitOnCtrlC: false,
		patchConsole: false,
	});
} else if (registry.hasCommand(commandName)) {
	const command = registry.getCommand(commandName);
	if (command) {
		const result = command.execute(cli.flags);
		render(result, {
			exitOnCtrlC: false,
			debug: isDebugMode(),
			patchConsole: false,
		});
	}
} else {
	console.error(`Unknown command: ${commandName}`);
	console.log('Run "ink-cli help" to see available commands');
	process.exit(1);
}
