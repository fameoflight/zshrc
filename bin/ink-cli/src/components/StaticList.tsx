import React from 'react';
import {Static} from 'ink';

export interface StaticListProps<T> {
	items: T[];
	children: (item: T, index: number) => React.ReactElement;
	emptyState?: React.ReactElement;
}

/**
 * StaticList - Generic list component with Static optimization
 *
 * Renders a list of items using Ink's Static component to prevent
 * re-renders of already rendered items. Perfect for chat histories,
 * logs, todos, or any append-only list.
 *
 * @example
 * <StaticList items={messages}>
 *   {(msg) => <MessageBubble {...msg} />}
 * </StaticList>
 */
function StaticList<T>({
	items,
	children,
	emptyState,
}: StaticListProps<T>): React.ReactElement | null {
	if (items.length === 0) {
		return emptyState || null;
	}

	return <Static items={items}>{(item, index) => children(item, index)}</Static>;
}

export default StaticList;
