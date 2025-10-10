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
import {useConfig} from '../common/hooks/useConfig.js';
import {createConfigCommands, ConfigCommandContext} from '../common/configCommands.js';
import {CHAT_COMMANDS} from '../common/chatCommands.js';
import {ChatMessage, ChatRole} from '../common/types/chat.js';
import {createCommandLogger} from '../common/logger.js';
import {AppProvider, useAppContext} from '../common/context/AppContext.js';
import SelectInput from 'ink-select-input';
import {
	computeChatStatus,
	computeInfoText,
	getShortcuts,
} from '../common/utils/chatStatus.js';

import StaticList from '../components/StaticList.js';

import StreamingMessage from '../components/StreamingMessage.js';

// LLM Chat specific configuration interface
interface LLMChatConfig {
	temperature: number; // 0.0-2.0, controls randomness in responses
	maxTokens?: number; // Optional: maximum tokens in response
	systemPrompt?: string; // Optional: custom system prompt
	model?: string; // Optional: model name override
}

// Temperature validation function
const validateTemperature = (value: number) => {
	if (typeof value !== 'number' || isNaN(value)) {
		return 'Temperature must be a number';
	}
	if (value < 0 || value > 2) {
		return 'Temperature must be between 0.0 and 2.0';
	}
	return true;
};

// Default configuration schema
const DEFAULT_LLM_CHAT_CONFIG = {
	defaults: {
		temperature: 0.7,
	},
	validation: {
		temperature: validateTemperature,
	},
};

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
				'Use Escape to cancel streaming responses',
				'Use Ctrl+C to exit the chat',
				'Provider presets: lmstudio, openai, ollama',
			],
		};
	}

	execute(flags: LLMChatFlags): React.ReactElement {
		const logger = createCommandLogger('llm-chat');
		return (
			<AppProvider logger={logger} commandName="llm-chat">
				<LLMChatComponent flags={flags} />
			</AppProvider>
		);
	}
}

const LLMChatComponent: React.FC<{flags: LLMChatFlags}> = ({flags}) => {
	const {exit} = useApp();
	const { logger } = useAppContext();
	logger.debug('[LLMChatComponent] Component rendering started');

	// Use config schema directly - useConfig hook handles stability
	const configSchema = DEFAULT_LLM_CHAT_CONFIG;

	// Initialize config management
	const {config, updateConfig, resetConfig, isLoading: configLoading, error: configError} =
		useConfig<LLMChatConfig>('llm-chat', configSchema);

	logger.debug('[LLMChatComponent] Component rendering', { config, isLoading: configLoading, error: configError });

	// State
	const [showWelcome, setShowWelcome] = useState(true);
	const [isInterrupting, setIsInterrupting] = useState(false);
	const [showCommandSelector, setShowCommandSelector] = useState(false);
	const [abortController, setAbortController] =
		useState<AbortController | null>(null);

	// Merge flags with config (flags take precedence) - useMemo to prevent infinite re-renders
	const mergedConfig = useMemo(() => ({
		...config,
		...flags, // CLI flags override config
	}), [config, flags]);

	// Initialize LLM service with merged config
	const {llmService, isInitialized, error, resolvedProvider, setError} =
		useLLMService({
			flags: mergedConfig,
			defaultConfig: DEFAULT_LLM_CONFIG,
			loggerName: 'llm-chat',
		});

	// Manage chat messages
	const {messages, messageCount, addMessage, clearMessages} = useChatMessages({
		systemPrompt: config.systemPrompt || llmService?.getConfig()?.systemPrompt,
	});

	// Handle streaming responses
	const {
		currentResponse,
		isStreaming,
		handleChunk,
		resetBuffer,
		setIsStreaming,
	} = useStreamBuffer({
		batchInterval: 2,
		onComplete: content => {
			addMessage('assistant', content);
		},
		onError: err => setError(err),
	});

// Create available commands for autocomplete
	const availableCommands = useMemo(() => {
		const configCommands = createConfigCommands(
			config,
			updateConfig,
			resetConfig,
			'llm-chat'
		);
		return [...configCommands, ...CHAT_COMMANDS];
	}, [config, updateConfig, resetConfig]);

	// Handle text input with autocomplete
	const {value: currentInput, suggestions, showSuggestions} = useTextInput({
		onSubmit: sendMessage,
		onCommandSelect: (commandValue) => {
			executeCommand(commandValue);
		},
		availableCommands,
		shortcuts: {
			c: () => exit(),
			l: () => {
				clearMessages();
				setShowWelcome(true);
			},
		},
		disabled: isStreaming || !llmService || showCommandSelector || configLoading,
	});

	// Send message to LLM
	async function sendMessage(userMessage: string) {
		if (!llmService || isStreaming) return;

		// Check if this is a command (starts with /)
		if (userMessage.startsWith('/')) {
			// Handle config commands
			if (userMessage.startsWith('/config')) {
				const parts = userMessage.split(' ');
				if (parts.length >= 2 && parts[1]) {
					const subcommand = parts[1].toLowerCase();

					if (subcommand === 'set' && parts.length >= 4) {
						// Directly handle /config set key value
						const key = parts[2];
						const rawValue = parts.slice(3).join(' ');

						// Convert value to appropriate type
						let convertedValue: any = rawValue;
						if (!isNaN(Number(rawValue)) && rawValue.trim() !== '') {
							convertedValue = Number(rawValue);
						}

						try {
							await updateConfig({temperature: convertedValue} as any);
							addMessage('system', `✅ ${key} updated to "${convertedValue}"`);
							return;
						} catch (error) {
							addMessage('system', `❌ Failed to update config: ${error}`);
							return;
						}
					} else if (subcommand === 'list') {
						// Directly handle /config list
						const configEntries = Object.entries(config)
							.map(([key, value]) => `• ${key}: ${value || 'not set'}`)
							.join('\n');
						addMessage('system', `⚙️ Current Configuration:\n\n${configEntries}`);
						return;
					} else if (subcommand === 'reset') {
						// Directly handle /config reset
						try {
							await resetConfig();
							addMessage('system', '✅ Configuration reset to defaults');
							return;
						} catch (error) {
							addMessage('system', `❌ Failed to reset config: ${error}`);
							return;
						}
					}
				}
			}

			// Handle other commands
			const commandValue = userMessage.substring(1).toLowerCase(); // Remove '/' and convert to lowercase
			if (commandValue === 'clear') {
				clearMessages();
				setShowWelcome(true);
				return;
			} else if (commandValue === 'tokens') {
				// Calculate token usage
				const userChars = messages
					.filter(msg => msg.role === 'user')
					.reduce((sum, msg) => sum + msg.content.length, 0);
				const assistantChars = messages
					.filter(msg => msg.role === 'assistant')
					.reduce((sum, msg) => sum + msg.content.length, 0);
				const totalChars = userChars + assistantChars;
				const totalTokens = Math.ceil(totalChars / 4);

				addMessage('system', `📊 Token Usage:\n• Total Characters: ${totalChars}\n• Estimated Total Tokens: ${totalTokens}\n\nNote: This is a rough approximation (~4 chars/token).`);
				return;
			}
		}

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
						currentResponse + '\n\n*(Response cancelled)*',
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

	// Execute command (used only for menu selections)
	async function executeCommand(commandValue: string) {
		// Include config commands dynamically
		const configCommands = createConfigCommands(
			config,
			updateConfig,
			resetConfig,
			'llm-chat'
		);

		const allCommands = [...configCommands, ...CHAT_COMMANDS];
		const command = allCommands.find(cmd => cmd.value === commandValue);
		if (!command) return;

		const chatContext: ConfigCommandContext<LLMChatConfig> = {
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
			config,
			updateConfig,
			resetConfig,
			logger,
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
	useInput(
		(_, key) => {
			if (isStreaming && key.escape && abortController) {
				setIsInterrupting(true);
				abortController.abort();
			}
		},
		{isActive: isStreaming && !showCommandSelector},
	);

	// Compute status and info for bottom bar
	const chatState = useMemo(
		() => ({
			isStreaming,
			isInterrupting,
			isInitialized,
			error: error || configError || null,
			currentInput,
			messageCount,
		}),
		[
			isStreaming,
			isInterrupting,
			isInitialized,
			error,
			configError,
			currentInput,
			messageCount,
		],
	);

	const status = computeChatStatus(chatState);
	const info = computeInfoText(messageCount, resolvedProvider);
	const shortcuts = getShortcuts(isStreaming, !!error || !!configError);

	// Header info items - memoized to update when config changes
	const headerInfo = useMemo(() => {
		const items: InfoItem[] = [
			{
				label: 'Base URL',
				value: flags.baseurl || llmService?.getConfig()?.baseURL || 'Unknown',
				valueColor: 'gray',
			},
			{
				label: 'Temperature',
				value: config.temperature.toFixed(1),
				valueColor: 'cyan',
				icon: '🌡️',
			},
		];

		if (configError) {
			items.push({
				label: 'Config Error',
				value: configError,
				valueColor: 'red',
				icon: '⚠️',
			});
		}

		if (llmService?.getConfig()?.systemPrompt) {
			items.push({
				label: 'System Prompt',
				value: llmService.getConfig().systemPrompt!,
				valueColor: 'gray',
				icon: '📋',
			});
		}

		return items;
	}, [config.temperature, configError, flags.baseurl, llmService]);

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
								items={(() => {
									const configCommands = createConfigCommands(
										config,
										updateConfig,
										resetConfig,
										'llm-chat'
									);
									return [...configCommands, ...CHAT_COMMANDS];
								})()}
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
				{/* Config error display */}
				{configError && (
					<Box>
						<Text color="red">⚙️ Config Error: {configError}</Text>
						<Newline />
					</Box>
				)}

				{/* Config loading state */}
				{configLoading && (
					<Box>
						<Text color="blue">⚙️ Loading configuration...</Text>
						<Newline />
					</Box>
				)}

				{/* Error display */}
				{error && (
					<Box>
						<Text color="red">❌ Error: {error}</Text>
						<Newline />
					</Box>
				)}

				{/* Initializing state */}
				{!isInitialized && !error && !configLoading && (
					<Box>
						<Text color="yellow">🔄 Initializing LLM service...</Text>
						<Newline />
					</Box>
				)}

				{/* Welcome message */}
				{showWelcome && isInitialized && !error && !configError && (
					<Box flexDirection="column" marginBottom={1}>
						<Text color="green">
							💬 Start typing your message and press Enter to send.
						</Text>
						<Text color="gray">Type / to see available commands.</Text>
						<Text color="cyan">🌡️ Current temperature: {config.temperature.toFixed(1)} (use /config to change)</Text>
					</Box>
				)}

				{/* Chat history */}
				<StaticList items={messages}>
					{(message: ChatMessage) => <MessageBubble message={message} />}
				</StaticList>

				{/* Streaming response */}
				{isStreaming && currentResponse && (
					<StreamingMessage content={currentResponse} />
				)}

				{/* Thinking indicator */}
				{isStreaming && !currentResponse && (
					<Text color="gray">🤔 Thinking...</Text>
				)}

	{/* Autocomplete suggestions */}
				{showSuggestions && (
					<Box flexDirection="column" marginBottom={1}>
						{suggestions.map((suggestion, index) => (
							<Box key={suggestion.value}>
								<Text color="gray">
									{index === 0 ? '→' : ' '} {suggestion.label}
								</Text>
								{suggestion.description && (
									<Text color="dimColor"> - {suggestion.description}</Text>
								)}
							</Box>
						))}
						<Text color="dimColor">Press Tab to autocomplete, or continue typing</Text>
					</Box>
				)}

				{/* Input prompt - always at bottom */}
				<TextInput value={currentInput} suffix="_" prefixColor="yellow" />
			</>
		</SplitLayout>
	);
};

export default LLMChatCommand;
