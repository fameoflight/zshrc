import React from 'react';
import {Text} from 'ink';

interface MarkdownRendererProps {
	content: string;
	isStreaming?: boolean;
}

/**
 * MarkdownRenderer - Renders content as plain text
 *
 * Simplified version that just renders plain text.
 * Markdown libraries for Ink have rendering issues.
 */
const MarkdownRenderer: React.FC<MarkdownRendererProps> = ({
	content,
	isStreaming = false,
}) => {
	if (!content.trim()) {
		return null;
	}

	if (isStreaming) {
		// For streaming, show content as is
		return <Text>{content}</Text>;
	}

	// Just render as plain text - markdown libraries for Ink don't work well
	return <Text>{content}</Text>;
};

MarkdownRenderer.displayName = 'MarkdownRenderer';

export default MarkdownRenderer;
