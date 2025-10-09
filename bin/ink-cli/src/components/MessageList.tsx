import React from 'react';
import {Box, Text} from 'ink';
import MessageBubble, {SenderConfig} from './MessageBubble.js';
import StaticList from './StaticList.js';
import MarkdownRenderer from './MarkdownRenderer.js';
import {ChatMessage} from '../common/types/chat.js';

interface MessageListProps {
	messages: ChatMessage[];
	senders: {
		user: SenderConfig;
		assistant: SenderConfig;
		system: SenderConfig;
	};
}

const MessageList: React.FC<MessageListProps> = ({messages, senders}) => {
	return (
		<StaticList items={messages}>
			{message => {
				const getSender = () => {
					switch (message.role) {
						case 'user':
							return senders.user;
						case 'assistant':
							return senders.assistant;
						case 'system':
							return senders.system;
						default:
							return senders.assistant;
					}
				};

				const getRenderer = () => {
					switch (message.role) {
						case 'user':
							return (content: string) => (
								<Box backgroundColor="gray">
									<Text color="white">{content}</Text>
								</Box>
							);
						case 'assistant':
							return (content: string) => (
								<MarkdownRenderer content={content} isStreaming={false} />
							);
						case 'system':
							return (content: string) => (
								<MarkdownRenderer content={content} isStreaming={false} />
							);
						default:
							return (content: string) => <Text>{content}</Text>;
					}
				};

				return (
					<MessageBubble
						sender={getSender()}
						content={message.content}
						renderer={getRenderer()}
					/>
				);
			}}
		</StaticList>
	);
};

export default MessageList;