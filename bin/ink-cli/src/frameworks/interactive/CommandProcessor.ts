/**
 * Unified Command Processing Pipeline
 *
 * Provides a standardized way to process commands and messages
 * across all interactive commands with support for middleware.
 */

export interface ProcessingContext {
	command: string;
	input: string;
	state: any;
	sessionId: string;
	handled: boolean;
	result?: any;
	error?: string;
}

export interface CommandMiddleware {
	name: string;
	priority: number;
	execute(context: ProcessingContext): Promise<ProcessingContext>;
	canHandle?(context: ProcessingContext): boolean;
}

export interface CommandHandler {
	command: string | RegExp;
	description: string;
	execute(context: ProcessingContext): Promise<ProcessingContext>;
}

/**
 * Processes commands through a pipeline of middleware and handlers
 */
export class CommandProcessor {
	private middleware: CommandMiddleware[] = [];
	private handlers: CommandHandler[] = [];

	/**
	 * Add middleware to the processing pipeline
	 */
	addMiddleware(middleware: CommandMiddleware): void {
		this.middleware.push(middleware);
		// Sort by priority (higher priority first)
		this.middleware.sort((a, b) => b.priority - a.priority);
	}

	/**
	 * Remove middleware from the pipeline
	 */
	removeMiddleware(name: string): void {
		this.middleware = this.middleware.filter(m => m.name !== name);
	}

	/**
	 * Register a command handler
	 */
	registerHandler(handler: CommandHandler): void {
		this.handlers.push(handler);
	}

	/**
	 * Unregister a command handler
	 */
	unregisterHandler(command: string | RegExp): void {
		this.handlers = this.handlers.filter(h => h.command !== command);
	}

	/**
	 * Process input through the middleware pipeline and handlers
	 */
	async process(input: string, state: any, sessionId: string): Promise<ProcessingContext> {
		const context: ProcessingContext = {
			command: '',
			input: input.trim(),
			state,
			sessionId,
			handled: false,
		};

		// Extract command if it's a command
		if (context.input.startsWith('/')) {
			context.command = context.input.substring(1).toLowerCase();
		}

		try {
			// Process through middleware pipeline
			for (const middleware of this.middleware) {
				// Check if middleware can handle this context
				if (middleware.canHandle && !middleware.canHandle(context)) {
					continue;
				}

				context.result = await middleware.execute(context);
				if (context.handled) {
					break;
				}
			}

			// If not handled by middleware, try command handlers
			if (!context.handled && context.command) {
				for (const handler of this.handlers) {
					if (this.matchesCommand(context.command, handler.command)) {
						context.result = await handler.execute(context);
						context.handled = true;
						break;
					}
				}
			}

			return context;
		} catch (error) {
			context.error = String(error);
			return context;
		}
	}

	/**
	 * Check if a command string matches a handler pattern
	 */
	private matchesCommand(command: string, pattern: string | RegExp): boolean {
		if (typeof pattern === 'string') {
			return command === pattern || command.startsWith(pattern + ' ');
		} else {
			return pattern.test(command);
		}
	}

	/**
	 * Get all registered middleware
	 */
	getMiddleware(): CommandMiddleware[] {
		return [...this.middleware];
	}

	/**
	 * Get all registered handlers
	 */
	getHandlers(): CommandHandler[] {
		return [...this.handlers];
	}

	/**
	 * Get available commands for help/autocomplete
	 */
	getAvailableCommands(): Array<{command: string; description: string}> {
		return this.handlers.map(h => ({
			command: typeof h.command === 'string' ? h.command : h.command.source,
			description: h.description,
		}));
	}
}

// Common middleware implementations

export const LoggingMiddleware: CommandMiddleware = {
	name: 'logging',
	priority: 100,
	async execute(context: ProcessingContext): Promise<ProcessingContext> {
		console.log(`[CommandProcessor] Processing: ${context.input}`);
		return context;
	},
};

export const ValidationMiddleware: CommandMiddleware = {
	name: 'validation',
	priority: 90,
	async execute(context: ProcessingContext): Promise<ProcessingContext> {
		if (!context.input || context.input.trim() === '') {
			context.handled = true;
			context.result = 'Empty input ignored';
		}
		return context;
	},
};

export const HelpMiddleware: CommandMiddleware = {
	name: 'help',
	priority: 80,
	canHandle(context: ProcessingContext): boolean {
		return context.command === 'help' || context.command === '';
	},
	async execute(context: ProcessingContext): Promise<ProcessingContext> {
		if (context.command === 'help') {
			context.handled = true;
			context.result = {
				type: 'help',
				content: 'Type /help to see available commands, or /exit to quit.',
			};
		}
		return context;
	},
};

// Common command handlers

export const ExitHandler: CommandHandler = {
	command: 'exit',
	description: 'Exit the current command',
	async execute(context: ProcessingContext): Promise<ProcessingContext> {
		context.handled = true;
		context.result = {
			type: 'exit',
			content: 'Exiting...',
		};
		return context;
	},
};

export const ClearHandler: CommandHandler = {
	command: 'clear',
	description: 'Clear the conversation history',
	async execute(context: ProcessingContext): Promise<ProcessingContext> {
		context.handled = true;
		context.result = {
			type: 'clear',
			content: 'Conversation cleared.',
		};
		return context;
	},
};

export const QuitHandler: CommandHandler = {
	command: 'quit',
	description: 'Quit the current command',
	async execute(context: ProcessingContext): Promise<ProcessingContext> {
		context.handled = true;
		context.result = {
			type: 'exit',
			content: 'Quitting...',
		};
		return context;
	},
};

/**
 * Factory function to create a configured command processor
 */
export function createCommandProcessor(): CommandProcessor {
	const processor = new CommandProcessor();

	// Add common middleware
	processor.addMiddleware(LoggingMiddleware);
	processor.addMiddleware(ValidationMiddleware);
	processor.addMiddleware(HelpMiddleware);

	// Add common handlers
	processor.registerHandler(ExitHandler);
	processor.registerHandler(ClearHandler);
	processor.registerHandler(QuitHandler);

	return processor;
}