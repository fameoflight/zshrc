import {LLMProvider, ToolDefinition, ToolResult} from '../../services/LLMProvider.js';
import {toolRegistry} from '../../services/ToolRegistry.js';
import {contextManager} from '../../services/ContextManager.js';

export interface AgentCapability {
	name: string;
	description: string;
	execute: (context: AgentContext) => Promise<AgentResult>;
}

export interface AgentContext {
	sessionId: string;
	userInput: string;
	conversationHistory: any[];
	availableTools: ToolDefinition[];
	llmProvider?: LLMProvider;
	goal?: string;
	state: Record<string, any>;
}

export interface AgentResult {
	success: boolean;
	result: any;
	error?: string;
	actions: AgentAction[];
	toolsUsed?: string[];
	nextAction?: 'continue' | 'stop' | 'clarify';
	clarification?: string;
}

export interface AgentAction {
	type: 'tool_call' | 'llm_response' | 'user_input' | 'wait';
	description: string;
	data?: any;
	confidence?: number;
}

/**
 * Agent System - Framework for creating autonomous agents
 *
 * Provides the foundation for agents that can use tools, make decisions,
 * and interact with users to achieve goals.
 */
export class AgentSystem {
	private capabilities: Map<string, AgentCapability> = new Map();
	private agents: Map<string, RunningAgent> = new Map();

	/**
	 * Register an agent capability
	 */
	registerCapability(capability: AgentCapability): void {
		this.capabilities.set(capability.name, capability);
	}

	/**
	 * Get a capability by name
	 */
	getCapability(name: string): AgentCapability | undefined {
		return this.capabilities.get(name);
	}

	/**
	 * Create and start an agent
	 */
	async startAgent(
		agentId: string,
		goal: string,
		sessionId: string,
		llmProvider?: LLMProvider
	): Promise<void> {
		const agent = new RunningAgent(
			agentId,
			goal,
			sessionId,
			llmProvider,
			this.capabilities
		);

		this.agents.set(agentId, agent);
		await agent.start();
	}

	/**
	 * Stop an agent
	 */
	async stopAgent(agentId: string): Promise<void> {
		const agent = this.agents.get(agentId);
		if (agent) {
			await agent.stop();
			this.agents.delete(agentId);
		}
	}

	/**
	 * Get agent status
	 */
	getAgentStatus(agentId: string): AgentStatus | null {
		const agent = this.agents.get(agentId);
		return agent ? agent.getStatus() : null;
	}

	/**
	 * List all running agents
	 */
	getRunningAgents(): string[] {
		return Array.from(this.agents.keys());
	}

	/**
	 * Send input to an agent
	 */
	async sendAgentInput(agentId: string, input: string): Promise<void> {
		const agent = this.agents.get(agentId);
		if (agent) {
			await agent.processInput(input);
		}
	}
}

interface AgentStatus {
	id: string;
	goal: string;
	status: 'starting' | 'running' | 'waiting' | 'stopped' | 'error';
	currentAction?: string;
	progress?: number;
	error?: string;
}

class RunningAgent {
	private id: string;
	private goal: string;
	private sessionId: string;
	private llmProvider?: LLMProvider;
	private capabilities: Map<string, AgentCapability>;
	private status: AgentStatus['status'] = 'starting';
	private currentAction?: string;
	private state: Record<string, any> = {};
	private isActive = true;

	constructor(
		id: string,
		goal: string,
		sessionId: string,
		llmProvider: LLMProvider | undefined,
		capabilities: Map<string, AgentCapability>
	) {
		this.id = id;
		this.goal = goal;
		this.sessionId = sessionId;
		this.llmProvider = llmProvider;
		this.capabilities = capabilities;
	}

	async start(): Promise<void> {
		this.status = 'running';
		await this.processGoal();
	}

	async stop(): Promise<void> {
		this.isActive = false;
		this.status = 'stopped';
	}

	getStatus(): AgentStatus {
		return {
			id: this.id,
			goal: this.goal,
			status: this.status,
			currentAction: this.currentAction,
		};
	}

	async processInput(input: string): Promise<void> {
		if (!this.isActive) return;

		// Add user input to conversation
		await contextManager.addMessage(this.sessionId, 'user', input);

		// Continue processing
		await this.processGoal();
	}

	private async processGoal(): Promise<void> {
		if (!this.isActive) return;

		try {
			// Get conversation history
			const history = contextManager.getConversation(this.sessionId);
			const availableTools = toolRegistry.getAllToolSchemas();

			// Create agent context
			const agentContext: AgentContext = {
				sessionId: this.sessionId,
				userInput: history[history.length - 1]?.content || '',
				conversationHistory: history,
				availableTools,
				llmProvider: this.llmProvider,
				goal: this.goal,
				state: this.state,
			};

			// Use LLM to decide next action if available
			if (this.llmProvider && this.llmProvider.isReady()) {
				await this.processWithLLM(agentContext);
			} else {
				await this.processWithoutLLM(agentContext);
			}

		} catch (error) {
			this.status = 'error';
			await contextManager.addMessage(
				this.sessionId,
				'system',
				`❌ Agent error: ${error}`
			);
		}
	}

	private async processWithLLM(context: AgentContext): Promise<void> {
		if (!this.llmProvider) return;

		// Create prompt for LLM
		const prompt = this.createAgentPrompt(context);

		try {
			let llmResponse = '';
			await this.llmProvider.streamChat(
				[{
					role: 'user',
					content: prompt,
				}],
				(chunk) => {
					if (chunk.content) {
						llmResponse += chunk.content;
					}
				},
				context.availableTools
			);

			// Parse LLM response and execute actions
			await this.executeLLMResponse(llmResponse, context);

		} catch (error) {
			await contextManager.addMessage(
				context.sessionId,
				'system',
				`❌ Agent LLM error: ${error}`
			);
		}
	}

	private async processWithoutLLM(context: AgentContext): Promise<void> {
		// Fallback behavior without LLM
		await contextManager.addMessage(
			context.sessionId,
			'system',
			'🤖 Agent ready, but LLM not available. Please provide specific instructions.'
		);
		this.status = 'waiting';
	}

	private createAgentPrompt(context: AgentContext): string {
		const toolsList = context.availableTools
			.map(tool => `- ${tool.name}: ${tool.description}`)
			.join('\n');

		return `
You are an AI assistant with access to tools. Your goal is: ${context.goal}

Available tools:
${toolsList}

Recent conversation:
${context.conversationHistory.slice(-5).map(msg => `${msg.role}: ${msg.content}`).join('\n')}

Current state: ${JSON.stringify(context.state, null, 2)}

Respond with a JSON object containing:
{
  "thought": "your reasoning about what to do next",
  "action": "tool_call or llm_response or wait",
  "tool_name": "name of tool to use (if action is tool_call)",
  "tool_parameters": {...parameters for tool...},
  "response": "what to say to user (if action is llm_response)",
  "update_state": {...key-value pairs to update your state...}
}
		`.trim();
	}

	private async executeLLMResponse(response: string, context: AgentContext): Promise<void> {
		try {
			// Try to parse JSON response
			const jsonMatch = response.match(/\{[\s\S]*\}/);
			if (!jsonMatch) {
				// If no JSON, treat as plain response
				await contextManager.addMessage(context.sessionId, 'assistant', response);
				return;
			}

			const parsed = JSON.parse(jsonMatch[0]);

			// Update state
			if (parsed.update_state) {
				this.state = {...this.state, ...parsed.update_state};
			}

			// Execute action
			switch (parsed.action) {
				case 'tool_call':
					if (parsed.tool_name && parsed.tool_parameters) {
						await this.executeTool(parsed.tool_name, parsed.tool_parameters, context);
					}
					break;

				case 'llm_response':
					if (parsed.response) {
						await contextManager.addMessage(context.sessionId, 'assistant', parsed.response);
					}
					this.status = 'waiting';
					break;

				case 'wait':
					await contextManager.addMessage(context.sessionId, 'assistant', parsed.thought || 'Waiting for further input.');
					this.status = 'waiting';
					break;

				default:
					await contextManager.addMessage(
						context.sessionId,
						'system',
						`❌ Unknown action: ${parsed.action}`
					);
			}

		} catch (error) {
			await contextManager.addMessage(
				context.sessionId,
				'system',
				`❌ Failed to parse agent response: ${error}`
			);
		}
	}

	private async executeTool(toolName: string, parameters: any, context: AgentContext): Promise<void> {
		this.currentAction = `Using tool: ${toolName}`;

		try {
			const result = await toolRegistry.executeTool(toolName, parameters);

			await contextManager.addMessage(
				context.sessionId,
				'tool',
				`Used tool ${toolName} with result: ${JSON.stringify(result)}`
			);

			// Continue processing after tool execution
			setTimeout(() => this.processGoal(), 1000);

		} catch (error) {
			await contextManager.addMessage(
				context.sessionId,
				'system',
				`❌ Tool execution failed: ${error}`
			);
		}

		this.currentAction = undefined;
	}
}

// Global agent system instance
export const agentSystem = new AgentSystem();

/**
 * Convenience functions for global agent management
 */
export async function startAgent(
	agentId: string,
	goal: string,
	sessionId: string,
	llmProvider?: LLMProvider
): Promise<void> {
	return agentSystem.startAgent(agentId, goal, sessionId, llmProvider);
}

export async function stopAgent(agentId: string): Promise<void> {
	return agentSystem.stopAgent(agentId);
}

export function getAgentStatus(agentId: string): AgentStatus | null {
	return agentSystem.getAgentStatus(agentId);
}