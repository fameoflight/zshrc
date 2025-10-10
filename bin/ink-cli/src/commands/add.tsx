import React from 'react';
import {Text, Box} from 'ink';
import {Command, CommandConfig, CommandFlags, CommandHelp} from '../base/command.js';

/**
 * Add Command - adds two numbers and shows the output
 */
class AddCommand implements Command {
	name(): string {
		return 'add';
	}

	description(): string {
		return 'Add two numbers and show the result';
	}

	config(): CommandConfig {
		return {
			name: this.name(),
			description: this.description(),
			flags: {
				a: {
					type: 'number',
					description: 'First number to add',
					required: true,
				},
				b: {
					type: 'number',
					description: 'Second number to add',
					required: true,
				},
			},
		};
	}

	help(): CommandHelp {
		return {
			description: 'Adds two numbers together and displays the result with a visual calculation.',
			usage: 'add --a=<number> --b=<number>',
			examples: [
				'add --a=5 --b=3',
				'add --a=10.5 --b=2.3',
				'add -a=100 -b=200',
			],
			notes: [
				'Both numbers are required parameters',
				'Supports both integers and decimal numbers',
				'Results are displayed with color-coded formatting',
			],
		};
	}

	execute(flags: CommandFlags): React.ReactElement {
		const a = flags['a'] || 0;
		const b = flags['b'] || 0;
		const sum = a + b;

		return (
			<Box flexDirection="column">
				<Text color="cyan">🧮 Adding two numbers:</Text>
				<Text>
					<Text color="yellow">{a}</Text>
					{' + '}
					<Text color="yellow">{b}</Text>
					{' = '}
					<Text color="green" bold>
						{sum}
					</Text>
				</Text>
			</Box>
		);
	}
}

export default AddCommand;
