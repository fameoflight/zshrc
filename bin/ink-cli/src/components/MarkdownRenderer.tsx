import {Text} from 'ink';
import Markdown from '@jescalan/ink-markdown';

interface MarkdownRendererProps {
	content: string;
	isStreaming?: boolean;
}

function MarkdownRenderer({
	content,
	isStreaming = false,
}: MarkdownRendererProps) {
	if (isStreaming) {
		// For streaming, just render raw content to avoid flicker
		// The markdown processing happens when streaming ends
		return <Text>{content}</Text>;
	}

	// For non-streaming content, render the full markdown at once
	return <Markdown>{content}</Markdown>;
}

export default MarkdownRenderer;
