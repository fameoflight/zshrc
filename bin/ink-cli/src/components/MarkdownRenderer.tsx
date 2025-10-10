import {Text, Newline} from 'ink';
import Markdown from '@jescalan/ink-markdown';

interface MarkdownRendererProps {
	content: string;
	isStreaming?: boolean;
	textColor?: string;
}

function MarkdownRenderer({
	content,
	isStreaming = false,
	textColor,
}: MarkdownRendererProps) {
	if (isStreaming) {
		// For streaming, just render raw content to avoid flicker
		// The markdown processing happens when streaming ends
		return <Text color={textColor}>{content}</Text>;
	}

	// For non-streaming content, render the full markdown at once
	// Add some spacing around markdown content for better readability
	return (
		<>
			<Markdown>{content}</Markdown>
			<Newline />
		</>
	);
}

export default MarkdownRenderer;
