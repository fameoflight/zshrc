import React, {ReactElement} from 'react';
import {Box, Text, Newline} from 'ink';

export interface ToolResult {
	toolName: string;
	result: any;
	error?: string;
	executionTime?: number;
	metadata?: Record<string, any>;
}

export interface ToolResultDisplayProps {
	/** Tool result to display */
	result: ToolResult;
	/** Show execution time */
	showTiming?: boolean;
	/** Show tool name */
	showToolName?: boolean;
	/** Compact display mode */
	compact?: boolean;
	/** Custom result formatter */
	formatResult?: (result: any) => string;
}

/**
 * Component for displaying tool execution results
 *
 * Provides consistent formatting for tool outputs across all interactive commands
 * with support for different result types and error handling.
 */
export function ToolResultDisplay({
	result,
	showTiming = true,
	showToolName = true,
	compact = false,
	formatResult,
}: ToolResultDisplayProps): ReactElement {
	const {toolName, result: data, error, executionTime, metadata} = result;

	// Determine display color based on result
	const color = error ? 'red' : 'green';
	const icon = error ? '❌' : '✅';

	// Format the result data
	const formattedResult = formatResult
		? formatResult(data)
		: formatDefaultResult(data);

	return (
		<Box flexDirection="column" marginBottom={compact ? 0 : 1} paddingX={compact ? 0 : 1}>
			{/* Header with tool name and status */}
			<Box flexDirection="row" marginBottom={compact ? 0 : 1}>
				{showToolName && (
					<Text color="cyan" bold={!compact}>
						{icon} {toolName}
					</Text>
				)}
				{showToolName && showTiming && executionTime && (
					<Text color="gray" dimColor>
						{' '}({executionTime}ms)
					</Text>
				)}
			</Box>

			{/* Error message */}
			{error && (
				<Box marginBottom={compact ? 0 : 1}>
					<Text color="red">
						{error}
					</Text>
				</Box>
			)}

			{/* Result data */}
			{!error && formattedResult && (
				<Box flexDirection="column">
					{formattedResult.split('\n').map((line, index) => (
						<Text key={index} color="white">
							{line}
						</Text>
					))}
				</Box>
			)}

			{/* Metadata */}
			{metadata && Object.keys(metadata).length > 0 && !compact && (
				<Box flexDirection="column" marginTop={1}>
					<Text color="gray" dimColor bold>
						Metadata:
					</Text>
					{Object.entries(metadata).map(([key, value]) => (
						<Text key={key} color="gray" dimColor>
							• {key}: {String(value)}
						</Text>
					))}
				</Box>
			)}
		</Box>
	);
}

/**
 * Default result formatter for common data types
 */
function formatDefaultResult(data: any): string {
	if (data === null || data === undefined) {
		return 'No result';
	}

	if (typeof data === 'string') {
		return data;
	}

	if (typeof data === 'number' || typeof data === 'boolean') {
		return String(data);
	}

	if (Array.isArray(data)) {
		if (data.length === 0) {
			return 'Empty array';
		}
		return data.map((item, index) => `${index + 1}. ${formatDefaultResult(item)}`).join('\n');
	}

	if (typeof data === 'object') {
		const entries = Object.entries(data);
		if (entries.length === 0) {
			return 'Empty object';
		}
		return entries
			.map(([key, value]) => `${key}: ${formatDefaultResult(value)}`)
			.join('\n');
	}

	return String(data);
}

export interface ToolExecutionListProps {
	/** List of tool results */
	results: ToolResult[];
	/** Max results to display */
	maxResults?: number;
	/** Show summary */
	showSummary?: boolean;
	/** Compact mode */
	compact?: boolean;
}

/**
 * Component for displaying a list of tool execution results
 */
export function ToolExecutionList({
	results,
	maxResults = 10,
	showSummary = true,
	compact = false,
}: ToolExecutionListProps): ReactElement {
	const displayResults = results.slice(-maxResults);

	const successfulResults = displayResults.filter(r => !r.error).length;
	const failedResults = displayResults.filter(r => r.error).length;
	const totalExecutionTime = displayResults.reduce((sum, r) => sum + (r.executionTime || 0), 0);

	return (
		<Box flexDirection="column">
			{/* Summary */}
			{showSummary && displayResults.length > 0 && (
				<Box flexDirection="column" marginBottom={1} paddingX={1}>
					<Text color="cyan" bold={!compact}>
						Tool Execution Summary
					</Text>
					<Box flexDirection="row" gap={2}>
						<Text color="green">
							✅ {successfulResults} successful
						</Text>
						{failedResults > 0 && (
							<Text color="red">
								❌ {failedResults} failed
							</Text>
						)}
						{totalExecutionTime > 0 && (
							<Text color="gray">
								⏱️ {totalExecutionTime}ms total
							</Text>
						)}
					</Box>
				</Box>
			)}

			{/* Individual results */}
			{displayResults.map((result, index) => (
				<ToolResultDisplay
					key={`${result.toolName}-${index}`}
					result={result}
					compact={compact}
					showToolName={displayResults.length > 1}
					showTiming={displayResults.length === 1}
				/>
			))}

			{/* More results indicator */}
			{results.length > maxResults && (
				<Box paddingLeft={1} paddingRight={1}>
					<Text color="gray" dimColor>
						... and {results.length - maxResults} more results
					</Text>
				</Box>
			)}
		</Box>
	);
}

export interface ToolStatusProps {
	/** Currently executing tool */
	currentTool?: string;
	/** Is a tool running? */
	isRunning?: boolean;
	/** Queue of pending tools */
	queue?: string[];
	/** Show progress indicator */
	showProgress?: boolean;
}

/**
 * Component for displaying tool execution status
 */
export function ToolStatus({
	currentTool,
	isRunning = false,
	queue = [],
	showProgress = true,
}: ToolStatusProps): ReactElement {
	return (
		<Box flexDirection="row" alignItems="center" gap={1}>
			{isRunning && currentTool && (
				<>
					{showProgress && (
						<Text color="yellow">
							⏳
						</Text>
					)}
					<Text color="yellow">
						Running: {currentTool}
					</Text>
				</>
			)}

			{!isRunning && queue.length > 0 && (
				<Text color="gray">
					Queue: {queue.slice(0, 3).join(', ')}
					{queue.length > 3 && ` +${queue.length - 3} more`}
				</Text>
			)}

			{!isRunning && queue.length === 0 && currentTool && (
				<Text color="green">
					✅ Ready
				</Text>
			)}
		</Box>
	);
}