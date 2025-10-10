import React, {useState, useMemo} from 'react';
import {Text, Box, Newline, useApp, useInput} from 'ink';
import BottomBar from '../components/BottomBar.js';
import MessageBubble from '../components/MessageBubble.js';
import InfoSection, {InfoItem} from '../components/InfoSection.js';
import TextInput from '../components/TextInput.js';
import SplitLayout from '../components/SplitLayout.js';
import {
	Command,
	CommandConfig,
	CommandFlags,
	CommandHelp,
} from '../base/command.js';
import {StreamChunk} from '../common/llm/index.js';
import {DEFAULT_LLM_CONFIG} from '../common/llm/config.js';
import {useStreamBuffer} from '../common/hooks/useStreamBuffer.js';
import {useLLMService} from '../common/hooks/useLLMService.js';
import {useTextInput} from '../common/hooks/useTextInput.js';
import {useChatMessages} from '../common/hooks/useChatMessages.js';
import {CHAT_COMMANDS, ChatContext} from '../common/chatCommands.js';
import {ChatMessage, ChatRole} from '../common/types/chat.js';
import SelectInput from 'ink-select-input';
import {
	computeChatStatus,
	computeInfoText,
	getShortcuts,
} from '../common/utils/chatStatus.js';
import StaticList from '../components/StaticList.js';

interface LLMChatFlags extends CommandFlags {
	provider?: string;
	baseurl?: string;
	apikey?: string;
	model?: string;
	'system-prompt'?: string;
	temperature?: number;
	'max-tokens'?: number;
}

/**
 * LLM Chat Command - Interactive chat with any OpenAI-compatible LLM
 */
class LLMChatCommand implements Command {
	name(): string {
		return 'llm-chat';
	}

	description(): string {
		return 'Interactive chat with OpenAI-compatible LLM (LM Studio, Ollama, OpenAI, etc.)';
	}

	config(): CommandConfig<LLMChatFlags> {
		return {
			name: this.name(),
			description: this.description(),
			flags: {
				provider: {
					type: 'string',
					description: 'LLM provider preset (lmstudio)',
					default: 'lmstudio',
				},
				baseurl: {
					type: 'string',
					description: 'Custom API base URL (overrides provider)',
				},
				apikey: {
					type: 'string',
					description: 'API key for providers that require authentication',
				},
				model: {
					type: 'string',
					description: 'Model name to use',
				},
				'system-prompt': {
					type: 'string',
					description: 'System prompt to set conversation context',
				},
				temperature: {
					type: 'number',
					description: 'Temperature for response randomness (0.0-2.0)',
				},
				'max-tokens': {
					type: 'number',
					description: 'Maximum tokens in response',
				},
			},
		};
	}

	help(): CommandHelp {
		return {
			description:
				'Start an interactive chat session with persistent conversation context using any OpenAI-compatible LLM provider.',
			usage: 'llm-chat [OPTIONS]',
			examples: [
				'llm-chat',
				'llm-chat --provider=openai --apikey=sk-...',
				'llm-chat --provider=ollama --model=llama2',
				'llm-chat --baseurl=http://localhost:8080 --model=custom-model',
				'llm-chat --system-prompt="You are a helpful assistant"',
			],
			notes: [
				'Default provider is LM Studio (localhost:1234)',
				'Supports streaming responses for real-time interaction',
				'Conversation context is maintained throughout the session',
				'Use Ctrl+L to clear conversation history',
				'Use Ctrl+C to exit the chat',
				'Provider presets: lmstudio, openai, ollama',
			],
		};
	}

	execute(flags: LLMChatFlags): React.ReactElement {
		return <LLMChatComponent flags={flags} />;
	}
}

const LLMChatComponent: React.FC<{flags: LLMChatFlags}> = ({flags}) => {
	const {exit} = useApp();

	// State
	const [showWelcome, setShowWelcome] = useState(true);
	const [isInterrupting, setIsInterrupting] = useState(false);
	const [showCommandSelector, setShowCommandSelector] = useState(false);
	const [abortController, setAbortController] =
		useState<AbortController | null>(null);

	// Initialize LLM service
	const {llmService, isInitialized, error, resolvedProvider, setError} =
		useLLMService({
			flags,
			defaultConfig: DEFAULT_LLM_CONFIG,
			loggerName: 'llm-chat',
		});

	// Manage chat messages
	const {messages, messageCount, addMessage, clearMessages} = useChatMessages({
		systemPrompt: llmService?.getConfig()?.systemPrompt,
	});

	// Handle streaming responses
	const {
		currentResponse,
		isStreaming,
		handleChunk,
		resetBuffer,
		setIsStreaming,
	} = useStreamBuffer({
		batchInterval: 5,
		onComplete: content => {
			addMessage('assistant', content);
		},
		onError: err => setError(err),
	});

	// Handle text input
	const {value: currentInput} = useTextInput({
		onSubmit: sendMessage,
		onCommandTrigger: () => {
			setShowCommandSelector(true);
		},
		shortcuts: {
			c: () => exit(),
			l: () => {
				clearMessages();
				setShowWelcome(true);
			},
		},
		disabled: isStreaming || !llmService || showCommandSelector,
	});

	// Send message to LLM
	async function sendMessage(userMessage: string) {
		if (!llmService || isStreaming) return;

		// Add user message and start streaming
		addMessage('user', userMessage);
		resetBuffer();
		setIsStreaming(true);
		setShowWelcome(false);
		setError(null);
		setIsInterrupting(false);

		// Create abort controller
		const controller = new AbortController();
		setAbortController(controller);

		try {
			const messagesWithSystem = messages.concat([
				{role: 'user' as ChatRole, content: userMessage},
			]);

			// Prepend system prompt if configured
			const config = llmService.getConfig();
			const finalMessages =
				config.systemPrompt && messagesWithSystem[0]?.role !== 'system'
					? [
							{role: 'system' as ChatRole, content: config.systemPrompt},
							...messagesWithSystem,
					  ]
					: messagesWithSystem;

			// Stream response
			await llmService.streamChat(finalMessages, (chunk: StreamChunk) => {
				if (controller.signal.aborted) return;
				handleChunk(chunk);
			});
		} catch (err) {
			if (controller.signal.aborted) {
				// Interrupted - add partial response
				if (currentResponse) {
					addMessage(
						'assistant',
						currentResponse + '\n\n*(Response interrupted)*',
					);
				}
				setIsStreaming(false);
				setIsInterrupting(false);
			} else {
				setError(err instanceof Error ? err.message : String(err));
				setIsStreaming(false);
			}
		} finally {
			setAbortController(null);
		}
	}

	// Execute command
	async function executeCommand(commandValue: string) {
		const command = CHAT_COMMANDS.find(cmd => cmd.value === commandValue);
		if (!command) return;

		const chatContext: ChatContext = {
			messages,
			messageCount,
			clearMessages: () => {
				clearMessages();
				setShowWelcome(true);
			},
			addMessage,
			currentResponse,
			isStreaming,
			setError,
		};

		try {
			await command.execute(chatContext);
		} catch (err) {
			setError(err instanceof Error ? err.message : String(err));
		}

		setShowCommandSelector(false);
	}

	// Handle command selection
	const handleCommandSelect = (item: {label: string; value: string}) => {
		executeCommand(item.value);
	};

	// Handle escape key and Ctrl+C for command selector
	useInput(
		(input, key) => {
			if (showCommandSelector) {
				if (key.escape) {
					setShowCommandSelector(false);
				} else if (key.ctrl && input === 'c') {
					exit();
				}
			}
		},
		{isActive: showCommandSelector},
	);

	// Handle escape key - interrupt streaming
	if (isStreaming && abortController) {
		// This will be handled by useTextInput with escape key
		// We just need to expose the abort function
	}

	// Compute status and info for bottom bar
	const chatState = useMemo(
		() => ({
			isStreaming,
			isInterrupting,
			isInitialized,
			error: error || null,
			currentInput,
			messageCount,
		}),
		[
			isStreaming,
			isInterrupting,
			isInitialized,
			error,
			currentInput,
			messageCount,
		],
	);

	const status = computeChatStatus(chatState);
	const info = computeInfoText(messageCount, resolvedProvider);
	const shortcuts = getShortcuts(isStreaming, !!error);

	// Header info items
	const headerInfo: InfoItem[] = [
		{
			label: 'Base URL',
			value: flags.baseurl || llmService?.getConfig()?.baseURL || 'Unknown',
			valueColor: 'gray',
		},
	];

	if (llmService?.getConfig()?.systemPrompt) {
		headerInfo.push({
			label: 'System Prompt',
			value: llmService.getConfig().systemPrompt!,
			valueColor: 'gray',
			icon: '📋',
		});
	}

	return (
		<SplitLayout
			header={
				<InfoSection
					title={`LLM Chat - ${resolvedProvider}`}
					titleIcon="🤖"
					titleColor="blue"
					items={headerInfo}
				/>
			}
			footer={
				showCommandSelector ? (
					<Box flexDirection="column">
						<Box width="100%">
							<Text color="gray">
								{'─'.repeat(process.stdout.columns || 80)}
							</Text>
						</Box>
						<Box borderColor="cyan" padding={1} flexDirection="column">
							<Text color="cyan" bold>
								🔧 Select a command:
							</Text>
							<SelectInput
								items={CHAT_COMMANDS}
								onSelect={handleCommandSelect}
							/>
							<Text color="gray" dimColor>
								Press Escape to cancel, Ctrl+C to exit
							</Text>
						</Box>
					</Box>
				) : (
					<BottomBar
						status={status.text}
						statusColor={status.color}
						info={info}
						shortcuts={shortcuts}
						border={true}
					/>
				)
			}
		>
			<>
				{/* Error display */}
				{error && (
					<Box>
						<Text color="red">❌ Error: {error}</Text>
						<Newline />
					</Box>
				)}

				{/* Initializing state */}
				{!isInitialized && !error && (
					<Box>
						<Text color="yellow">🔄 Initializing LLM service...</Text>
						<Newline />
					</Box>
				)}

				{/* Welcome message */}
				{showWelcome && isInitialized && !error && (
					<Box flexDirection="column" marginBottom={1}>
						<Text color="green">
							💬 Start typing your message and press Enter to send.
						</Text>
						<Text color="gray">Type / to see available commands.</Text>
					</Box>
				)}

				{/* Chat history */}
				<StaticList items={messages}>
					{(message: ChatMessage) => <MessageBubble message={message} />}
				</StaticList>

				{/* Streaming response */}
				{isStreaming && currentResponse && (
					<MessageBubble
						message={{
							role: 'assistant',
							content: currentResponse + '▌',
						}}
					/>
				)}

				{/* Thinking indicator */}
				{isStreaming && !currentResponse && (
					<Text color="gray">🤔 Thinking...</Text>
				)}

				{/* Input prompt - always at bottom */}
				<TextInput value={currentInput} suffix="_" prefixColor="yellow" />
			</>
		</SplitLayout>
	);
};

export default LLMChatCommand;
