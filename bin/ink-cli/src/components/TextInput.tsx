import React from 'react';
import {Box, Text} from 'ink';

export interface TextInputProps {
	value: string;
	prefix?: string;
	suffix?: string;
	prefixColor?: string;
	prefixBold?: boolean;
	placeholder?: string;
	placeholderColor?: string;
}

/**
 * TextInput - Generic text input display component
 *
 * Pure visual component for displaying text input state.
 * Does NOT handle keyboard input - use with useTextInput hook.
 *
 * @example
 * const { value } = useTextInput({ onSubmit: handleSubmit });
 * <TextInput value={value} prefix="💬 You: " suffix="_" />
 */
const TextInput: React.FC<TextInputProps> = ({
	value,
	suffix = '_',
	placeholder = 'Type your message...',
	placeholderColor = 'gray',
}) => {
	return (
		<Box flexDirection="row" marginTop={2}>
			{value ? (
				<>
					<Text>{value}</Text>
					{suffix && <Text color="gray">{suffix}</Text>}
				</>
			) : (
				placeholder && <Text color={placeholderColor}>{placeholder}</Text>
			)}
		</Box>
	);
};

export default TextInput;
