import React, {ReactElement} from 'react';
import {BaseInteractiveCommand, Plugin, BaseInteractiveState} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {LLMProvider, ToolDefinition as LLMToolDefinition} from '../services/LLMProvider.js';
import {toolRegistry, ToolDefinition as RegistryToolDefinition} from '../services/ToolRegistry.js';
import {serviceContainer} from '../services/ServiceProvider.js';

export interface ToolCallingPluginOptions {
	/** Enable automatic tool calling */
	enableAutoCalling?: boolean;
	/** Tools to register for LLM */
	tools?: RegistryToolDefinition[];
	/** Require confirmation before tool execution */
	requireConfirmation?: boolean;
}

/**
 * Tool Calling Plugin - Enables LLMs to call tools directly
 *
 * This plugin prepares the system for when LLMs can call tools directly,
 * providing tool registration, execution, and result handling.
 */
export class ToolCallingPlugin implements Plugin {
	name = 'tool-calling';

	private command?: BaseInteractiveCommand<any>;
	private options: ToolCallingPluginOptions;
	private llmProvider?: LLMProvider;
	private _isToolCallingEnabled = false;

	constructor(options: ToolCallingPluginOptions = {}) {
		this.options = {
			requireConfirmation: true,
			enableAutoCalling: false,
			...options,
		};
	}

	async initialize(command: BaseInteractiveCommand<any>): Promise<void> {
		this.command = command;
		this.llmProvider = serviceContainer.resolve<LLMProvider>('llm-provider');

		// Register tools with LLM provider if supported
		if (this.options.tools && this.llmProvider && this.llmProvider.registerTools) {
			this.llmProvider.registerTools(this.options.tools);
			this._isToolCallingEnabled = true;
		}

		// Register tools with global registry
		if (this.options.tools) {
			toolRegistry.registerTools(this.options.tools);
		}
	}

	async cleanup(): Promise<void> {
		// Cleanup tool calling resources
	}

	async onMessage(message: string): Promise<boolean> {
		if (!this.command) return false;

		// Handle tool calling commands
		if (message.startsWith('/')) {
			const commandName = message.substring(1).toLowerCase();

			switch (commandName) {
				case 'tools-enable':
					await this.enableToolCalling();
					return true;

				case 'tools-disable':
					await this.disableToolCalling();
					return true;

				case 'tools-status':
					await this.showToolCallingStatus();
					return true;

				case 'tools-register':
					return await this.handleRegisterTools(message);

				case 'tools-call':
					return await this.handleManualToolCall(message);

				default:
					return false;
			}
		}

		return false;
	}

	onStateChange(state: BaseInteractiveState): void {
		// React to state changes if needed
	}

	renderComponents(): ReactElement[] {
		// Tool calling plugin doesn't render UI components by default
		// It provides backend functionality for tool calling
		return [];
	}

	/**
	 * Enable tool calling
	 */
	private async enableToolCalling(): Promise<void> {
		if (!this.command) return;

		if (!this.llmProvider) {
			await this.command.addMessage('system', '❌ No LLM provider available for tool calling');
			return;
		}

		if (!this.llmProvider.registerTools) {
			await this.command.addMessage('system', '❌ LLM provider does not support tool calling');
			return;
		}

		try {
			// Get all available tools
			const availableTools = toolRegistry.getAllTools();

			if (availableTools.length === 0) {
				await this.command.addMessage('system', 'ℹ️ No tools available for calling');
				return;
			}

			// Register tools with LLM provider
			this.llmProvider.registerTools(availableTools);
			this._isToolCallingEnabled = true;

			await this.command.addMessage(
				'system',
				`✅ Tool calling enabled with ${availableTools.length} tools available`
			);

		} catch (error) {
			await this.command.addMessage(
				'system',
				`❌ Failed to enable tool calling: ${error}`
			);
		}
	}

	/**
	 * Disable tool calling
	 */
	private async disableToolCalling(): Promise<void> {
		if (!this.command) return;

		try {
			if (this.llmProvider && this.llmProvider.registerTools) {
				// Register empty tools array to disable
				this.llmProvider.registerTools([]);
			}

			this._isToolCallingEnabled = false;

			await this.command.addMessage('system', '🛑 Tool calling disabled');

		} catch (error) {
			await this.command.addMessage(
				'system',
				`❌ Failed to disable tool calling: ${error}`
			);
		}
	}

	/**
	 * Show tool calling status
	 */
	private async showToolCallingStatus(): Promise<void> {
		if (!this.command) return;

		const availableTools = toolRegistry.getAllTools();
		const isLLMReady = this.llmProvider?.isReady() || false;
		const supportsToolCalling = this.llmProvider?.registerTools !== undefined;

		let statusText = '🔧 Tool Calling Status:\n\n';
		statusText += `🤖 LLM Provider: ${isLLMReady ? 'Ready' : 'Not Ready'}\n`;
		statusText += `🔌 Tool Support: ${supportsToolCalling ? 'Supported' : 'Not Supported'}\n`;
		statusText += `🟢 Tool Calling: ${this._isToolCallingEnabled ? 'Enabled' : 'Disabled'}\n`;
		statusText += `📋 Available Tools: ${availableTools.length}\n`;

		if (availableTools.length > 0) {
			statusText += '\n📋 Available Tools:\n';
			for (const tool of availableTools.slice(0, 10)) { // Show first 10 tools
				statusText += `• ${tool.name}: ${tool.description}\n`;
			}
			if (availableTools.length > 10) {
				statusText += `... and ${availableTools.length - 10} more\n`;
			}
		}

		statusText += `\n💡 Commands:\n`;
		statusText += `• /tools-enable - Enable tool calling\n`;
		statusText += `• /tools-disable - Disable tool calling\n`;
		statusText += `• /tools-call <tool> <json-args> - Manually call a tool`;

		await this.command.addMessage('system', statusText);
	}

	/**
	 * Handle tool registration command
	 */
	private async handleRegisterTools(message: string): Promise<boolean> {
		if (!this.command) return false;

		const parts = message.trim().split(' ');
		if (parts.length < 3) {
			await this.command.addMessage('system', '❌ Usage: /tools-register <tool-name> <json-definition>');
			return true;
		}

		const toolName = parts[1];
		const definitionString = parts.slice(2).join(' ');

		try {
			const definition = JSON.parse(definitionString);

			const tool: RegistryToolDefinition = {
				name: toolName!,
				description: definition.description || toolName!,
				parameters: definition.parameters || {type: 'object', properties: {}},
				execute: async (params: any) => {
					// For dynamically registered tools, we'll just return the parameters
					return {called: toolName, parameters: params};
				},
			};

			toolRegistry.registerTool(tool);

			// Re-register with LLM if tool calling is enabled
			if (this._isToolCallingEnabled && this.llmProvider?.registerTools) {
				const allTools = toolRegistry.getAllTools();
				this.llmProvider.registerTools(allTools);
			}

			await this.command.addMessage('system', `✅ Tool registered: ${toolName}`);

		} catch (error) {
			await this.command.addMessage('system', `❌ Failed to register tool: ${error}`);
		}

		return true;
	}

	/**
	 * Handle manual tool call command
	 */
	private async handleManualToolCall(message: string): Promise<boolean> {
		if (!this.command) return false;

		const parts = message.trim().split(' ');
		if (parts.length < 2) {
			await this.command.addMessage('system', '❌ Usage: /tools-call <tool-name> <json-args>');
			return true;
		}

		const toolName = parts[1];
		const argsString = parts.slice(2).join(' ');

		if (!toolName) {
			await this.command.addMessage('system', '❌ Tool name is required');
			return true;
		}

		let parameters = {};
		if (argsString) {
			try {
				parameters = JSON.parse(argsString);
			} catch {
				await this.command.addMessage('system', '❌ Invalid JSON arguments');
				return true;
			}
		}

		await this.executeTool(toolName, parameters);
		return true;
	}

	/**
	 * Execute a tool manually
	 */
	private async executeTool(toolName: string, parameters: any): Promise<void> {
		if (!this.command) return;

		try {
			await this.command.addMessage('system', `🔧 Calling tool: ${toolName}`);

			const startTime = Date.now();
			const result = await toolRegistry.executeTool(toolName, parameters);
			const executionTime = Date.now() - startTime;

			const resultText = `✅ Tool Result (${executionTime}ms):\n\n${JSON.stringify(result, null, 2)}`;
			await this.command.addMessage('system', resultText);

		} catch (error) {
			await this.command.addMessage('system', `❌ Tool execution failed: ${error}`);
		}
	}

	/**
	 * Check if tool calling is enabled
	 */
	isToolCallingEnabled(): boolean {
		return this._isToolCallingEnabled;
	}

	/**
	 * Get available tools for LLM
	 */
	getAvailableTools(): RegistryToolDefinition[] {
		return toolRegistry.getAllTools();
	}
}

/**
 * Factory function to create a tool calling plugin
 */
export function createToolCallingPlugin(options?: ToolCallingPluginOptions): ToolCallingPlugin {
	return new ToolCallingPlugin(options);
}