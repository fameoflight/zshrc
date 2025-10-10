import {ChatCommand} from './chatCommands.js';

export interface ConfigCommandContext<T> {
	messages: any[];
	messageCount: number;
	clearMessages: () => void;
	addMessage: (role: any, content: string) => void;
	currentResponse?: string;
	isStreaming: boolean;
	setError: (error: string | null) => void;
	updateConfig: (updates: Partial<T>) => Promise<void>;
	resetConfig: () => Promise<void>;
	config: T;
	logger?: any;
}

export function createConfigCommands<T extends object>(
	config: T,
	_updateConfig: (updates: Partial<T>) => Promise<void>,
	resetConfig: () => Promise<void>,
	_configType: string = 'config'
): ChatCommand[] {
	const configEntries = Object.entries(config)
		.map(([key, value]) => `• ${key}: ${value || 'not set'}`)
		.join('\n');

	const availableKeys = Object.keys(config).join(', ');

	return [
		{
			label: '/config list',
			value: 'config-list',
			description: 'Show current configuration settings',
			execute: async (context: any) => {
				const configContext = context as ConfigCommandContext<T>;
				configContext.addMessage('system', `⚙️ Current Configuration:\n\n${configEntries}`);
			},
		},
		{
			label: '/config set',
			value: 'config-set',
			description: 'Update a configuration setting',
			execute: async (context: any) => {
				const configContext = context as ConfigCommandContext<T>;
				configContext.addMessage('system', `❌ Please use text input: /config set <key> <value>\n\nAvailable keys: ${availableKeys}`);
			},
		},
		{
			label: '/config reset',
			value: 'config-reset',
			description: 'Reset configuration to defaults',
			execute: async (context: any) => {
				const configContext = context as ConfigCommandContext<T>;
				try {
					await resetConfig();
					configContext.addMessage('system', '✅ Configuration reset to defaults');
				} catch (error) {
					configContext.addMessage('system', `❌ Failed to reset config: ${error}`);
				}
			},
		},
	];
}

// Legacy function for backward compatibility
export function createConfigCommand<T extends object>(
	_config: T,
	_updateConfig: (updates: Partial<T>) => Promise<void>,
	_resetConfig: () => Promise<void>,
	configType: string = 'config'
): ChatCommand {
	return {
		label: '/config',
		value: 'config',
		description: `Manage ${configType} configuration`,
		execute: async (context: any) => {
			const configContext = context as ConfigCommandContext<T>;
			configContext.addMessage('system', `⚙️ Please select a specific config command from the menu.`);
		},
	};
}