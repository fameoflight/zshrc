import React from 'react';
import {Box, Text, Static} from 'ink';

export interface InfoItem {
	label: string;
	value: string;
	icon?: string;
	labelColor?: string;
	valueColor?: string;
}

export interface InfoSectionProps {
	title: string;
	titleIcon?: string;
	titleColor?: string;
	items: InfoItem[];
	static?: boolean;
}

/**
 * InfoRow - Single info key-value display
 */
const InfoRow: React.FC<InfoItem> = ({
	label,
	value,
	icon,
	labelColor = 'white',
	valueColor = 'gray',
}) => {
	return (
		<Text>
			{icon && `${icon} `}
			<Text color={labelColor}>{label}:</Text> <Text color={valueColor}>{value}</Text>
		</Text>
	);
};

/**
 * InfoSection - Generic header/info display component
 *
 * Displays a title and list of key-value pairs.
 * Perfect for showing configuration, status, or any structured info.
 *
 * @example
 * <InfoSection
 *   title="LLM Chat"
 *   titleIcon="🤖"
 *   items={[
 *     { label: 'Provider', value: 'LM Studio' },
 *     { label: 'Model', value: 'qwen3-80b', icon: '🧠' }
 *   ]}
 * />
 */
const InfoSection: React.FC<InfoSectionProps> = ({
	title,
	titleIcon,
	titleColor = 'blue',
	items,
	static: useStatic = true,
}) => {
	if (useStatic) {
		return (
			<Static items={items}>
				{(item, index) => (
					<Box flexDirection="column" key={`${item.label}-${index}`}>
						{index === 0 && (
							<Text color={titleColor} bold>
								{titleIcon && `${titleIcon} `}
								{title}
							</Text>
						)}
						<InfoRow {...item} />
						{index === items.length - 1 && <Text>{''}</Text>}
					</Box>
				)}
			</Static>
		);
	}

	return (
		<Box flexDirection="column">
			<Text color={titleColor} bold>
				{titleIcon && `${titleIcon} `}
				{title}
			</Text>
			{items.map((item, index) => (
				<InfoRow key={`${item.label}-${index}`} {...item} />
			))}
			<Text>{''}</Text>
		</Box>
	);
};

export default InfoSection;
