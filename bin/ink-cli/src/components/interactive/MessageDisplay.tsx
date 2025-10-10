import React, {ReactElement} from 'react';
import {Box, Text, Newline} from 'ink';
import MessageBubble from '../MessageBubble';
import StreamingMessage from '../StreamingMessage';
import {ChatMessage} from '../../common/types/chat';

export interface ExtendedChatMessage extends ChatMessage {
	id: string;
	timestamp: Date;
	metadata?: Record<string, any>;
}

export interface MessageDisplayProps {
	/** Array of messages to display */
	messages: ExtendedChatMessage[];
	/** Current streaming response */
	currentResponse?: string;
	/** Whether streaming is active */
	isStreaming?: boolean;
	/** Show timestamps */
	showTimestamps?: boolean;
	/** Show message IDs (for debugging) */
	showIds?: boolean;
	/** Custom message renderer */
	renderMessage?: (message: ExtendedChatMessage) => ReactElement;
	/** Max messages to display (for performance) */
	maxMessages?: number;
	/** Auto-scroll to bottom */
	autoScroll?: boolean;
	/** Compact mode (less spacing) */
	compact?: boolean;
}

/**
 * Standardized message display component for interactive commands
 *
 * Handles different message types, streaming responses, and provides
 * a consistent display format across all interactive commands.
 */
export function MessageDisplay({
	messages,
	currentResponse = '',
	isStreaming = false,
	showTimestamps = false,
	showIds = false,
	renderMessage,
	maxMessages,
	autoScroll = true,
	compact = false,
}: MessageDisplayProps): ReactElement {
	// Limit messages for performance
	const displayMessages = maxMessages
		? messages.slice(-maxMessages)
		: messages;

	// Convert to MessageBubble format for compatibility
	const compatibleMessages = displayMessages.map(msg => ({
		id: msg.id,
		role: msg.role,
		content: msg.content,
		timestamp: msg.timestamp,
	}));

	// Custom message renderer or default
	const MessageRenderer = renderMessage || DefaultMessageRenderer;

	return (
		<Box flexDirection="column" width="100%">
			{displayMessages.map((message, index) => (
				<Box key={message.id} flexDirection="column" marginBottom={compact ? 0 : 1}>
					{showIds && (
						<Text color="dimColor" dimColor>
							[{message.id}]
						</Text>
					)}
					{showTimestamps && (
						<Text color="dimColor" dimColor>
							{message.timestamp.toLocaleTimeString()}{' '}
						</Text>
					)}
					<MessageRenderer message={message} />
				</Box>
			))}

			{/* Streaming response */}
			{isStreaming && currentResponse && (
				<Box flexDirection="column" marginBottom={compact ? 0 : 1}>
					{showTimestamps && (
						<Text color="dimColor" dimColor>
							{new Date().toLocaleTimeString()}{' '}
						</Text>
					)}
					<StreamingMessage content={currentResponse} />
				</Box>
			)}

			{/* Thinking indicator */}
			{isStreaming && !currentResponse && (
				<Box flexDirection="row" marginBottom={compact ? 0 : 1}>
					{showTimestamps && (
						<Text color="dimColor" dimColor>
							{new Date().toLocaleTimeString()}{' '}
						</Text>
					)}
					<Text color="gray">🤔 Thinking...</Text>
				</Box>
			)}

			{/* Auto-scroll indicator */}
			{autoScroll && displayMessages.length > 0 && (
				<Box height={1}>
					<Text color="dimColor" dimColor>
						{'↓'}
					</Text>
				</Box>
			)}
		</Box>
	);
}

/**
 * Default message renderer using MessageBubble component
 */
function DefaultMessageRenderer({message}: {message: ExtendedChatMessage}): ReactElement {
	// Use the existing MessageBubble component for compatibility
	return (
		<MessageBubble
			message={{
				role: message.role,
				content: message.content,
			}}
		/>
	);
}

export interface WelcomeMessageProps {
	/** Title of the welcome message */
	title?: string;
	/** Description text */
	description?: string;
	/** Additional tips */
	tips?: string[];
	/** Show shortcuts */
	shortcuts?: Record<string, string>;
	/** Welcome color */
	color?: string;
}

/**
 * Welcome message component for initial screen
 */
export function WelcomeMessage({
	title = 'Welcome!',
	description = 'Start typing your message and press Enter to send.',
	tips = ['Type / to see available commands'],
	shortcuts = {'Escape': 'Exit', 'Ctrl+C': 'Quit'},
	color = 'green',
}: WelcomeMessageProps): ReactElement {
	return (
		<Box flexDirection="column" marginBottom={1}>
			<Text color={color} bold>
				{title}
			</Text>
			<Text>{description}</Text>

			{tips.length > 0 && (
				<>
					{tips.map((tip, index) => (
						<Text key={index} color="gray">
							{tip}
						</Text>
					))}
				</>
			)}

			{shortcuts && Object.keys(shortcuts).length > 0 && (
				<Box flexDirection="column" marginTop={1}>
					<Text color="dimColor" bold>
						Quick shortcuts:
					</Text>
					{Object.entries(shortcuts).map(([key, desc]) => (
						<Text key={key} color="dimColor">
							• {key}: {desc}
						</Text>
					))}
				</Box>
			)}
		</Box>
	);
}

export interface ErrorMessageProps {
	/** Error message */
	error: string;
	/** Error title */
	title?: string;
	/** Show retry suggestion */
	showRetry?: boolean;
	/** Custom action */
	action?: string;
	/** On action click */
	onAction?: () => void;
}

/**
 * Error message component for consistent error display
 */
export function ErrorMessage({
	error,
	title = 'Error',
	showRetry = true,
	action,
	onAction,
}: ErrorMessageProps): ReactElement {
	return (
		<Box flexDirection="column" marginBottom={1}>
			<Text color="red" bold>
				❌ {title}
			</Text>
			<Text color="red">{error}</Text>

			{showRetry && (
				<Text color="gray">
					Try again or type /help for available commands.
				</Text>
			)}

			{action && onAction && (
				<Text color="cyan">
					Type '{action}' to {action.toLowerCase()}
				</Text>
			)}
		</Box>
	);
}

export interface LoadingMessageProps {
	/** Loading message */
	message?: string;
	/** Show spinner */
	showSpinner?: boolean;
	/** Loading color */
	color?: string;
}

/**
 * Loading message component
 */
export function LoadingMessage({
	message = 'Loading...',
	showSpinner = true,
	color = 'blue',
}: LoadingMessageProps): ReactElement {
	return (
		<Box flexDirection="row" marginBottom={1}>
			{showSpinner && (
				<Text color={color}>
					🔄{' '}
				</Text>
			)}
			<Text color={color}>
				{message}
			</Text>
		</Box>
	);
}