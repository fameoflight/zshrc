import React, {ReactElement} from 'react';
import {BaseInteractiveCommand, Plugin, BaseInteractiveState} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {useConfig} from '../common/hooks/useConfig.js';

export interface ConfigPluginOptions<T = any> {
	/** Configuration schema */
	schema?: {
		defaults: T;
		validation?: Record<keyof T, (value: any) => true | string>;
	};
	/** Configuration namespace (for storage) */
	namespace?: string;
	/** Enable runtime config changes */
	enableRuntimeChanges?: boolean;
}

/**
 * Config Plugin - Provides configuration management for interactive commands
 *
 * This plugin enables commands to have persistent configuration with validation,
 * runtime updates, and easy management through chat commands.
 */
export class ConfigPlugin<T extends object = any> implements Plugin {
	name = 'config';

	private command?: BaseInteractiveCommand<any>;
	private options: ConfigPluginOptions<T>;
	private namespace: string;
	private config?: T;
	private updateConfig?: (updates: Partial<T>) => Promise<void>;
	private resetFunction?: () => Promise<void>;

	constructor(options: ConfigPluginOptions<T> = {}) {
		this.options = options;
		this.namespace = options.namespace || 'default';
	}

	async initialize(command: BaseInteractiveCommand<any>): Promise<void> {
		this.command = command;

		// Note: In a real implementation, we'd integrate with the useConfig hook
		// For now, we'll provide a simple in-memory config
		const defaultConfig = this.options.schema?.defaults || {} as T;
		this.config = {...defaultConfig};
	}

	async cleanup(): Promise<void> {
		// Cleanup any config-related resources
	}

	async onMessage(message: string): Promise<boolean> {
		if (!this.command) return false;

		// Handle configuration commands
		if (message.startsWith('/config')) {
			return await this.handleConfigCommand(message);
		}

		return false;
	}

	onStateChange(state: BaseInteractiveState): void {
		// React to state changes if needed
	}

	renderComponents(): ReactElement[] {
		// Config plugin doesn't render UI components by default
		// It provides commands and backend functionality
		return [];
	}

	/**
	 * Handle configuration commands
	 */
	private async handleConfigCommand(command: string): Promise<boolean> {
		if (!this.command) return false;

		const parts = command.trim().split(' ');

		// Default to showing config if no subcommand provided
		if (parts.length < 2) {
			await this.showConfig();
			return true;
		}

		const subcommand = parts[1]?.toLowerCase() || '';

		switch (subcommand) {
			case 'list':
			case 'show':
				await this.showConfig();
				return true;

			case 'set':
				if (parts.length < 4) {
					await this.command.addMessage('system', '❌ Usage: /config set <key> <value>');
					return true;
				}
				await this.setConfigValue(parts[2] || '', parts.slice(3).join(' '));
				return true;

			case 'get':
				if (parts.length < 3) {
					await this.command.addMessage('system', '❌ Usage: /config get <key>');
					return true;
				}
				await this.getConfigValue(parts[2] || '');
				return true;

			case 'reset':
				await this.resetConfig();
				return true;

			case 'validate':
				await this.validateConfig();
				return true;

			case 'export':
				await this.exportConfig();
				return true;

			case 'import':
				if (parts.length < 3) {
					await this.command.addMessage('system', '❌ Usage: /config import <json>');
					return true;
				}
				await this.importConfig(parts.slice(2).join(' '));
				return true;

			default:
				await this.command.addMessage('system', `❌ Unknown config command: ${subcommand}`);
				await this.command.addMessage('system', 'Available: list, set, get, reset, validate, export, import');
				return true;
		}
	}

	/**
	 * Show current configuration
	 */
	private async showConfig(): Promise<void> {
		if (!this.command || !this.config) return;

		const configEntries = Object.entries(this.config)
			.map(([key, value]) => {
				const displayValue = value === undefined || value === null
					? 'not set'
					: typeof value === 'string' && value.length > 50
						? value.substring(0, 47) + '...'
						: String(value);
				return `• ${key}: ${displayValue}`;
			})
			.join('\n');

		const configText = `
⚙️ Configuration (${this.namespace}):

${configEntries || 'No configuration set'}

💡 Use /config set <key> <value> to update settings
Use /config reset to restore defaults
		`.trim();

		await this.command.addMessage('system', configText);
	}

	/**
	 * Set a configuration value
	 */
	private async setConfigValue(key: string, rawValue: string): Promise<void> {
		if (!this.command || !this.config) return;

		try {
			// Convert value to appropriate type
			let convertedValue: any = rawValue;

			// Try number conversion
			if (!isNaN(Number(rawValue)) && rawValue.trim() !== '') {
				convertedValue = Number(rawValue);
			}
			// Try boolean conversion
			else if (rawValue.toLowerCase() === 'true') {
				convertedValue = true;
			} else if (rawValue.toLowerCase() === 'false') {
				convertedValue = false;
			}
			// Try JSON conversion for objects/arrays
			else if ((rawValue.startsWith('{') && rawValue.endsWith('}')) ||
							 (rawValue.startsWith('[') && rawValue.endsWith(']'))) {
				try {
					convertedValue = JSON.parse(rawValue);
				} catch {
					// Keep as string if JSON parsing fails
				}
			}

			// Validate if validation rules exist
			const validationRule = this.options.schema?.validation?.[key as keyof T];
			if (validationRule) {
				const validationResult = validationRule(convertedValue);
				if (validationResult !== true) {
					await this.command.addMessage('system', `❌ Validation failed: ${validationResult}`);
					return;
				}
			}

			// Update config
			const oldValue = this.config[key as keyof T];
			this.config[key as keyof T] = convertedValue;

			// Update command state if it's a known property
			if (this.command && key in this.command.getState()) {
				this.command.updateState({[key]: convertedValue} as any);
			}

			await this.command.addMessage('system', `✅ ${key} updated: ${oldValue} → ${convertedValue}`);

		} catch (error) {
			await this.command.addMessage('system', `❌ Failed to set ${key}: ${error}`);
		}
	}

	/**
	 * Get a configuration value
	 */
	private async getConfigValue(key: string): Promise<void> {
		if (!this.command || !this.config) return;

		const value = this.config[key as keyof T];
		const displayValue = value === undefined || value === null
			? 'not set'
			: JSON.stringify(value, null, 2);

		await this.command.addMessage('system', `⚙️ ${key}: ${displayValue}`);
	}

	/**
	 * Reset configuration to defaults
	 */
	private async resetConfig(): Promise<void> {
		if (!this.command || !this.config) return;

		try {
			const defaults = this.options.schema?.defaults || {} as T;
			this.config = {...defaults};

			// Update command state with defaults
			if (this.command) {
				this.command.updateState(defaults as any);
			}

			await this.command.addMessage('system', '✅ Configuration reset to defaults');
		} catch (error) {
			await this.command.addMessage('system', `❌ Failed to reset config: ${error}`);
		}
	}

	/**
	 * Validate current configuration
	 */
	private async validateConfig(): Promise<void> {
		if (!this.command || !this.config) return;

		const validationRules = this.options.schema?.validation;
		if (!validationRules) {
			await this.command.addMessage('system', 'ℹ️ No validation rules configured');
			return;
		}

		const errors: string[] = [];
		const warnings: string[] = [];

		for (const [key, rule] of Object.entries(validationRules)) {
			const value = this.config[key as keyof T];
			if (value !== undefined) {
				try {
					const result = (rule as (value: any) => true | string)(value);
					if (result !== true) {
						errors.push(`${key}: ${result}`);
					}
				} catch (error) {
					errors.push(`${key}: ${error}`);
				}
			} else {
				warnings.push(`${key}: not set`);
			}
		}

		if (errors.length === 0 && warnings.length === 0) {
			await this.command.addMessage('system', '✅ Configuration is valid');
		} else {
			let message = '🔍 Configuration Validation:\n\n';
			if (errors.length > 0) {
				message += '❌ Errors:\n' + errors.map(e => `  • ${e}`).join('\n') + '\n\n';
			}
			if (warnings.length > 0) {
				message += '⚠️ Warnings:\n' + warnings.map(w => `  • ${w}`).join('\n');
			}
			await this.command.addMessage('system', message.trim());
		}
	}

	/**
	 * Export configuration as JSON
	 */
	private async exportConfig(): Promise<void> {
		if (!this.command || !this.config) return;

		try {
			const exported = JSON.stringify(this.config, null, 2);
			await this.command.addMessage('system', `📄 Configuration Export:\n\n\`\`\`json\n${exported}\n\`\`\``);
		} catch (error) {
			await this.command.addMessage('system', `❌ Failed to export config: ${error}`);
		}
	}

	/**
	 * Import configuration from JSON
	 */
	private async importConfig(jsonString: string): Promise<void> {
		if (!this.command || !this.config) return;

		try {
			const importedConfig = JSON.parse(jsonString);
			const defaults = this.options.schema?.defaults || {} as T;

			// Merge with defaults
			this.config = {...defaults, ...importedConfig};

			await this.command.addMessage('system', '✅ Configuration imported successfully');
		} catch (error) {
			await this.command.addMessage('system', `❌ Failed to import config: ${error}`);
		}
	}

	/**
	 * Get current configuration
	 */
	getConfig(): T | undefined {
		return this.config;
	}

	/**
	 * Get configuration value by key
	 */
	get<K extends keyof T>(key: K): T[K] | undefined {
		return this.config?.[key];
	}

	/**
	 * Set configuration value
	 */
	set<K extends keyof T>(key: K, value: T[K]): void {
		if (this.config) {
			this.config[key] = value;
		}
	}
}

/**
 * Factory function to create a config plugin
 */
export function createConfigPlugin<T extends object = any>(
	options?: ConfigPluginOptions<T>
): ConfigPlugin<T> {
	return new ConfigPlugin<T>(options);
}