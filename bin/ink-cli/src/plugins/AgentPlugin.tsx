import React, {ReactElement} from 'react';
import {BaseInteractiveCommand, Plugin, BaseInteractiveState} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {agentSystem, startAgent, stopAgent, getAgentStatus} from '../frameworks/agents/AgentSystem.js';
import {LLMProvider} from '../services/LLMProvider.js';
import {serviceContainer} from '../services/ServiceProvider.js';

export interface AgentPluginOptions {
	/** Enable agent auto-start */
	autoStart?: boolean;
	/** Default agent goal */
	defaultGoal?: string;
	/** Enable tool calling */
	enableToolCalling?: boolean;
}

/**
 * Agent Plugin - Provides autonomous agent capabilities for interactive commands
 *
 * This plugin enables commands to create and manage autonomous agents that can
 * use tools, make decisions, and work towards goals independently.
 */
export class AgentPlugin implements Plugin {
	name = 'agent';

	private command?: BaseInteractiveCommand<any>;
	private options: AgentPluginOptions;
	private currentAgentId?: string;
	private llmProvider?: LLMProvider;

	constructor(options: AgentPluginOptions = {}) {
		this.options = options;
	}

	async initialize(command: BaseInteractiveCommand<any>): Promise<void> {
		this.command = command;
		this.llmProvider = serviceContainer.resolve<LLMProvider>('llm-provider');

		// Auto-start agent if enabled
		if (this.options.autoStart && this.options.defaultGoal) {
			const state = command.getState();
			this.currentAgentId = `agent-${state.sessionId}`;
			await startAgent(
				this.currentAgentId,
				this.options.defaultGoal,
				state.sessionId,
				this.llmProvider
			);
		}
	}

	async cleanup(): Promise<void> {
		// Stop any running agents
		if (this.currentAgentId) {
			await stopAgent(this.currentAgentId);
		}
	}

	async onMessage(message: string): Promise<boolean> {
		if (!this.command) return false;

		// Handle agent-related commands
		if (message.startsWith('/')) {
			const commandName = message.substring(1).toLowerCase();

			switch (commandName) {
				case 'agent-start':
					return await this.handleAgentStart(message);

				case 'agent-stop':
					return await this.handleAgentStop();

				case 'agent-status':
					await this.showAgentStatus();
					return true;

				case 'agent-goal':
					return await this.handleAgentGoal(message);

				case 'agents':
				case 'agent-list':
					await this.listAgents();
					return true;

				default:
					return false;
			}
		}

		// Forward message to current agent if one is running
		if (this.currentAgentId) {
			const agentStatus = getAgentStatus(this.currentAgentId);
			if (agentStatus && (agentStatus.status === 'running' || agentStatus.status === 'waiting')) {
				await agentSystem.sendAgentInput(this.currentAgentId, message);
				return true;
			}
		}

		return false;
	}

	onStateChange(state: BaseInteractiveState): void {
		// React to state changes if needed
	}

	renderComponents(): ReactElement[] {
		if (!this.command) return [];

		const components: ReactElement[] = [];

		// Show agent status if an agent is running
		if (this.currentAgentId) {
			const agentStatus = getAgentStatus(this.currentAgentId);
			if (agentStatus) {
				components.push(this.renderAgentStatus(agentStatus));
			}
		}

		return components;
	}

	/**
	 * Handle agent start command
	 */
	private async handleAgentStart(message: string): Promise<boolean> {
		if (!this.command) return false;

		const parts = message.trim().split(' ');
		const goal = parts.slice(2).join(' ');

		if (!goal) {
			await this.command.addMessage('system', '❌ Usage: /agent-start <goal>');
			return true;
		}

		const state = this.command.getState();

		try {
			// Stop existing agent if running
			if (this.currentAgentId) {
				await stopAgent(this.currentAgentId);
			}

			// Start new agent
			this.currentAgentId = `agent-${state.sessionId}-${Date.now()}`;
			await startAgent(
				this.currentAgentId,
				goal,
				state.sessionId,
				this.llmProvider
			);

			await this.command.addMessage(
				'system',
				`🤖 Agent started with goal: "${goal}"`
			);

		} catch (error) {
			await this.command.addMessage(
				'system',
				`❌ Failed to start agent: ${error}`
			);
		}

		return true;
	}

	/**
	 * Handle agent stop command
	 */
	private async handleAgentStop(): Promise<boolean> {
		if (!this.command) return false;

		if (!this.currentAgentId) {
			await this.command.addMessage('system', 'ℹ️ No agent is currently running');
			return true;
		}

		try {
			await stopAgent(this.currentAgentId);
			this.currentAgentId = undefined;

			await this.command.addMessage('system', '🛑 Agent stopped');

		} catch (error) {
			await this.command.addMessage(
				'system',
				`❌ Failed to stop agent: ${error}`
			);
		}

		return true;
	}

	/**
	 * Handle agent goal command
	 */
	private async handleAgentGoal(message: string): Promise<boolean> {
		if (!this.command) return false;

		if (!this.currentAgentId) {
			await this.command.addMessage('system', 'ℹ️ No agent is currently running');
			return true;
		}

		const parts = message.trim().split(' ');
		const newGoal = parts.slice(2).join(' ');

		if (!newGoal) {
			await this.command.addMessage('system', '❌ Usage: /agent-goal <new-goal>');
			return true;
		}

		const agentStatus = getAgentStatus(this.currentAgentId);
		if (agentStatus) {
			await this.command.addMessage(
				'system',
				`🎯 Agent goal updated: "${agentStatus.goal}" → "${newGoal}"`
			);
		}

		return true;
	}

	/**
	 * Show agent status
	 */
	private async showAgentStatus(): Promise<void> {
		if (!this.command) return;

		if (!this.currentAgentId) {
			await this.command.addMessage('system', 'ℹ️ No agent is currently running');
			return;
		}

		const agentStatus = getAgentStatus(this.currentAgentId);
		if (!agentStatus) {
			await this.command.addMessage('system', 'ℹ️ Agent status not available');
			return;
		}

		const statusText = `
🤖 Agent Status:

🆔 ID: ${agentStatus.id}
🎯 Goal: ${agentStatus.goal}
📊 Status: ${agentStatus.status}
${agentStatus.currentAction ? `🔄 Current Action: ${agentStatus.currentAction}` : ''}
${agentStatus.progress !== undefined ? `📈 Progress: ${Math.round(agentStatus.progress * 100)}%` : ''}
		`.trim();

		await this.command.addMessage('system', statusText);
	}

	/**
	 * List all running agents
	 */
	private async listAgents(): Promise<void> {
		if (!this.command) return;

		const runningAgents = agentSystem.getRunningAgents();

		if (runningAgents.length === 0) {
			await this.command.addMessage('system', 'ℹ️ No agents are currently running');
			return;
		}

		let listText = `🤖 Running Agents (${runningAgents.length}):\n\n`;

		for (const agentId of runningAgents) {
			const status = getAgentStatus(agentId);
			if (status) {
				listText += `• ${status.id}: ${status.goal} (${status.status})\n`;
			}
		}

		await this.command.addMessage('system', listText);
	}

	/**
	 * Render agent status component
	 */
	private renderAgentStatus(agentStatus: any): ReactElement {
		const statusColor = {
			running: 'yellow',
			waiting: 'blue',
			stopped: 'gray',
			error: 'red',
			starting: 'cyan',
		}[agentStatus.status] || 'gray';

		const statusIcon = {
			running: '🔄',
			waiting: '⏸️',
			stopped: '⏹️',
			error: '❌',
			starting: '⏯️',
		}[agentStatus.status] || '❓';

		return React.createElement('div', {}, [
			React.createElement('div', {key: 'agent-status'}, [
				React.createElement('span', {style: {color: statusColor}}, `${statusIcon} Agent: ${agentStatus.status}`),
				agentStatus.currentAction && ` (${agentStatus.currentAction})`,
			]),
		]);
	}

	/**
	 * Get current agent ID
	 */
	getCurrentAgentId(): string | undefined {
		return this.currentAgentId;
	}

	/**
	 * Check if an agent is currently running
	 */
	isAgentRunning(): boolean {
		if (!this.currentAgentId) return false;
		const status = getAgentStatus(this.currentAgentId);
		return status ? status.status === 'running' || status.status === 'waiting' : false;
	}
}

/**
 * Factory function to create an agent plugin
 */
export function createAgentPlugin(options?: AgentPluginOptions): AgentPlugin {
	return new AgentPlugin(options);
}