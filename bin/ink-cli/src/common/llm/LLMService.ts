import {ChatMessage, ChatRole} from '../types/chat.js';

export interface LLMConfig {
	provider: string;
	name: string;
	baseURL: string;
	apiKey: string;
	model: string;
	maxTokens: number;
	temperature: number;
	systemPrompt: string;
}

export interface StreamChunk {
	content: string;
	isComplete: boolean;
	error?: string;
}

export interface LLMProvider {
	streamChat(
		messages: ChatMessage[],
		onChunk: (chunk: StreamChunk) => void,
		options?: Partial<LLMConfig>,
	): Promise<void>;

	sendMessage(
		message: string,
		onChunk: (chunk: StreamChunk) => void,
		options?: Partial<LLMConfig>,
	): Promise<void>;

	healthCheck(): Promise<boolean>;
}

export class LLMService implements LLMProvider {
	private config: LLMConfig;

	constructor(config: LLMConfig) {
		this.config = {
			...config,
		};
	}

	updateConfig(newConfig: Partial<LLMConfig>): void {
		this.config = {...this.config, ...newConfig};
	}

	getConfig(): LLMConfig {
		return {...this.config};
	}

	async streamChat(
		messages: ChatMessage[],
		onChunk: (chunk: StreamChunk) => void,
		options?: Partial<LLMConfig>,
	): Promise<void> {
		const finalConfig = {...this.config, ...options};

		try {
			const response = await fetch(
				`${finalConfig.baseURL}/v1/chat/completions`,
				{
					method: 'POST',
					headers: {
						'Content-Type': 'application/json',
						...(finalConfig.apiKey && {
							Authorization: `Bearer ${finalConfig.apiKey}`,
						}),
					},
					body: JSON.stringify({
						model: finalConfig.model,
						messages,
						max_tokens: finalConfig.maxTokens,
						temperature: finalConfig.temperature,
						stream: true,
					}),
				},
			);

			if (!response.ok) {
				throw new Error(`HTTP ${response.status}: ${response.statusText}`);
			}

			if (!response.body) {
				throw new Error('Response body is null');
			}

			const reader = response.body.getReader();
			const decoder = new TextDecoder();
			let buffer = '';

			try {
				while (true) {
					const {done, value} = await reader.read();
					if (done) break;

					const chunk = decoder.decode(value, {stream: true});
					buffer += chunk;
					const lines = buffer.split('\n');
					buffer = lines.pop() || '';

					for (const line of lines) {
						const trimmed = line.trim();
						if (trimmed.startsWith('data: ')) {
							const data = trimmed.slice(6);
							if (data === '[DONE]') {
								onChunk({content: '', isComplete: true});
								return;
							}

							try {
								const parsed = JSON.parse(data);
								const content = parsed.choices?.[0]?.delta?.content || '';
								if (content) {
									onChunk({content, isComplete: false});
								}
							} catch (parseError) {
								// Ignore malformed JSON chunks
							}
						}
					}
				}
				onChunk({content: '', isComplete: true});
			} finally {
				reader.releaseLock();
			}
		} catch (error) {
			onChunk({
				content: '',
				isComplete: false,
				error: error instanceof Error ? error.message : String(error),
			});
		}
	}

	async sendMessage(
		message: string,
		onChunk: (chunk: StreamChunk) => void,
		options?: Partial<LLMConfig>,
	): Promise<void> {
		const messages: ChatMessage[] = [];

		if (this.config.systemPrompt) {
			messages.push({role: 'system' as ChatRole, content: this.config.systemPrompt});
		}

		messages.push({role: 'user' as ChatRole, content: message});

		return this.streamChat(messages, onChunk, options);
	}

	async healthCheck(): Promise<boolean> {
		try {
			const response = await fetch(`${this.config.baseURL}/v1/models`, {
				method: 'GET',
				headers: {
					...(this.config.apiKey && {
						Authorization: `Bearer ${this.config.apiKey}`,
					}),
				},
			});
			return response.ok;
		} catch {
			return false;
		}
	}
}

export function createLLMService(config: LLMConfig): LLMService {
	return new LLMService(config);
}
