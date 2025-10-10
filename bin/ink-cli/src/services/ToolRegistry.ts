/**
 * Tool Registry System
 *
 * Provides a centralized way to register and discover tools that can be used
 * by interactive commands and potentially called by LLMs in the future.
 */

export interface ToolDefinition {
	name: string;
	description: string;
	parameters: {
		type: 'object';
		properties: Record<string, any>;
		required?: string[];
	};
	execute: (parameters: Record<string, any>) => Promise<any>;
}

export interface ToolCategory {
	name: string;
	description: string;
	tools: ToolDefinition[];
}

/**
 * Registry for managing available tools
 */
export class ToolRegistry {
	private tools: Map<string, ToolDefinition> = new Map();
	private categories: Map<string, ToolCategory> = new Map();

	/**
	 * Register a single tool
	 */
	registerTool(tool: ToolDefinition): void {
		this.tools.set(tool.name, tool);
	}

	/**
	 * Register multiple tools
	 */
	registerTools(tools: ToolDefinition[]): void {
		for (const tool of tools) {
			this.registerTool(tool);
		}
	}

	/**
	 * Get a tool by name
	 */
	getTool(name: string): ToolDefinition | undefined {
		return this.tools.get(name);
	}

	/**
	 * Get all registered tools
	 */
	getAllTools(): ToolDefinition[] {
		return Array.from(this.tools.values());
	}

	/**
	 * Get tools filtered by category or criteria
	 */
	getTools(filter?: (tool: ToolDefinition) => boolean): ToolDefinition[] {
		const allTools = this.getAllTools();
		return filter ? allTools.filter(filter) : allTools;
	}

	/**
	 * Create a tool category
	 */
	createCategory(name: string, description: string, toolNames: string[]): void {
		const categoryTools = toolNames
			.map(toolName => this.getTool(toolName))
			.filter((tool): tool is ToolDefinition => tool !== undefined);

		this.categories.set(name, {
			name,
			description,
			tools: categoryTools,
		});
	}

	/**
	 * Get a category by name
	 */
	getCategory(name: string): ToolCategory | undefined {
		return this.categories.get(name);
	}

	/**
	 * Get all categories
	 */
	getAllCategories(): ToolCategory[] {
		return Array.from(this.categories.values());
	}

	/**
	 * Remove a tool
	 */
	unregisterTool(name: string): void {
		this.tools.delete(name);
		// Remove from categories
		for (const category of this.categories.values()) {
			category.tools = category.tools.filter(tool => tool.name !== name);
		}
	}

	/**
	 * Clear all tools
	 */
	clear(): void {
		this.tools.clear();
		this.categories.clear();
	}

	/**
	 * Execute a tool by name
	 */
	async executeTool(name: string, parameters: Record<string, any>): Promise<any> {
		const tool = this.getTool(name);
		if (!tool) {
			throw new Error(`Tool '${name}' not found`);
		}

		try {
			return await tool.execute(parameters);
		} catch (error) {
			throw new Error(`Error executing tool '${name}': ${error}`);
		}
	}

	/**
	 * Get tool schema for LLM function calling
	 */
	getToolSchema(name: string): any {
		const tool = this.getTool(name);
		if (!tool) {
			return null;
		}

		return {
			name: tool.name,
			description: tool.description,
			parameters: tool.parameters,
		};
	}

	/**
	 * Get all tool schemas for LLM function calling
	 */
	getAllToolSchemas(): any[] {
		return this.getAllTools().map(tool => this.getToolSchema(tool.name));
	}
}

// Global tool registry instance
export const toolRegistry = new ToolRegistry();

/**
 * Register a tool globally
 */
export function registerTool(tool: ToolDefinition): void {
	toolRegistry.registerTool(tool);
}

/**
 * Get a tool globally
 */
export function getTool(name: string): ToolDefinition | undefined {
	return toolRegistry.getTool(name);
}

/**
 * Execute a tool globally
 */
export async function executeTool(name: string, parameters: Record<string, any>): Promise<any> {
	return toolRegistry.executeTool(name, parameters);
}