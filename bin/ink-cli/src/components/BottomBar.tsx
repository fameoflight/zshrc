import React from 'react';
import {Box, Text} from 'ink';

export interface BottomBarProps {
	/** Status message to display on the left */
	status?: string;
	/** Additional info to display in the center */
	info?: string;
	/** Keyboard shortcuts or help text to display on the right */
	shortcuts?: string[];
	/** Custom color for the status message */
	statusColor?: string;
	/** Custom color for the info message */
	infoColor?: string;
	/** Custom color for shortcuts */
	shortcutsColor?: string;
	/** Whether to show a border above the bar */
	border?: boolean;
}

const BottomBar: React.FC<BottomBarProps> = ({
	status = 'Ready',
	info,
	shortcuts = ['Enter=send', 'Ctrl+L=clear', 'Ctrl+C=exit'],
	statusColor = 'green',
	infoColor = 'blue',
	shortcutsColor = 'gray',
	border = true,
}) => {
	// Format shortcuts for display
	const formatShortcuts = () => {
		return shortcuts.join(' | ');
	};

	// Build the bar content
	const buildContent = () => {
		const parts: React.ReactElement[] = [];

		// Status section (left)
		if (status) {
			parts.push(
				<Text key="status" color={statusColor} bold>
					{status}
				</Text>,
			);
		}

		// Info section (center)
		if (info) {
			if (parts.length > 0) {
				parts.push(<Text key="separator-1" color="dim"> | </Text>);
			}
			parts.push(<Text key="info" color={infoColor}>{info}</Text>);
		}

		// Shortcuts section (right)
		if (shortcuts && shortcuts.length > 0) {
			if (parts.length > 0) {
				parts.push(<Text key="separator-2" color="dim"> | </Text>);
			}
			parts.push(<Text key="shortcuts" color={shortcutsColor}>{formatShortcuts()}</Text>);
		}

		return parts;
	};

	const content = buildContent();

	return (
		<Box flexDirection="column">
			{border && (
				<Box width="100%">
					<Text color="gray">{"─".repeat(process.stdout.columns || 80)}</Text>
				</Box>
			)}
			<Box justifyContent="space-between" alignItems="center" paddingX={1}>
				<Box flexGrow={0}>{content}</Box>
			</Box>
		</Box>
	);
};

export default BottomBar;
