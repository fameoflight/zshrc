import React, {memo} from 'react';
import {Box, Text} from 'ink';

interface StreamingMessageProps {
	content: string;
	prefix?: string;
	textColor?: string;
}

/**
 * StreamingMessage - Optimized component for streaming text display
 *
 * This component is specifically designed to handle streaming text with minimal
 * re-renders. It renders directly without additional markdown processing during
 * streaming to prevent flickering.
 */
const StreamingMessage: React.FC<StreamingMessageProps> = memo(({content, prefix = '🤖', textColor}) => {
	return (
		<Box
			flexDirection="column"
			justifyContent="center"
			alignItems="flex-start"
		>
			<Text color={textColor}>
				{prefix}
				{': '}
				{content}
				{'▌'}
			</Text>
		</Box>
	);
});

StreamingMessage.displayName = 'StreamingMessage';

export default StreamingMessage;