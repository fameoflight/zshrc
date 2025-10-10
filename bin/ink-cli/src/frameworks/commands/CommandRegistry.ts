import {GenericCommand, CommandContext, CommandRegistryOptions, CommandExecutionResult, CommandCategory} from './types.js';

/**
 * CommandRegistry - Centralized command management system
 *
 * Provides registration, execution, and discovery of commands.
 * Supports categorization, validation, and error handling.
 */
export class CommandRegistry<T = any> {
	private commands = new Map<string, GenericCommand<T>>();
	private categories = new Map<string, CommandCategory>();
	private executionHistory: CommandExecutionResult[] = [];
	private options: Required<CommandRegistryOptions>;

	constructor(options: CommandRegistryOptions = {}) {
		this.options = {
			caseSensitive: false,
			allowDuplicates: false,
			onCommandRegistered: () => {},
			onCommandExecuted: () => {},
			onCommandError: () => {},
			...options,
		};
	}

	/**
	 * Register a new command
	 */
	register(command: GenericCommand<T>): void {
		const commandId = this.options.caseSensitive ? command.id : command.id.toLowerCase();

		if (!this.options.allowDuplicates && this.commands.has(commandId)) {
			throw new Error(`Command with id '${command.id}' already exists`);
		}

		this.commands.set(commandId, command);

		// Add to category if specified
		if (command.category) {
			const categoryId = this.options.caseSensitive ? command.category : command.category.toLowerCase();
			if (!this.categories.has(categoryId)) {
				this.categories.set(categoryId, {
					id: command.category,
					label: command.category,
					commands: [],
				});
			}
			const category = this.categories.get(categoryId)!;
			category.commands.push(command);
		}

		this.options.onCommandRegistered(command);
	}

	/**
	 * Register multiple commands
	 */
	registerBatch(commands: GenericCommand<T>[]): void {
		commands.forEach(command => this.register(command));
	}

	/**
	 * Unregister a command
	 */
	unregister(commandId: string): boolean {
		const id = this.options.caseSensitive ? commandId : commandId.toLowerCase();
		const command = this.commands.get(id);

		if (!command) {
			return false;
		}

		// Remove from category
		if (command.category) {
			const categoryId = this.options.caseSensitive ? command.category : command.category.toLowerCase();
			const category = this.categories.get(categoryId);
			if (category) {
				category.commands = category.commands.filter(cmd => cmd.id !== command.id);
				if (category.commands.length === 0) {
					this.categories.delete(categoryId);
				}
			}
		}

		return this.commands.delete(id);
	}

	/**
	 * Execute a command by ID
	 */
	async execute(commandId: string, context: CommandContext<T> = {}): Promise<CommandExecutionResult> {
		const id = this.options.caseSensitive ? commandId : commandId.toLowerCase();
		const command = this.commands.get(id);

		if (!command) {
			throw new Error(`Command '${commandId}' not found`);
		}

		if (command.disabled) {
			throw new Error(`Command '${commandId}' is disabled`);
		}

		const startTime = Date.now();
		let success = false;
		let error: Error | undefined;

		try {
			// Validate command if validation function provided
			if (command.validate && !command.validate(context)) {
				throw new Error(`Command '${commandId}' validation failed`);
			}

			// Execute command
			await command.execute(context);
			success = true;

			// Call success callback if provided
			if (command.onSuccess) {
				command.onSuccess(context);
			}

		} catch (err) {
			error = err instanceof Error ? err : new Error(String(err));
			success = false;

			// Call error callback if provided
			if (command.onError) {
				command.onError(error, context);
			}

			// Call global error handler
			this.options.onCommandError(command, error, context);

			// Re-throw error for caller to handle
			throw error;
		} finally {
			const duration = Date.now() - startTime;
			const result: CommandExecutionResult = {
				command,
				success,
				error,
				duration,
			};

			this.executionHistory.push(result);
			this.options.onCommandExecuted(command, context);
		}

		return {
			command,
			success,
			error,
			duration: Date.now() - startTime,
		};
	}

	/**
	 * Get a command by ID
	 */
	get(commandId: string): GenericCommand<T> | undefined {
		const id = this.options.caseSensitive ? commandId : commandId.toLowerCase();
		return this.commands.get(id);
	}

	/**
	 * Check if a command exists
	 */
	has(commandId: string): boolean {
		const id = this.options.caseSensitive ? commandId : commandId.toLowerCase();
		return this.commands.has(id);
	}

	/**
	 * Get all commands
	 */
	getAll(): GenericCommand<T>[] {
		return Array.from(this.commands.values());
	}

	/**
	 * Get all visible commands (not hidden)
	 */
	getVisible(): GenericCommand<T>[] {
		return this.getAll().filter(cmd => !cmd.hidden);
	}

	/**
	 * Get commands by category
	 */
	getByCategory(categoryId: string): GenericCommand<T>[] {
		const id = this.options.caseSensitive ? categoryId : categoryId.toLowerCase();
		const category = this.categories.get(id);
		return category ? category.commands : [];
	}

	/**
	 * Get all categories
	 */
	getCategories(): CommandCategory[] {
		return Array.from(this.categories.values());
	}

	/**
	 * Search commands by label, description, or ID
	 */
	search(query: string): GenericCommand<T>[] {
		const searchQuery = this.options.caseSensitive ? query : query.toLowerCase();
		return this.getAll().filter(command => {
			const id = this.options.caseSensitive ? command.id : command.id.toLowerCase();
			const label = this.options.caseSensitive ? command.label : command.label.toLowerCase();
			const description = this.options.caseSensitive ? command.description : command.description.toLowerCase();

			return id.includes(searchQuery) ||
				label.includes(searchQuery) ||
				description.includes(searchQuery);
		});
	}

	/**
	 * Get command by keybinding
	 */
	getByKeyBinding(keybinding: string): GenericCommand<T> | undefined {
		return this.getAll().find(command => command.keybinding === keybinding);
	}

	/**
	 * Get execution history
	 */
	getExecutionHistory(): CommandExecutionResult[] {
		return [...this.executionHistory];
	}

	/**
	 * Clear execution history
	 */
	clearExecutionHistory(): void {
		this.executionHistory = [];
	}

	/**
	 * Get statistics about command usage
	 */
	getStatistics() {
		const stats = {
			totalCommands: this.commands.size,
			hiddenCommands: this.getAll().filter(cmd => cmd.hidden).length,
			disabledCommands: this.getAll().filter(cmd => cmd.disabled).length,
			categories: this.categories.size,
			totalExecutions: this.executionHistory.length,
			successfulExecutions: this.executionHistory.filter(r => r.success).length,
			failedExecutions: this.executionHistory.filter(r => !r.success).length,
			averageExecutionTime: 0,
		};

		if (stats.totalExecutions > 0) {
			const totalTime = this.executionHistory.reduce((sum, result) => sum + result.duration, 0);
			stats.averageExecutionTime = totalTime / stats.totalExecutions;
		}

		return stats;
	}
}