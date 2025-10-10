import React, {memo} from 'react';
import {Box, Text} from 'ink';
import {ChatMessage} from '../common/types/chat.js';

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
				backgroundColor: 'black',
				name: 'You',
			};
		case 'assistant':
			return {
				prefix: '🤖',
				textColor: undefined,
				backgroundColor: undefined,
				name: 'Assistant',
			};
		case 'system':
			return {
				prefix: '⚙️',
				textColor: 'yellow',
				backgroundColor: 'black',
				name: 'System',
			};
		default:
			return {
				prefix: '❓',
				textColor: 'white',
				backgroundColor: 'black',
				name: 'Unknown',
			};
	}
}

function MessageBubble(props: IMessageBubbleProps) {
	const {message} = props;
	const {prefix, textColor, backgroundColor} = getConfig(message.role);

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
				{message.content}
			</Text>
		</Box>
	);
}

export default memo(MessageBubble);
