import React, {ReactElement, ReactNode} from 'react';
import {Box, Text} from 'ink';

export interface InteractiveLayoutProps {
	/** Header content (configurable by command) */
	header?: ReactElement;
	/** Main content area */
	children: ReactNode;
	/** Footer content (status bar, shortcuts, etc.) */
	footer?: ReactElement;
	/** Show border around content area */
	border?: boolean;
	/** Layout direction */
	direction?: 'column' | 'row';
	/** Flex grow for content area */
	contentGrow?: boolean;
	/** Padding for content area */
	padding?: number;
	/** Minimum height for the layout */
	minHeight?: number;
}

/**
 * Standard layout component for all interactive commands
 *
 * Provides consistent structure with header, content, and footer areas.
 * Commands can customize each section while maintaining consistent behavior.
 */
export function InteractiveLayout({
	header,
	children,
	footer,
	border = true,
	direction = 'column',
	contentGrow = true,
	padding = 1,
	minHeight,
}: InteractiveLayoutProps): ReactElement {
	// Calculate content flex value
	const contentFlex = contentGrow ? 1 : 0;

	return (
		<Box flexDirection="column" height={minHeight}>
			{/* Header Section */}
			{header && (
				<Box flexDirection="column">
					{header}
					{/* Separator */}
					<Box width="100%">
						<Text color="gray">{'─'.repeat(process.stdout.columns || 80)}</Text>
					</Box>
				</Box>
			)}

			{/* Main Content Area */}
			<Box
				flexDirection={direction}
				flexGrow={contentFlex}
				paddingX={padding}
				paddingY={border ? 0 : padding}
				borderStyle={border ? 'single' : undefined}
				borderColor={border ? 'gray' : undefined}
			>
				{children}
			</Box>

			{/* Footer Section */}
			{footer && (
				<Box flexDirection="column">
					{/* Separator */}
					<Box width="100%">
						<Text color="gray">{'─'.repeat(process.stdout.columns || 80)}</Text>
					</Box>
					{footer}
				</Box>
			)}
		</Box>
	);
}

export interface InteractiveHeaderProps {
	/** Title of the command */
	title: string;
	/** Title color */
	titleColor?: string;
	/** Icon to show next to title */
	titleIcon?: string;
	/** Additional info items to display */
	infoItems?: Array<{
		label: string;
		value: string;
		valueColor?: string;
		icon?: string;
	}>;
	/** Layout direction for header */
	direction?: 'row' | 'column';
}

/**
 * Standard header component for interactive commands
 */
export function InteractiveHeader({
	title,
	titleColor = 'blue',
	titleIcon,
	infoItems = [],
	direction = 'row',
}: InteractiveHeaderProps): ReactElement {
	return (
		<Box flexDirection="column" paddingX={1}>
			{/* Title Row */}
			<Box flexDirection="row" marginBottom={infoItems.length > 0 ? 1 : 0}>
				{titleIcon && <Text color={titleColor}>{titleIcon} </Text>}
				<Text color={titleColor} bold>
					{title}
				</Text>
			</Box>

			{/* Info Items */}
			{infoItems.length > 0 && (
				<Box
					flexDirection={direction}
					flexWrap="wrap"
					gap={direction === 'row' ? 2 : 1}
				>
					{infoItems.map((item, index) => (
						<Box key={index} flexDirection="row">
							{item.icon && <Text>{item.icon} </Text>}
							<Text color="gray" dimColor>
								{item.label}:
							</Text>
							<Text color={item.valueColor || 'white'}>
								{' '}
								{item.value}
							</Text>
						</Box>
					))}
				</Box>
			)}
		</Box>
	);
}

export interface InteractiveFooterProps {
	/** Status message */
	status?: string;
	/** Status color */
	statusColor?: string;
	/** Info text (usually command count, provider info, etc.) */
	info?: string;
	/** Shortcuts to display */
	shortcuts?: Record<string, string>;
	/** Show border */
	border?: boolean;
	/** Layout direction */
	direction?: 'row' | 'column';
}

/**
 * Standard footer component for interactive commands
 */
export function InteractiveFooter({
	status,
	statusColor = 'green',
	info,
	shortcuts = {},
	border = true,
	direction = 'row',
}: InteractiveFooterProps): ReactElement {
	const hasShortcuts = Object.keys(shortcuts).length > 0;

	return (
		<Box
			flexDirection="column"
			paddingX={1}
			borderTop={border}
			borderColor="gray"
		>
			{/* Status and Info Row */}
			<Box flexDirection="row" justifyContent="space-between">
				<Box flexDirection="row">
					{status && (
						<Text color={statusColor}>
							● {status}
						</Text>
					)}
					{status && info && (
						<Text color="gray"> | </Text>
					)}
					{info && (
						<Text color="gray">{info}</Text>
					)}
				</Box>

				{hasShortcuts && (
					<Box flexDirection="row" justifyContent="flex-end">
						<Text color="cyan" dimColor>
							{Object.entries(shortcuts)
								.slice(0, 3) // Limit to 3 shortcuts to avoid crowding
								.map(([key, desc]) => `${key}=${desc}`)
								.join(' ')}
						</Text>
					</Box>
				)}
			</Box>

			{/* Full shortcuts list (shown if there are more than 3) */}
			{hasShortcuts && Object.keys(shortcuts).length > 3 && (
				<Box flexDirection="row" justifyContent="center">
					<Text color="gray" dimColor>
						Shortcuts: {Object.entries(shortcuts)
							.map(([key, desc]) => `${key}=${desc}`)
							.join(', ')}
					</Text>
				</Box>
			)}
		</Box>
	);
}