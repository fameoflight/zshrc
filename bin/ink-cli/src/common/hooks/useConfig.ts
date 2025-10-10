import {useState, useEffect, useCallback} from 'react';
import fs from 'fs';

import {ConfigManager, ConfigSchema} from '../types/config.js';
import {getConfigPath} from '../utils.js';
import {useAppContext} from '../context/AppContext.js';

function loadConfig<T>(commandName: string, defaults: T): T {
	const configPath = getConfigPath(commandName);

	try {
		if (fs.existsSync(configPath)) {
			const configData = fs.readFileSync(configPath, 'utf8');
			const parsed = JSON.parse(configData);
			return {...defaults, ...parsed};
		}
	} catch (error) {
		console.warn(`Failed to load config from ${configPath}:`, error);
	}

	return defaults;
}

function saveConfig<T>(commandName: string, config: T): void {
	const configPath = getConfigPath(commandName);
	try {
		fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
	} catch (error) {
		throw new Error(`Failed to save config to ${configPath}: ${error}`);
	}
}

export function useConfig<T extends object>(
	commandName: string,
	schema: ConfigSchema<T>
): ConfigManager<T> {
	const { logger } = useAppContext();

	// Use simple state - no refs, no force updates
	const [config, setConfig] = useState<T>(schema.defaults);
	const [isLoading, setIsLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);

	// Load config on mount only once
	useEffect(() => {
		logger.debug(`[useConfig] Effect RUNNING for command: ${commandName}`);
		let mounted = true;

		const loadAndSetConfig = async () => {
			try {
				const loadedConfig = loadConfig(commandName, schema.defaults);

				// Simple validation for temperature if it exists
				const temperature = (loadedConfig as any).temperature;
				if (temperature !== undefined &&
					(typeof temperature !== 'number' ||
					 temperature < 0 ||
					 temperature > 2)) {
					logger.warn('Invalid temperature in config, using default');
					if (mounted) {
						setConfig(schema.defaults);
					}
				} else {
					if (mounted) {
						setConfig({...schema.defaults, ...loadedConfig});
					}
				}

				if (mounted) {
					setIsLoading(false);
				}
			} catch (err) {
				if (mounted) {
					setError(err instanceof Error ? err.message : 'Failed to load config');
					setIsLoading(false);
				}
			}
		};

		loadAndSetConfig();

		return () => {
			logger.debug(`[useConfig] Effect CLEANUP for command: ${commandName}`);
			mounted = false;
		};
	}, [commandName]); // Only depend on commandName

	const updateConfig = useCallback(async (updates: Partial<T>) => {
		logger.debug(`[useConfig] updateConfig called with:`, updates);
		try {
			// Validate temperature if present
			if ('temperature' in updates && updates.temperature !== undefined) {
				const temp = updates.temperature as any;
				if (typeof temp !== 'number' || isNaN(temp) || temp < 0 || temp > 2) {
					throw new Error('Temperature must be a number between 0.0 and 2.0');
				}
			}

			const newConfig = {...config, ...updates};
			saveConfig(commandName, newConfig);
			setConfig(newConfig);
		} catch (err) {
			throw new Error(`Failed to update config: ${err}`);
		}
	}, [config, commandName]);

	const resetConfig = useCallback(async () => {
		try {
			saveConfig(commandName, schema.defaults);
			setConfig(schema.defaults);
		} catch (err) {
			throw new Error(`Failed to reset config: ${err}`);
		}
	}, [commandName, schema.defaults]);

	return {
		config,
		updateConfig,
		resetConfig,
		saveConfig: async () => saveConfig(commandName, config),
		isLoading,
		error,
	};
}