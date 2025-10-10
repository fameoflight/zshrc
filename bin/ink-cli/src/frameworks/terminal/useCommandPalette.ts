import {useState, useCallback, useMemo} from 'react';
import {useInput} from 'ink';
import {Command, CommandPaletteState} from './types.js';

export interface UseCommandPaletteOptions {
	commands: Command[];
	isOpen?: boolean;
	onOpen?: () => void;
	onClose?: () => void;
	onSelect?: (command: Command) => void;
	triggerKey?: string;
}

/**
 * useCommandPalette - Generic command palette system
 *
 * Provides command discovery and execution with keyboard navigation.
 * Similar to VS Code command palette or application launchers.
 *
 * @example
 * const commands = [
 *   { id: 'clear', label: 'Clear History', description: 'Clear all data', action: clearHistory },
 *   { id: 'refresh', label: 'Refresh', description: 'Refresh data', action: refreshData }
 * ];
 *
 * const { paletteState, openPalette, closePalette } = useCommandPalette({
 *   commands,
 *   onSelect: (cmd) => cmd.action()
 * });
 */
export function useCommandPalette({
	commands,
	isOpen: initialIsOpen = false,
	onOpen,
	onClose,
	onSelect,
}: UseCommandPaletteOptions) {
	const [state, setState] = useState<CommandPaletteState>({
		isOpen: initialIsOpen,
		commands,
		filter: '',
		selectedIndex: 0,
	});

	// Filter commands based on filter text
	const filteredCommands = useMemo(() => {
		if (!state.filter) return state.commands;

		const lowerFilter = state.filter.toLowerCase();
		return state.commands.filter(
			command =>
				command.label.toLowerCase().includes(lowerFilter) ||
				command.description.toLowerCase().includes(lowerFilter) ||
				command.id.toLowerCase().includes(lowerFilter),
		);
	}, [state.commands, state.filter]);

	// Open command palette
	const openPalette = useCallback(() => {
		setState(prev => ({
			...prev,
			isOpen: true,
			filter: '',
			selectedIndex: 0,
		}));
		onOpen?.();
	}, [onOpen]);

	// Close command palette
	const closePalette = useCallback(() => {
		setState(prev => ({
			...prev,
			isOpen: false,
			filter: '',
			selectedIndex: 0,
		}));
		onClose?.();
	}, [onClose]);

	// Select current command
	const selectCommand = useCallback(() => {
		if (filteredCommands.length > 0) {
			const command = filteredCommands[state.selectedIndex];
			setState(prev => ({
				...prev,
				isOpen: false,
				filter: '',
				selectedIndex: 0,
			}));

			if (command) {
				onSelect?.(command);
			}
		}
	}, [filteredCommands, state.selectedIndex, onSelect]);

	// Navigate commands
	const navigateUp = useCallback(() => {
		setState(prev => ({
			...prev,
			selectedIndex: Math.max(0, prev.selectedIndex - 1),
		}));
	}, []);

	const navigateDown = useCallback(() => {
		setState(prev => ({
			...prev,
			selectedIndex: Math.min(
				filteredCommands.length - 1,
				prev.selectedIndex + 1,
			),
		}));
	}, [filteredCommands.length]);

	// Update filter
	const updateFilter = useCallback((filter: string) => {
		setState(prev => ({
			...prev,
			filter,
			selectedIndex: 0,
		}));
	}, []);

	// Handle keyboard input when palette is open
	useInput(
		(input, key) => {
			if (!state.isOpen) return;

			if (key.escape) {
				closePalette();
				return;
			}

			if (key.return) {
				selectCommand();
				return;
			}

			if (key.upArrow) {
				navigateUp();
				return;
			}

			if (key.downArrow) {
				navigateDown();
				return;
			}

			if (key.backspace || key.delete) {
				updateFilter(state.filter.slice(0, -1));
				return;
			}

			if (input && !key.ctrl && !key.meta) {
				updateFilter(state.filter + input);
			}
		},
		{isActive: state.isOpen},
	);

	return {
		paletteState: state,
		filteredCommands,
		openPalette,
		closePalette,
		selectCommand,
		updateFilter,
		navigateUp,
		navigateDown,
	};
}
