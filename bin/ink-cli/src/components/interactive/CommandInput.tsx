import React, {useState, useEffect, useMemo, ReactElement} from 'react';
import {Text, Box, useInput} from 'ink';
import {useTextInput} from '../../common/hooks/useTextInput.js';

export interface CommandSuggestion {
	value: string;
	label: string;
	description?: string;
	type?: 'command' | 'argument' | 'completion';
}

export interface CommandInputProps {
	/** Current input value */
	value: string;
	/** Callback when input changes */
	onChange?: (value: string) => void;
	/** Callback when user submits input */
	onSubmit?: (value: string) => void;
	/** Callback when user cancels input */
	onCancel?: () => void;
	/** Available suggestions for autocomplete */
	suggestions?: CommandSuggestion[];
	/** Show suggestions */
	showSuggestions?: boolean;
	/** Input placeholder */
	placeholder?: string;
	/** Prefix color */
	prefixColor?: string;
	/** Whether input is disabled */
	disabled?: boolean;
	/** Custom shortcuts */
	shortcuts?: Record<string, () => void>;
	/** History navigation */
	history?: string[];
	/** Multi-line support */
	multiline?: boolean;
}

/**
 * Enhanced command input with autocomplete, history, and shortcuts
 *
 * Provides a consistent input experience across all interactive commands
 * with support for command completion, history navigation, and custom shortcuts.
 */
export function CommandInput({
	value,
	onChange,
	onSubmit,
	onCancel,
	suggestions = [],
	showSuggestions = false,
	placeholder = '> ',
	prefixColor = 'yellow',
	disabled = false,
	shortcuts = {},
	history = [],
	multiline = false,
}: CommandInputProps): ReactElement {
	const [internalValue, setInternalValue] = useState(value);
	const [historyIndex, setHistoryIndex] = useState(-1);
	const [showAutocomplete, setShowAutocomplete] = useState(false);

	// Convert suggestions to format expected by useTextInput
	const availableCommands = suggestions.map(s => ({
		value: s.value,
		label: s.label,
		description: s.description,
	}));

	// Use the text input hook for keyboard handling
	const {
		value: textInputValue,
		setValue: setTextInputValue,
		suggestions: hookSuggestions,
		showSuggestions: hookShowSuggestions,
	} = useTextInput({
		onSubmit: submittedValue => {
			if (onSubmit) {
				onSubmit(submittedValue);
			}
			setHistoryIndex(-1);
			setShowAutocomplete(false);
		},
		onCancel: () => {
			if (onCancel) {
				onCancel();
			}
			setShowAutocomplete(false);
		},
		onCommandSelect: command => {
			setShowAutocomplete(false);
		},
		availableCommands,
		shortcuts: {
			...shortcuts,
			// Add escape key handler
			escape: () => {
				if (showAutocomplete) {
					setShowAutocomplete(false);
				} else if (onCancel) {
					onCancel();
				}
			},
		},
		multiline,
		disabled,
	});

	// Sync with external value
	useEffect(() => {
		if (value !== textInputValue) {
			setTextInputValue(value);
		}
	}, [value, setTextInputValue]);

	// Filter suggestions based on current input
	const filteredSuggestions = useMemo(() => {
		if (!showAutocomplete || !internalValue.trim()) {
			return [];
		}

		const searchTerm = internalValue.toLowerCase();
		return suggestions
			.filter(
				suggestion =>
					suggestion.label.toLowerCase().includes(searchTerm) ||
					suggestion.value.toLowerCase().includes(searchTerm),
			)
			.slice(0, 8); // Limit to 8 suggestions
	}, [internalValue, suggestions, showAutocomplete]);

	// Handle input changes
	const handleChange = (newValue: string) => {
		setTextInputValue(newValue);
		onChange?.(newValue);

		// Show autocomplete if we have suggestions and input starts with relevant prefix
		const shouldShowAutocomplete = Boolean(
			newValue.trim() &&
				(newValue.startsWith('/') || // Commands
					suggestions.some(s =>
						s.label.toLowerCase().startsWith(newValue.toLowerCase()),
					)),
		);
		setShowAutocomplete(shouldShowAutocomplete);
	};

	// History navigation is handled by useTextInput hook

	return (
		<Box flexDirection="column" width="100%">
			{/* Autocomplete suggestions */}
			{hookShowSuggestions && hookSuggestions.length > 0 && (
				<Box flexDirection="column" marginBottom={1}>
					{hookSuggestions.map((suggestion, index) => (
						<Box key={suggestion.value} flexDirection="row" paddingLeft={2}>
							<Text color="gray">
								{index === 0 ? '→' : ' '} {suggestion.label}
							</Text>
							{suggestion.description && (
								<Text color="dimColor">
									{' - '}
									{suggestion.description}
								</Text>
							)}
						</Box>
					))}
					<Box paddingLeft={2}>
						<Text color="dimColor">
							Press Tab to autocomplete, Escape to cancel
						</Text>
					</Box>
				</Box>
			)}

			{/* Input field */}
			<Box flexDirection="row" alignItems="center">
				<Text color={prefixColor}>{placeholder}</Text>
				<Text>{textInputValue}_</Text>
			</Box>
		</Box>
	);
}

export interface QuickCommandBarProps {
	/** Available quick commands */
	commands: Array<{
		key: string;
		label: string;
		description: string;
		action: () => void;
	}>;
	/** Show shortcuts help */
	showHelp?: boolean;
}

/**
 * Quick command bar for frequently used actions
 */
export function QuickCommandBar({
	commands,
	showHelp = true,
}: QuickCommandBarProps): ReactElement {
	return (
		<Box
			flexDirection="row"
			justifyContent="space-between"
			paddingLeft={1}
			paddingRight={1}
		>
			<Box flexDirection="row" gap={2}>
				{commands.map(cmd => (
					<Box key={cmd.key}>
						<Text color="cyan" bold>
							{cmd.key}
						</Text>
						<Text color="gray"> {cmd.label}</Text>
					</Box>
				))}
			</Box>

			{showHelp && (
				<Text color="dimColor">Type /help for commands, /exit to quit</Text>
			)}
		</Box>
	);
}
