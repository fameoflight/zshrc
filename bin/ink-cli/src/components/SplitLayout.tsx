import React from 'react';
import {Box} from 'ink';

export interface SplitLayoutProps {
	header?: React.ReactElement;
	children: React.ReactElement;
	footer?: React.ReactElement;
}

/**
 * SplitLayout - Generic three-section layout component
 *
 * Standard layout pattern with optional header, required body, and optional footer.
 * Header and footer stay fixed while body grows to fill available space.
 *
 * Perfect for commands that need consistent layout structure.
 *
 * @example
 * <SplitLayout
 *   header={<InfoSection title="My App" items={[...]} />}
 *   body={<MessageList messages={messages} />}
 *   footer={<BottomBar status="Ready" />}
 * />
 */
const SplitLayout: React.FC<SplitLayoutProps> = props => {
	const {header, children: body, footer} = props;
	return (
		<Box flexDirection="column" height="100%">
			{header}
			<Box flexDirection="column" flexGrow={1}>
				{body}
			</Box>
			{footer}
		</Box>
	);
};

export default SplitLayout;
