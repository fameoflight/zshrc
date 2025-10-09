import React, {memo} from 'react';
import {Text, Box} from 'ink';

export interface SenderConfig {
	name: string;
	color: string;
	icon?: string;
}

export interface MessageBubbleProps {
	sender: SenderConfig;
	content: string;
	renderer?: (content: string) => React.ReactElement;
	backgroundColor?: string;
}

/**
 * MessageBubble - Generic message display component
 *
 * Displays a message from any sender with customizable rendering.
 * Works for chat messages, logs, notifications, etc.
 *
 * @example
 * <MessageBubble
 *   sender={{ name: 'Assistant', color: 'cyan', icon: '🤖' }}
 *   content="Hello!"
 *   renderer={(text) => <MarkdownRenderer content={text} />}
 * />
 */
const MessageBubble: React.FC<MessageBubbleProps> = memo(
	({sender, content, renderer, backgroundColor}) => {
		if (!renderer) {
			return (
				<Text>
					{sender.icon && `${sender.icon} `}
					{sender.name}:{' '}
					<Text backgroundColor={backgroundColor}>{content}</Text>
				</Text>
			);
		}

		return (
			<>
				<Text>
					{sender.icon && `${sender.icon} `}
					{sender.name}:
				</Text>

				<Box marginLeft={2} flexDirection="column">
					{renderer(content)}
				</Box>
			</>
		);
	},
);

MessageBubble.displayName = 'MessageBubble';

export default MessageBubble;
