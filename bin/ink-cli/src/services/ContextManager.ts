/**
 * Context Management System
 *
 * Provides shared state and conversation context management across
 * interactive commands and potentially between commands.
 */

export interface ConversationMessage {
	id: string;
	role: 'user' | 'assistant' | 'system';
	content: string;
	timestamp: Date;
	metadata?: Record<string, any>;
}

export interface CommandContext {
	commandName: string;
	sessionId: string;
	startTime: Date;
	state: Record<string, any>;
}

export interface SharedContext {
	globalState: Record<string, any>;
	commandHistory: CommandContext[];
	activeSession: string | null;
}

/**
 * Manages conversation and shared context
 */
export class ContextManager {
	private conversations: Map<string, ConversationMessage[]> = new Map();
	private sharedContext: SharedContext = {
		globalState: {},
		commandHistory: [],
		activeSession: null,
	};

	/**
	 * Create a new conversation session
	 */
	createSession(sessionId: string): void {
		if (!this.conversations.has(sessionId)) {
			this.conversations.set(sessionId, []);
		}
		this.sharedContext.activeSession = sessionId;
	}

	/**
	 * Add a message to a conversation
	 */
	addMessage(
		sessionId: string,
		role: 'user' | 'assistant' | 'system',
		content: string,
		metadata?: Record<string, any>
	): string {
		const messageId = this.generateMessageId();
		const message: ConversationMessage = {
			id: messageId,
			role,
			content,
			timestamp: new Date(),
			metadata,
		};

		if (!this.conversations.has(sessionId)) {
			this.createSession(sessionId);
		}

		const conversation = this.conversations.get(sessionId)!;
		conversation.push(message);

		return messageId;
	}

	/**
	 * Get conversation history for a session
	 */
	getConversation(sessionId: string): ConversationMessage[] {
		return this.conversations.get(sessionId) || [];
	}

	/**
	 * Get last N messages from a conversation
	 */
	getLastMessages(sessionId: string, count: number): ConversationMessage[] {
		const conversation = this.getConversation(sessionId);
		return conversation.slice(-count);
	}

	/**
	 * Clear conversation for a session
	 */
	clearConversation(sessionId: string): void {
		this.conversations.set(sessionId, []);
	}

	/**
	 * Delete a session
	 */
	deleteSession(sessionId: string): void {
		this.conversations.delete(sessionId);
		if (this.sharedContext.activeSession === sessionId) {
			this.sharedContext.activeSession = null;
		}
	}

	/**
	 * Get all session IDs
	 */
	getSessionIds(): string[] {
		return Array.from(this.conversations.keys());
	}

	/**
	 * Set global state
	 */
	setGlobalState(key: string, value: any): void {
		this.sharedContext.globalState[key] = value;
	}

	/**
	 * Get global state
	 */
	getGlobalState(key: string): any {
		return this.sharedContext.globalState[key];
	}

	/**
	 * Get all global state
	 */
	getAllGlobalState(): Record<string, any> {
		return {...this.sharedContext.globalState};
	}

	/**
	 * Clear global state
	 */
	clearGlobalState(): void {
		this.sharedContext.globalState = {};
	}

	/**
	 * Start tracking a command context
	 */
	startCommandContext(commandName: string, sessionId: string): string {
		const contextId = this.generateContextId();
		const context: CommandContext = {
			commandName,
			sessionId,
			startTime: new Date(),
			state: {},
		};

		this.sharedContext.commandHistory.push(context);
		return contextId;
	}

	/**
	 * Update command state
	 */
	updateCommandState(contextId: string, state: Record<string, any>): void {
		// For now, we'll update the most recent context with matching command
		// In a more sophisticated implementation, we'd track contextId properly
		const recentContexts = this.sharedContext.commandHistory.slice(-5);
		const context = recentContexts.find(ctx =>
			ctx.commandName && Object.keys(state).length > 0
		);

		if (context) {
			context.state = {...context.state, ...state};
		}
	}

	/**
	 * Get command history
	 */
	getCommandHistory(): CommandContext[] {
		return [...this.sharedContext.commandHistory];
	}

	/**
	 * Get active session
	 */
	getActiveSession(): string | null {
		return this.sharedContext.activeSession;
	}

	/**
	 * Set active session
	 */
	setActiveSession(sessionId: string): void {
		if (this.conversations.has(sessionId)) {
			this.sharedContext.activeSession = sessionId;
		}
	}

	/**
	 * Export context for persistence
	 */
	exportContext(): any {
		return {
			conversations: Object.fromEntries(this.conversations),
			sharedContext: this.sharedContext,
		};
	}

	/**
	 * Import context from persistence
	 */
	importContext(data: any): void {
		if (data.conversations) {
			this.conversations = new Map(Object.entries(data.conversations));
		}
		if (data.sharedContext) {
			this.sharedContext = {...this.sharedContext, ...data.sharedContext};
		}
	}

	/**
	 * Clear all context
	 */
	clearAll(): void {
		this.conversations.clear();
		this.sharedContext = {
			globalState: {},
			commandHistory: [],
			activeSession: null,
		};
	}

	private generateMessageId(): string {
		return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
	}

	private generateContextId(): string {
		return `ctx_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
	}
}

// Global context manager instance
export const contextManager = new ContextManager();

/**
 * Convenience functions for global context access
 */
export function createSession(sessionId: string): void {
	contextManager.createSession(sessionId);
}

export function addMessage(
	sessionId: string,
	role: 'user' | 'assistant' | 'system',
	content: string,
	metadata?: Record<string, any>
): string {
	return contextManager.addMessage(sessionId, role, content, metadata);
}

export function getConversation(sessionId: string): ConversationMessage[] {
	return contextManager.getConversation(sessionId);
}

export function setGlobalState(key: string, value: any): void {
	contextManager.setGlobalState(key, value);
}

export function getGlobalState(key: string): any {
	return contextManager.getGlobalState(key);
}