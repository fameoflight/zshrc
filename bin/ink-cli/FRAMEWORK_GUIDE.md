# Interactive CLI Frameworks Guide

This guide explains how to use the reusable frameworks extracted from the llm-chat command to build interactive CLI applications.

## Overview

The frameworks provide three major reusable components:

1. **Streaming Framework** - Handle any streaming operations with progress tracking
2. **Interactive Terminal Framework** - Build interactive terminal apps with keyboard shortcuts
3. **Command System** - Register and manage commands with execution handling

## Streaming Framework

### Location: `src/frameworks/streaming/`

### Core Components

#### `useAsyncStream<T>()`
Generic hook for handling any streaming operation.

```typescript
import {useAsyncStream} from '../frameworks/streaming/index.js';

const {currentData, isStreaming, handleChunk, cancel, reset} = useAsyncStream({
  batchInterval: 2,
  onComplete: (result) => console.log('Complete:', result),
  onError: (error) => console.error('Error:', error),
  onProgress: (progress) => console.log('Progress:', progress),
});
```

**Features:**
- Batching to reduce UI flicker
- Cancellation with abort controllers
- Progress tracking (0-100%)
- Generic type support (`T` can be string, array, object)
- Error handling and recovery

#### `StreamingContent<T>`
Component optimized for displaying streaming content.

```typescript
import StreamingContent from '../frameworks/streaming/StreamingContent.js';

<StreamingContent
  content={currentData}
  isStreaming={isStreaming}
  prefix="📡"
  textColor="white"
  showCursor={true}
  progress={75}
  renderContent={(data) => <CustomRenderer data={data} />}
/>
```

**Features:**
- Minimal re-renders for smooth streaming
- Configurable prefix and styling
- Progress indicator support
- Custom content rendering
- Cursor indication during streaming

#### `computeStreamStatus()`
Utility for computing status indicators.

```typescript
import {computeStreamStatus} from '../frameworks/streaming/StreamStatus.js';

const status = computeStreamStatus({
  isStreaming: true,
  isCancelling: false,
  isInitialized: true,
  error: null,
  currentData: 'Processing...',
  progress: 45,
}, {
  loadingText: 'Working...',
  cancellingText: 'Stopping...',
});
```

## Interactive Terminal Framework

### Location: `src/frameworks/terminal/`

### Core Components

#### `useInteractiveApp<T>()`
Core app state management.

```typescript
import {useInteractiveApp} from '../frameworks/terminal/index.js';

const {appState, status, info, handleError, exit, isReady} = useInteractiveApp({
  title: 'My App',
  onInitialize: async () => {
    await setupResources();
    return { data: 'ready' };
  },
  onCleanup: async () => {
    await cleanupResources();
  },
});
```

**Features:**
- Initialization state management
- Error handling and recovery
- Application lifecycle management
- Status computation
- Cleanup on exit

#### `useKeyboardShortcuts()`
Generic keyboard shortcut handling.

```typescript
import {useKeyboardShortcuts} from '../frameworks/terminal/index.js';

const {getShortcutsDisplay} = useKeyboardShortcuts({
  shortcuts: [
    { key: 'c', ctrl: true, description: 'Exit', action: () => exit() },
    { key: 'l', ctrl: true, description: 'Clear', action: () => clear() },
    { key: 'escape', description: 'Cancel', action: () => cancel() },
    { key: 'r', shift: true, description: 'Refresh', action: () => refresh() },
  ],
  isActive: !isStreaming,
});
```

**Features:**
- Support for Ctrl, Alt, Shift modifiers
- Special key handling (Escape, arrows, etc.)
- Unknown key handling
- Shortcuts display formatting

#### `useCommandPalette()`
Command discovery and execution system.

```typescript
import {useCommandPalette} from '../frameworks/terminal/index.js';

const {paletteState, openPalette, closePalette} = useCommandPalette({
  commands: [
    { id: 'clear', label: 'Clear', description: 'Clear all data', action: clearData },
    { id: 'refresh', label: 'Refresh', description: 'Refresh data', action: refreshData },
  ],
  onSelect: (command) => {
    command.action();
  },
  triggerKey: '/',
});
```

**Features:**
- Command filtering
- Keyboard navigation
- Auto-trigger on key press
- Command categories support

## Command System

### Location: `src/frameworks/commands/`

### Core Components

#### `CommandRegistry`
Centralized command management.

```typescript
import {CommandRegistry} from '../frameworks/commands/index.js';

const registry = new CommandRegistry({
  caseSensitive: false,
  onCommandExecuted: (command, context) => {
    console.log('Executed:', command.label);
  },
});

registry.register({
  id: 'clear',
  label: 'Clear',
  description: 'Clear all data',
  execute: async (context) => {
    // Command logic here
  },
});
```

**Features:**
- Command registration and discovery
- Execution with error handling
- Command categorization
- Validation and callbacks
- Execution history tracking

#### Command Creation Helpers
Utilities for creating common command types.

```typescript
import {createActionCommand, createValidatedCommand} from '../frameworks/commands/index.js';

// Simple action command
const clearCommand = createActionCommand(
  'clear',
  'Clear',
  'Clear all data',
  async (context) => { /* clear logic */ }
);

// Command with validation
const deleteCommand = createValidatedCommand(
  'delete',
  'Delete',
  'Delete selected item',
  async (context) => { /* delete logic */ },
  (context) => context.selectedItem !== null // validation
);
```

## Building Interactive Commands

### Complete Example: File Monitor

Here's how to combine all frameworks to build an interactive command:

```typescript
import React, {useState} from 'react';
import {useAsyncStream} from '../frameworks/streaming/index.js';
import {useInteractiveApp, useKeyboardShortcuts, useCommandPalette} from '../frameworks/terminal/index.js';
import {createActionCommand} from '../frameworks/commands/index.js';

const FileMonitorCommand = ({flags}) => {
  const [isMonitoring, setIsMonitoring] = useState(false);

  // Initialize app
  const {appState, handleError, exit} = useInteractiveApp({
    title: 'File Monitor',
    onInitialize: async () => ({ directory: flags.directory || '.' }),
  });

  // Setup streaming for file events
  const {currentData, isStreaming, handleChunk, cancel} = useAsyncStream({
    batchInterval: 1,
    onError: handleError,
  });

  // Setup commands
  const commands = [
    createActionCommand('start', 'Start', 'Start monitoring', startMonitoring),
    createActionCommand('stop', 'Stop', 'Stop monitoring', stopMonitoring),
    createActionCommand('clear', 'Clear', 'Clear events', () => reset()),
  ];

  const {openPalette} = useCommandPalette({
    commands,
    onSelect: async (command) => command.execute({}),
  });

  // Setup keyboard shortcuts
  useKeyboardShortcuts({
    shortcuts: [
      { key: 'c', ctrl: true, description: 'Exit', action: exit },
      { key: 'escape', description: 'Stop', action: cancel },
      { key: '/', description: 'Commands', action: openPalette },
    ],
  });

  // Command implementations
  const startMonitoring = () => {
    setIsMonitoring(true);
    // Start monitoring logic...
    handleChunk({ content: '[12:00:00] Started monitoring' });
  };

  const stopMonitoring = () => {
    setIsMonitoring(false);
    cancel();
  };

  return (
    <SplitLayout
      header={<InfoSection title="File Monitor" />}
      footer={<BottomBar status="Monitoring..." />}
    >
      <StreamingContent
        content={currentData}
        isStreaming={isStreaming}
        prefix="📁"
      />
    </SplitLayout>
  );
};
```

## Best Practices

### 1. State Management
- Use `useInteractiveApp` for app-level state
- Keep component state local and focused
- Use streams for data that updates over time

### 2. Error Handling
- Always provide error callbacks to streaming hooks
- Use the centralized error handling from `useInteractiveApp`
- Display clear error messages to users

### 3. Keyboard Shortcuts
- Provide consistent shortcuts across commands (Ctrl+C to exit, Escape to cancel)
- Use descriptive shortcut text in the status bar
- Disable shortcuts when they shouldn't be active

### 4. Performance
- Use appropriate batch intervals (2-5ms for smooth streaming)
- Memoize expensive computations
- Use React.memo for components that re-render frequently

### 5. User Experience
- Provide clear status indicators
- Show progress for long-running operations
- Include help commands and documentation
- Use consistent visual design patterns

## Migration from llm-chat

To migrate existing commands to use the new frameworks:

1. **Replace `useStreamBuffer`** with `useAsyncStream`
2. **Replace manual keyboard handling** with `useKeyboardShortcuts`
3. **Replace command arrays** with `CommandRegistry` and helper functions
4. **Replace app state management** with `useInteractiveApp`
5. **Use `StreamingContent`** instead of custom streaming components

The migration will reduce code duplication and provide consistent behavior across all commands.