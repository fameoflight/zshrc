/**
 * Configuration types for ink-cli commands
 */

export interface ConfigManager<T extends object> {
	config: T;
	updateConfig: (updates: Partial<T>) => Promise<void>;
	resetConfig: () => Promise<void>;
	saveConfig: () => Promise<void>;
	isLoading: boolean;
	error: string | null;
}

export interface ConfigSchema<T extends object> {
	defaults: T;
	validation: {
		[K in keyof T]?: (value: any) => boolean | string;
	};
}