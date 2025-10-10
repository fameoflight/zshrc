/**
 * Interactive terminal framework types
 */

export interface KeyboardShortcut {
	key: string;
	ctrl?: boolean;
	alt?: boolean;
	shift?: boolean;
	description: string;
	action: () => void;
}

export interface InteractiveAppState {
	isInitialized: boolean;
	error: string | null;
	isActive: boolean;
	currentInput: string;
}

export interface InteractiveAppOptions {
	title?: string;
	onInitialize?: () => Promise<void>;
	onCleanup?: () => void;
	enableKeyboardShortcuts?: boolean;
	exitOnCtrlC?: boolean;
}

export interface Command {
	id: string;
	label: string;
	description: string;
	action: (context?: any) => void | Promise<void>;
	category?: string;
	keybinding?: string;
}

export interface CommandPaletteState {
	isOpen: boolean;
	commands: Command[];
	filter: string;
	selectedIndex: number;
}

export interface TerminalStatusConfig {
	ready: { text: string; color: string; icon: string };
	loading: { text: string; color: string; icon: string };
	error: { text: string; color: string; icon: string };
	typing: { text: string; color: string; icon: string };
}