import {useCallback, useMemo} from 'react';
import {useInput} from 'ink';
import {KeyboardShortcut} from './types.js';

export interface UseKeyboardShortcutsOptions {
	shortcuts: KeyboardShortcut[];
	isActive?: boolean;
	onUnknownKey?: (input: string, key: any) => void;
}

/**
 * useKeyboardShortcuts - Generic keyboard shortcut management
 *
 * Handles keyboard shortcuts with support for modifiers (Ctrl, Alt, Shift).
 * Provides consistent behavior across interactive applications.
 *
 * @example
 * const shortcuts = [
 *   { key: 'c', ctrl: true, description: 'Exit', action: () => exit() },
 *   { key: 'l', ctrl: true, description: 'Clear', action: () => clear() },
 *   { key: 'escape', description: 'Cancel', action: () => cancel() }
 * ];
 *
 * useKeyboardShortcuts({ shortcuts, isActive: !isStreaming });
 */
export function useKeyboardShortcuts({
	shortcuts,
	isActive = true,
	onUnknownKey,
}: UseKeyboardShortcutsOptions) {
	// Create shortcut map for efficient lookup
	const shortcutMap = useMemo(() => {
		const map = new Map<string, KeyboardShortcut>();

		shortcuts.forEach(shortcut => {
			const key = createShortcutKey(shortcut);
			map.set(key, shortcut);
		});

		return map;
	}, [shortcuts]);

	// Create standardized key identifier
	const createShortcutKey = useCallback((shortcut: KeyboardShortcut): string => {
		const parts: string[] = [];

		if (shortcut.ctrl) parts.push('ctrl');
		if (shortcut.alt) parts.push('alt');
		if (shortcut.shift) parts.push('shift');
		if (shortcut.key.length > 1) {
			parts.push(shortcut.key.toLowerCase());
		} else {
			parts.push(shortcut.key);
		}

		return parts.join('+');
	}, []);

	// Handle keyboard input
	const handleInput = useCallback(
		(input: string, key: any) => {
			if (!isActive) return;

			// Create key identifier for current input
			const parts: string[] = [];

			if (key.ctrl) parts.push('ctrl');
			if (key.alt) parts.push('alt');
			if (key.shift) parts.push('shift');

			let keyName = '';
			if (key.escape) keyName = 'escape';
			else if (key.return) keyName = 'return';
			else if (key.backspace || key.delete) keyName = 'backspace';
			else if (key.tab) keyName = 'tab';
			else if (key.space) keyName = 'space';
			else if (key.upArrow) keyName = 'up';
			else if (key.downArrow) keyName = 'down';
			else if (key.leftArrow) keyName = 'left';
			else if (key.rightArrow) keyName = 'right';
			else if (input) keyName = input.toLowerCase();

			if (keyName) parts.push(keyName);

			const shortcutKey = parts.join('+');

			// Find matching shortcut
			const shortcut = shortcutMap.get(shortcutKey);
			if (shortcut) {
				shortcut.action();
			} else if (onUnknownKey && input) {
				onUnknownKey(input, key);
			}
		},
		[isActive, shortcutMap, onUnknownKey],
	);

	// Setup input handler
	useInput(handleInput, { isActive });

	// Get shortcuts display text
	const getShortcutsDisplay = useCallback((activeOnly = true): string[] => {
		return shortcuts
			.filter(shortcut => !activeOnly || !shortcut.ctrl || shortcut.key !== 'c')
			.map(shortcut => {
				const parts: string[] = [];

				if (shortcut.ctrl) parts.push('Ctrl');
				if (shortcut.alt) parts.push('Alt');
				if (shortcut.shift) parts.push('Shift');

				let keyName = shortcut.key;
				if (shortcut.key === 'escape') keyName = 'Esc';
				else if (shortcut.key === 'return') keyName = 'Enter';
				else if (shortcut.key === 'backspace') keyName = 'Backspace';
				else if (shortcut.key === 'tab') keyName = 'Tab';
				else if (shortcut.key === 'space') keyName = 'Space';
				else if (shortcut.key === 'up') keyName = '↑';
				else if (shortcut.key === 'down') keyName = '↓';
				else if (shortcut.key === 'left') keyName = '←';
				else if (shortcut.key === 'right') keyName = '→';

				parts.push(keyName);

				return `${parts.join('+')}=${shortcut.description}`;
			});
	}, [shortcuts]);

	return {
		shortcuts,
		getShortcutsDisplay,
	};
}