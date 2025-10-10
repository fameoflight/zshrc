import React, {memo} from 'react';
import {Box, Text} from 'ink';

interface StreamingContentProps<T = string> {
	content: T;
	isStreaming?: boolean;
	prefix?: string;
	textColor?: string;
	progress?: number;
	showCursor?: boolean;
	renderContent?: (content: T) => React.ReactNode;
}

/**
 * StreamingContent - Generic streaming display component
 *
 * Optimized for displaying streaming content with minimal re-renders.
 * Works with any data type - strings, arrays, or objects.
 */
const StreamingContent: React.FC<StreamingContentProps> = memo(({
	content,
	isStreaming = false,
	prefix = '📡',
	textColor,
	progress,
	showCursor = true,
	renderContent,
}) => {
	const renderDefaultContent = () => {
		if (renderContent) {
			return renderContent(content);
		}

		// Default rendering for strings
		if (typeof content === 'string') {
			return content + (isStreaming && showCursor ? '▌' : '');
		}

		// For other types, convert to string
		return String(content);
	};

	return (
		<Box
			flexDirection="column"
			justifyContent="center"
			alignItems="flex-start"
		>
			<Text color={textColor}>
				{prefix && `${prefix}: `}
				{renderDefaultContent()}
			</Text>
			{isStreaming && progress !== undefined && (
				<Text color="gray" dimColor>
					{Math.round(progress)}% complete
				</Text>
			)}
		</Box>
	);
});

StreamingContent.displayName = 'StreamingContent';

export default StreamingContent;