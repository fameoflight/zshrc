import {useState} from 'react';
import {useInput} from 'ink';

export interface UseTextInputOptions {
	onSubmit?: (value: string) => void;
	onCancel?: () => void;
	onCommandTrigger?: () => void;
	shortcuts?: Record<string, () => void>;
	multiline?: boolean;
	disabled?: boolean;
}

export interface UseTextInputResult {
	value: string;
	setValue: (value: string) => void;
	clear: () => void;
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
		onCommandTrigger,
		shortcuts = {},
		multiline = false,
		disabled = false,
	} = options;

	const [value, setValue] = useState('');

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

			// Handle regular character input
			if (input && !key.ctrl && !key.meta) {
				const newValue = value + input;

				// Check if user typed "/" at the beginning of input
				if (input === '/' && value === '' && onCommandTrigger) {
					onCommandTrigger();
					return; // Don't add "/" to the input value
				}

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
	};
}
