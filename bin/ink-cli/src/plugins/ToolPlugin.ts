import React, {ReactElement} from 'react';
import {BaseInteractiveCommand, Plugin, BaseInteractiveState} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {ToolRegistry, ToolDefinition} from '../services/ToolRegistry.js';
import {ToolResultDisplay, ToolExecutionList, ToolStatus} from '../components/interactive/ToolResultDisplay.js';
import {toolRegistry} from '../services/ToolRegistry.js';

export interface ToolPluginOptions {
	/** Custom tool registry (overrides global) */
	toolRegistry?: ToolRegistry;
	/** Enable auto-tool registration */
	autoRegister?: boolean;
	/** Tools to register on initialization */
	tools?: ToolDefinition[];
}

/**
 * Tool Plugin - Provides tool execution capabilities for interactive commands
 *
 * This plugin enables commands to register and execute tools, handle tool results,
 * and provide a consistent interface for tool-based operations.
 */
export class ToolPlugin implements Plugin {
	name = 'tool';

	private command?: BaseInteractiveCommand<any>;
	private toolRegistry: ToolRegistry;
	private options: ToolPluginOptions;
	private executionQueue: Array<{toolName: string; parameters: any}> = [];
	private isExecuting = false;
	private executionResults: any[] = [];

	constructor(options: ToolPluginOptions = {}) {
		this.options = options;
		this.toolRegistry = options.toolRegistry || toolRegistry;
	}

	async initialize(command: BaseInteractiveCommand<any>): Promise<void> {
		this.command = command;

		// Register tools if provided
		if (this.options.tools && this.options.autoRegister !== false) {
			this.toolRegistry.registerTools(this.options.tools);
		}
	}

	async cleanup(): Promise<void> {
		// Clear execution queue and results
		this.executionQueue = [];
		this.executionResults = [];
		this.isExecuting = false;
	}

	async onMessage(message: string): Promise<boolean> {
		if (!this.command) return false;

		// Handle tool-related commands
		if (message.startsWith('/')) {
			const commandName = message.substring(1).toLowerCase();

			switch (commandName) {
				case 'tools':
				case 'tool-list':
					await this.listTools();
					return true;

				case 'tool-execute':
					return await this.handleToolExecute(message);

				case 'tool-results':
					await this.showResults();
					return true;

				case 'tool-clear':
					await this.clearResults();
					return true;

				case 'tool-status':
					await this.showToolStatus();
					return true;

				default:
					// Check for direct tool execution: /<tool-name> [args]
					return await this.tryDirectToolExecution(commandName, message);
			}
		}

		return false;
	}

	onStateChange(state: BaseInteractiveState): void {
		// React to state changes if needed
	}

	renderComponents(): ReactElement[] {
		if (!this.command) return [];

		const state = this.command.getState();

		const components: ReactElement[] = [];

		// Show tool status if executing
		if (this.isExecuting && this.executionQueue.length > 0) {
			components.push(
				React.createElement(ToolStatus, {
					currentTool: this.executionQueue[0]?.toolName,
					isRunning: this.isExecuting,
					queue: this.executionQueue.slice(1).map(t => t.toolName),
					showProgress: true,
				})
			);
		}

		// Show recent tool results
		if (this.executionResults.length > 0) {
			components.push(
				React.createElement(ToolExecutionList, {
					results: this.executionResults.slice(-3), // Show last 3 results
					maxResults: 3,
					showSummary: false,
					compact: true,
				})
			);
		}

		return components;
	}

	/**
	 * List available tools
	 */
	private async listTools(): Promise<void> {
		if (!this.command) return;

		const tools = this.toolRegistry.getAllTools();
		const categories = this.toolRegistry.getAllCategories();

		if (tools.length === 0) {
			await this.command.addMessage('system', '🔧 No tools are registered.');
			return;
		}

		let toolListText = `🔧 Available Tools (${tools.length} total):\n\n`;

		// Show tools by category if categories exist
		if (categories.length > 0) {
			for (const category of categories) {
				toolListText += `📁 ${category.name}:\n`;
				toolListText += `${category.description}\n`;
				for (const tool of category.tools) {
					toolListText += `  • ${tool.name}: ${tool.description}\n`;
				}
				toolListText += '\n';
			}
		} else {
			// Show all tools in a flat list
			for (const tool of tools) {
				toolListText += `• ${tool.name}: ${tool.description}\n`;
			}
		}

		toolListText += `\n💡 Use /tool-execute <tool-name> <json-args> to execute a tool`;
		toolListText += `\nOr use /<tool-name> <args> for direct execution`;

		await this.command.addMessage('system', toolListText);
	}

	/**
	 * Handle tool execution command
	 */
	private async handleToolExecute(message: string): Promise<boolean> {
		if (!this.command) return false;

		const parts = message.trim().split(' ');
		if (parts.length < 2) {
			await this.command.addMessage('system', '❌ Usage: /tool-execute <tool-name> <json-args>');
			return true;
		}

		const toolName = parts[1];
		const argsString = parts.slice(2).join(' ');

		let parameters = {};
		if (argsString) {
			try {
				parameters = JSON.parse(argsString);
			} catch {
				await this.command.addMessage('system', '❌ Invalid JSON arguments');
				return true;
			}
		}

		if (toolName) {
			await this.executeTool(toolName, parameters);
		}
		return true;
	}

	/**
	 * Try direct tool execution (e.g., /search "query")
	 */
	private async tryDirectToolExecution(commandName: string, fullMessage: string): Promise<boolean> {
		if (!this.command) return false;

		const tool = this.toolRegistry.getTool(commandName);
		if (!tool) return false;

		// Parse arguments for direct execution
		const parts = fullMessage.trim().split(' ');
		const argsString = parts.slice(1).join(' ');

		let parameters = {};
		if (argsString) {
			// Try to parse as JSON first, then as simple string
			try {
				parameters = JSON.parse(argsString);
			} catch {
				// Use as simple query parameter
				parameters = {query: argsString};
			}
		}

		await this.executeTool(commandName, parameters);
		return true;
	}

	/**
	 * Execute a tool
	 */
	private async executeTool(toolName: string, parameters: any): Promise<void> {
		if (!this.command) return;

		try {
			this.command.addMessage('system', `🔧 Executing tool: ${toolName}`);

			const startTime = Date.now();
			const result = await this.toolRegistry.executeTool(toolName, parameters);
			const executionTime = Date.now() - startTime;

			// Add to results
			const toolResult = {
				toolName,
				result,
				executionTime,
				timestamp: new Date(),
			};
			this.executionResults.push(toolResult);

			// Limit results history
			if (this.executionResults.length > 20) {
				this.executionResults = this.executionResults.slice(-20);
			}

			// Show result
			await this.command.addMessage('tool', JSON.stringify({
				tool: toolName,
				result,
				executionTime: `${executionTime}ms`,
			}, null, 2));

		} catch (error) {
			const errorMessage = error instanceof Error ? error.message : String(error);
			await this.command.addMessage('system', `❌ Tool execution failed: ${errorMessage}`);

			// Add error result
			this.executionResults.push({
				toolName,
				result: null,
				error: errorMessage,
				timestamp: new Date(),
			});
		}
	}

	/**
	 * Show tool execution results
	 */
	private async showResults(): Promise<void> {
		if (!this.command) return;

		if (this.executionResults.length === 0) {
			await this.command.addMessage('system', '📊 No tool execution results yet.');
			return;
		}

		const recentResults = this.executionResults.slice(-10);
		const successfulCount = recentResults.filter(r => !r.error).length;
		const failedCount = recentResults.filter(r => r.error).length;

		let resultsText = `📊 Recent Tool Results (${recentResults.length} shown):\n\n`;
		resultsText += `✅ Successful: ${successfulCount}\n`;
		resultsText += `❌ Failed: ${failedCount}\n\n`;

		for (const result of recentResults) {
			const status = result.error ? '❌' : '✅';
			const executionTime = result.executionTime ? ` (${result.executionTime}ms)` : '';
			resultsText += `${status} ${result.toolName}${executionTime}\n`;
			if (result.error) {
				resultsText += `   Error: ${result.error}\n`;
			} else {
				const preview = JSON.stringify(result.result).substring(0, 100);
				resultsText += `   Result: ${preview}${JSON.stringify(result.result).length > 100 ? '...' : ''}\n`;
			}
		}

		await this.command.addMessage('system', resultsText);
	}

	/**
	 * Clear tool execution results
	 */
	private async clearResults(): Promise<void> {
		if (!this.command) return;

		this.executionResults = [];
		await this.command.addMessage('system', '🗑️ Tool execution results cleared.');
	}

	/**
	 * Show tool execution status
	 */
	private async showToolStatus(): Promise<void> {
		if (!this.command) return;

		const tools = this.toolRegistry.getAllTools();
		const categories = this.toolRegistry.getAllCategories();

		let statusText = '🔧 Tool System Status:\n\n';
		statusText += `📊 Registered Tools: ${tools.length}\n`;
		statusText += `📁 Categories: ${categories.length}\n`;
		statusText += `📈 Execution Queue: ${this.executionQueue.length}\n`;
		statusText += `📋 Recent Results: ${this.executionResults.length}\n`;
		statusText += `🔄 Currently Executing: ${this.isExecuting ? 'Yes' : 'No'}\n`;

		if (this.executionQueue.length > 0) {
			statusText += `\n📝 Execution Queue:\n`;
			for (let i = 0; i < Math.min(5, this.executionQueue.length); i++) {
				const item = this.executionQueue[i];
				if (item) {
					statusText += `  ${i + 1}. ${item.toolName}\n`;
				}
			}
			if (this.executionQueue.length > 5) {
				statusText += `  ... and ${this.executionQueue.length - 5} more\n`;
			}
		}

		await this.command.addMessage('system', statusText);
	}

	/**
	 * Get the tool registry
	 */
	getToolRegistry(): ToolRegistry {
		return this.toolRegistry;
	}

	/**
	 * Get execution results
	 */
	getExecutionResults(): any[] {
		return [...this.executionResults];
	}

	/**
	 * Clear execution results
	 */
	clearExecutionResults(): void {
		this.executionResults = [];
	}
}

/**
 * Factory function to create a tool plugin
 */
export function createToolPlugin(options?: ToolPluginOptions): ToolPlugin {
	return new ToolPlugin(options);
}