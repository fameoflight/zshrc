import {useState, useMemo} from 'react';
import {useInput} from 'ink';

export interface UseTextInputOptions {
	onSubmit?: (value: string) => void;
	onCancel?: () => void;
	onCommandTrigger?: () => void;
	onCommandSelect?: (command: string) => void;
	availableCommands?: Array<{value: string; label: string; description?: string}>;
	shortcuts?: Record<string, () => void>;
	multiline?: boolean;
	disabled?: boolean;
}

export interface UseTextInputResult {
	value: string;
	setValue: (value: string) => void;
	clear: () => void;
	suggestions: Array<{value: string; label: string; description?: string}>;
	showSuggestions: boolean;
}

/**
 * useTextInput - Generic text input with keyboard handling
 *
 * Handles keyboard input for text entry with customizable shortcuts.
 * Works for chat input, search bars, forms, etc.
 *
 * @example
 * const { value } = useTextInput({
 *   onSubmit: (text) => sendMessage(text),
 *   shortcuts: {
 *     'l': clearHistory,  // Ctrl+L
 *     'k': searchUp        // Ctrl+K
 *   }
 * });
 */
export function useTextInput(
	options: UseTextInputOptions = {},
): UseTextInputResult {
	const {
		onSubmit,
		onCancel,
		onCommandSelect,
		availableCommands = [],
		shortcuts = {},
		multiline = false,
		disabled = false,
	} = options;

	const [value, setValue] = useState('');

	// Filter suggestions based on current input
	const suggestions = useMemo(() => {
		if (!value.startsWith('/')) {
			return [];
		}

		// If user just typed '/', show all commands
		if (value.length === 1) {
			return availableCommands.slice(0, 10); // Show up to 10 commands
		}

		// Otherwise filter commands based on input
		const searchTerm = value.toLowerCase();
		return availableCommands.filter(cmd =>
			cmd.label.toLowerCase().includes(searchTerm) ||
			cmd.value.toLowerCase().includes(searchTerm)
		).slice(0, 5); // Limit to 5 suggestions when filtering
	}, [value, availableCommands]);

	const showSuggestions = value.startsWith('/') && suggestions.length > 0;

	useInput(
		(input, key) => {
			// Handle Return key
			if (key.return) {
				if (multiline && key.shift) {
					// Shift+Enter adds newline in multiline mode
					setValue(prev => prev + '\n');
					return;
				}

				if (onSubmit && value.trim()) {
					onSubmit(value.trim());
					setValue('');
				}
				return;
			}

			// Handle Escape key
			if (key.escape) {
				if (onCancel) {
					onCancel();
				}
				return;
			}

			// Handle custom shortcuts (Ctrl+key)
			if (key.ctrl && input && shortcuts[input]) {
				shortcuts[input]();
				return;
			}

			// Handle backspace/delete
			if (key.backspace || key.delete) {
				setValue(prev => prev.slice(0, -1));
				return;
			}

			// Handle Tab key for autocomplete
			if (key.tab && showSuggestions && suggestions.length > 0) {
				const selected = suggestions[0];
				if (selected) {
					setValue(selected.label);
					if (onCommandSelect) {
						onCommandSelect(selected.value);
					}
				}
				return;
			}

			// Handle regular character input
			if (input && !key.ctrl && !key.meta) {
				const newValue = value + input;
				setValue(newValue);
			}
		},
		{isActive: !disabled},
	);

	const clear = () => setValue('');

	return {
		value,
		setValue,
		clear,
		suggestions,
		showSuggestions,
	};
}
