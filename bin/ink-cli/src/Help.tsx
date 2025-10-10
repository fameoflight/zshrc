import {Text, Box, Newline} from 'ink';
import {getRegistry} from './base/index.js';

interface IHelpProps {}

function Help(_props: IHelpProps) {
	const registry = getRegistry();
	const commandNames = registry.getCommandNames();

	const formatCommandHelp = (name: string) => {
		const command = registry.getCommand(name);
		if (!command) return null;

		const config = command.config();
		const help = command.help();
		const flags = Object.entries(config.flags || {});

		const flagTexts = flags.map(([flagName, flagConfig]) => {
			const required = flagConfig.required ? ' (required)' : '';
			const defaultValue =
				flagConfig.default !== undefined
					? ` [default: ${flagConfig.default}]`
					: '';
			return `    --${flagName}  ${flagConfig.description}${required}${defaultValue}`;
		});

		return (
			<Box key={name} flexDirection="column" marginBottom={2}>
				<Box flexDirection="column" marginBottom={1}>
					<Text color="cyan" bold>
						{name}
					</Text>
					<Text color="white">{help.description}</Text>
				</Box>

				{help.usage && (
					<Box flexDirection="column" marginBottom={1}>
						<Text color="magenta" bold>
							Usage:
						</Text>
						<Text color="gray">{help.usage}</Text>
					</Box>
				)}

				{flagTexts.length > 0 && (
					<Box flexDirection="column" marginBottom={1}>
						<Text color="magenta" bold>
							Flags:
						</Text>
						{flagTexts.map((flagText, index) => (
							<Text key={index} color="gray">
								{flagText}
							</Text>
						))}
					</Box>
				)}

				{help.examples.length > 0 && (
					<Box flexDirection="column" marginBottom={1}>
						<Text color="magenta" bold>
							Examples:
						</Text>
						{help.examples.map((example, index) => (
							<Text key={index} color="gray">
								ink-cli {example}
							</Text>
						))}
					</Box>
				)}

				{help.notes && help.notes.length > 0 && (
					<Box flexDirection="column">
						<Text color="magenta" bold>
							Notes:
						</Text>
						{help.notes.map((note, index) => (
							<Text key={index} color="dim">
								• {note}
							</Text>
						))}
					</Box>
				)}
			</Box>
		);
	};

	return (
		<Box flexDirection="column">
			<Text color="green" bold underline>
				ink-cli - Interactive Command Line Interface
			</Text>
			<Newline />
			<Text color="yellow" bold>
				Usage:
			</Text>
			<Text> ink-cli {'<command>'} [options]</Text>
			<Text> ink-cli help</Text>
			<Newline />
			<Text color="yellow" bold>
				Available Commands:
			</Text>
			{commandNames.length > 0 ? (
				commandNames.map(formatCommandHelp)
			) : (
				<Text color="red">No commands registered</Text>
			)}
			<Newline />
			<Text color="dim" italic>
				Tip: Each command provides detailed examples and usage information
			</Text>
		</Box>
	);
}

export default Help;
