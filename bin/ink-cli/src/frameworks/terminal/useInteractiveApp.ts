import {useState, useCallback, useEffect, useMemo} from 'react';
import {useApp} from 'ink';
import {InteractiveAppState, InteractiveAppOptions} from './types.js';

/**
 * useInteractiveApp - Core interactive app state management
 *
 * Provides common patterns for interactive terminal applications:
 * - Initialization state management
 * - Error handling and recovery
 * - Application lifecycle management
 * - Status computation
 *
 * @example
 * const { appState, initialize, handleError, exit } = useInteractiveApp({
 *   title: 'My App',
 *   onInitialize: async () => {
 *     await setupResources();
 *     return { data: 'ready' };
 *   },
 *   exitOnCtrlC: true
 * });
 */
export function useInteractiveApp<T = any>(options: InteractiveAppOptions = {}) {
	const {title, onInitialize, onCleanup} = options;
	const {exit} = useApp();

	const [appState, setAppState] = useState<InteractiveAppState & {data?: T}>({
		isInitialized: false,
		error: null,
		isActive: true,
		currentInput: '',
	});

	// Initialize application
	const initialize = useCallback(async () => {
		setAppState(prev => ({...prev, isInitialized: false, error: null}));

		try {
			if (onInitialize) {
				await onInitialize();
				setAppState(prev => ({
					...prev,
					isInitialized: true,
				}));
			} else {
				setAppState(prev => ({...prev, isInitialized: true}));
			}
		} catch (error) {
			setAppState(prev => ({
				...prev,
				error: error instanceof Error ? error.message : String(error),
			}));
		}
	}, [onInitialize]);

	// Handle errors
	const handleError = useCallback((error: string | Error) => {
		const message = error instanceof Error ? error.message : error;
		setAppState(prev => ({...prev, error: message}));
	}, []);

	// Clear errors
	const clearError = useCallback(() => {
		setAppState(prev => ({...prev, error: null}));
	}, []);

	// Update current input
	const updateInput = useCallback((input: string) => {
		setAppState(prev => ({...prev, currentInput: input}));
	}, []);

	// Exit application
	const exitApp = useCallback(async () => {
		try {
			if (onCleanup) {
				await onCleanup();
			}
		} catch (error) {
			console.error('Error during cleanup:', error);
		}
		exit();
	}, [exit, onCleanup]);

	// Reset application state
	const reset = useCallback(() => {
		setAppState({
			isInitialized: false,
			error: null,
			isActive: true,
			currentInput: '',
		});
	}, []);

	// Auto-initialize on mount
	useEffect(() => {
		initialize();
	}, [initialize]);

	// Compute application status
	const status = useMemo(() => {
		if (appState.error) {
			return { text: 'Error', color: 'red', icon: '❌' };
		}

		if (!appState.isInitialized) {
			return { text: 'Initializing...', color: 'cyan', icon: '🔄', pulse: true };
		}

		if (appState.currentInput) {
			return { text: 'Typing...', color: 'blue', icon: '✏️' };
		}

		return { text: 'Ready', color: 'green', icon: '✓' };
	}, [appState]);

	// Get info text
	const getInfo = useCallback(() => {
		if (appState.error) {
			return appState.error;
		}

		if (!appState.isInitialized) {
			return title ? `Initializing ${title}...` : 'Initializing...';
		}

		return title ? `${title} - Ready` : 'Ready';
	}, [appState, title]);

	return {
		// State
		appState,
		status,
		info: getInfo(),

		// Actions
		initialize,
		handleError,
		clearError,
		updateInput,
		exit: exitApp,
		reset,

		// Computed properties
		isReady: appState.isInitialized && !appState.error,
		hasError: !!appState.error,
		isActive: appState.isActive,
	};
}