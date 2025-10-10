import React from 'react';
import {Text} from 'ink';

export interface StatusIndicatorProps {
	text: string;
	color: string;
	icon?: string;
	pulse?: boolean;
}

/**
 * StatusIndicator - Generic status display component
 *
 * Displays status text with color and optional icon.
 * Works for loading states, errors, success messages, etc.
 *
 * @example
 * <StatusIndicator text="Loading..." color="yellow" icon="🔄" pulse />
 * <StatusIndicator text="Error" color="red" icon="❌" />
 * <StatusIndicator text="Ready" color="green" icon="✓" />
 */
const StatusIndicator: React.FC<StatusIndicatorProps> = ({
	text,
	color,
	icon,
	pulse,
}) => {
	return (
		<Text color={color}>
			{icon && `${icon} `}
			{text}
			{pulse && ' •'}
		</Text>
	);
};

export default StatusIndicator;
