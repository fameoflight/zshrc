import {memo} from 'react';
import {Box, Text} from 'ink';
import {ChatMessage} from '../common/types/chat.js';
import MarkdownRenderer from '../components/MarkdownRenderer.js';

export interface SenderConfig {
	name: string;
	color: string;
	icon?: string;
}

interface IMessageBubbleProps {
	message: ChatMessage;
}

function getConfig(role: ChatMessage['role']) {
	switch (role) {
		case 'user':
			return {
				prefix: '👤',
				textColor: 'white',
				backgroundColor: undefined,
				name: 'You',
			};
		case 'assistant':
			return {
				prefix: '🤖',
				textColor: 'green',
				backgroundColor: undefined,
				name: 'Assistant',
			};
		case 'system':
			return {
				prefix: '⚙️',
				textColor: 'yellow',
				backgroundColor: undefined,
				name: 'System',
			};
		default:
			return {
				prefix: '❓',
				textColor: 'white',
				backgroundColor: undefined,
				name: 'Unknown',
			};
	}
}

function MessageBubble(props: IMessageBubbleProps) {
	const {message} = props;
	const {prefix, textColor, backgroundColor} = getConfig(message.role);

	const renderer = (text: string) => {
		if (message.role === 'user') {
			return <Text>{text}</Text>;
		} else {
			return <MarkdownRenderer content={text} isStreaming={false} />;
		}
	};

	return (
		<Box
			flexDirection="column"
			backgroundColor={backgroundColor}
			justifyContent="center"
			alignItems="flex-start"
		>
			<Text color={textColor}>
				{prefix}
				{': '}
				{renderer(message.content)}
			</Text>
		</Box>
	);
}

export default memo(MessageBubble);
