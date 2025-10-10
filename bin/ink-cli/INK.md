# INK CLI Architecture

## Overview

INK CLI is a modular command-line interface application built with React and Ink, featuring a revolutionary **LLM-enabled interactive command framework**. The system provides a foundation for building interactive CLI applications with reusable React components, plugin-based extensibility, and optional LLM integration.

## 🎯 Architecture Revolution

The architecture has been transformed from simple command-line tools to a **comprehensive interactive platform** that supports:

- **LLM-Enhanced Commands**: Any command can optionally use AI capabilities
- **Plugin System**: Extensible architecture for unlimited customization
- **Interactive UI**: Rich terminal interfaces with real-time streaming
- **Agent Framework**: Autonomous agents that use tools to achieve goals
- **Tool Calling**: Future-ready for when LLMs can call tools directly

## Core Architecture

### Service Injection Framework

**Dependency Injection Container** (`src/services/ServiceProvider.ts`)
- Centralized service registration and resolution
- Singleton and factory patterns
- Type-safe service access

**LLM Provider Interface** (`src/services/LLMProvider.ts`)
- Injectable LLM services (OpenAI, LM Studio, Ollama, Custom)
- Streaming chat with tool support
- Graceful degradation with NoOp provider

**Tool Registry** (`src/services/ToolRegistry.ts`)
- Central tool registration and discovery
- Type-safe tool execution
- Category-based organization

**Context Manager** (`src/services/ContextManager.ts`)
- Shared conversation state
- Session management
- Cross-command communication

### Interactive Command Foundation

**BaseInteractiveCommand** (`src/frameworks/interactive/BaseInteractiveCommand.ts`)
- Abstract base class for all interactive commands
- Plugin system for composable behavior
- Built-in state management and streaming
- React lifecycle management

**Command Processor** (`src/frameworks/interactive/CommandProcessor.ts`)
- Unified command processing pipeline
- Middleware support for custom behavior
- Type-safe command handling

**Streaming Manager** (`src/frameworks/interactive/StreamingManager.ts`)
- Real-time response streaming
- Batch processing and buffering
- Cancellation support

### Plugin System

The architecture includes a powerful plugin system that enables composable behavior:

**Core Plugins:**
- **ChatPlugin** (`src/plugins/ChatPlugin.ts`) - Conversational behavior with message history
- **LLMPlugin** (`src/plugins/LLMPlugin.ts`) - LLM integration with configuration commands
- **ConfigPlugin** (`src/plugins/ConfigPlugin.ts`) - Persistent configuration management
- **ToolPlugin** (`src/plugins/ToolPlugin.ts`) - Tool registration and execution

**Advanced Plugins:**
- **AgentPlugin** (`src/plugins/AgentPlugin.ts`) - Autonomous agent management
- **ToolCallingPlugin** (`src/plugins/ToolCallingPlugin.ts`) - LLM tool integration

### Interactive UI Library

**Layout Components** (`src/components/interactive/`)
- `InteractiveLayout` - Standard layout with header/content/footer
- `InteractiveHeader` - Configurable header with info items
- `InteractiveFooter` - Status bar with shortcuts

**Input Components**
- `CommandInput` - Enhanced input with autocomplete, history, shortcuts
- Auto-completion with Tab completion
- Command history navigation

**Display Components**
- `MessageDisplay` - Streaming message display with formatting
- `ToolResultDisplay` - Tool execution result visualization
- Welcome, error, and loading components

## Module Structure

```
src/
├── services/                    # Service injection layer
│   ├── LLMProvider.ts           # LLM service interface
│   ├── ServiceProvider.ts        # Dependency injection
│   ├── ToolRegistry.ts          # Tool management
│   ├── ContextManager.ts        # State management
│   └── adapters/                 # Legacy compatibility
├── frameworks/                  # Core frameworks
│   ├── interactive/            # Interactive command foundation
│   │   ├── BaseInteractiveCommand.ts
│   │   ├── CommandProcessor.ts
│   │   └── StreamingManager.ts
│   └── agents/                  # Agent framework
│       └── AgentSystem.ts
├── plugins/                     # Plugin system
│   ├── ChatPlugin.ts
│   ├── LLMPlugin.ts
│   ├── ConfigPlugin.ts
│   ├── ToolPlugin.ts
│   ├── AgentPlugin.ts
│   └── ToolCallingPlugin.ts
├── components/interactive/     # Interactive UI library
│   ├── InteractiveLayout.tsx
│   ├── CommandInput.tsx
│   ├── MessageDisplay.tsx
│   └── ToolResultDisplay.tsx
├── common/                     # Shared utilities
│   ├── hooks/                  # React hooks
│   │   ├── useLLMService.ts    # LLM service hook
│   │   └── useConfig.ts        # Configuration hook
│   ├── llm/                    # LLM implementation
│   └── types/                  # Type definitions
└── commands/                   # Command implementations
    ├── llm-chat.tsx           # Refactored LLM chat command
    └── add.tsx                # Simple add command
```

## 🚀 Creating Interactive Commands

### Basic Interactive Command

```tsx
import React from 'react';
import {BaseInteractiveCommand, BaseInteractiveState} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {InteractiveLayout, InteractiveHeader, InteractiveFooter} from '../components/interactive/InteractiveLayout.js';
import {createChatPlugin} from '../plugins/ChatPlugin.js';
import {createLLMPlugin} from '../plugins/LLMPlugin.js';

interface MyCommandState extends BaseInteractiveState {
  customProperty: string;
}

class MyCommand extends BaseInteractiveCommand<MyCommandState> {
  name() { return 'my-command'; }
  description() { return 'My interactive command'; }

  config() {
    return {
      name: this.name(),
      description: this.description(),
      flags: {
        // Define flags here
      },
    };
  }

  help() {
    return {
      description: 'Interactive command with LLM support',
      usage: 'my-command [options]',
      examples: ['my-command'],
      notes: ['Uses plugin-based architecture'],
    };
  }

  createInitialState(): MyCommandState {
    return {
      ...super.createInitialState(),
      customProperty: 'default',
    };
  }

  async initializeServices(): Promise<void> {
    // Add plugins for desired functionality
    this.addPlugin(createChatPlugin());
    this.addPlugin(createLLMPlugin());

    await super.initializeServices();
  }

  renderInteractiveUI(state: MyCommandState): React.ReactElement {
    return (
      <InteractiveLayout
        header={
          <InteractiveHeader
            title="My Command"
            titleIcon="⚡"
            infoItems={[
              {label: 'Property', value: state.customProperty},
            ]}
          />
        }
        footer={
          <InteractiveFooter
            status="Ready"
            info={`${state.messages.length} messages`}
          />
        }
      >
        {/* Content rendered by plugins */}
        {this.renderPluginComponents()}
      </InteractiveLayout>
    );
  }
}

export default MyCommand;
```

### LLM-Enhanced Tool Command

```tsx
import {createToolPlugin} from '../plugins/ToolPlugin.js';
import {createLLMPlugin} from '../plugins/LLMPlugin.js';
import {createToolCallingPlugin} from '../plugins/ToolCallingPlugin.js';

// In initializeServices():
async initializeServices(): Promise<void> {
  // Add tool plugin for tool operations
  this.addPlugin(createToolPlugin({
    tools: [
      {
        name: 'search',
        description: 'Search for files',
        parameters: {
          type: 'object',
          properties: {
            query: {type: 'string'},
            path: {type: 'string'},
          },
        },
        execute: async (params) => {
          // Tool implementation
          return {results: []};
        },
      },
    ],
  }));

  // Add LLM plugin for AI enhancement
  this.addPlugin(createLLMPlugin());

  // Add tool calling plugin for future LLM tool integration
  this.addPlugin(createToolCallingPlugin());
}
```

## 🤖 Agent Framework

The architecture includes a complete agent framework for autonomous operations:

```tsx
import {AgentPlugin} from '../plugins/AgentPlugin.js';

// In initializeServices():
async initializeServices(): Promise<void> {
  this.addPlugin(createAgentPlugin({
    autoStart: true,
    defaultGoal: 'Help the user with their tasks',
    enableToolCalling: true,
  }));
}
```

## 🔧 Configuration Management

Commands have built-in persistent configuration:

```tsx
import {createConfigPlugin} from '../plugins/ConfigPlugin.js';

interface MyConfig {
  setting1: string;
  setting2: number;
}

// In initializeServices():
async initializeServices(): Promise<void> {
  this.addPlugin(createConfigPlugin<MyConfig>({
    schema: {
      defaults: {
        setting1: 'default',
        setting2: 42,
      },
      validation: {
        setting2: (value) => value > 0 ? true : 'Must be positive',
      },
    },
    namespace: 'my-command',
  }));
}
```

## 🎨 Plugin Development

Create custom plugins by implementing the Plugin interface:

```tsx
import {Plugin, BaseInteractiveCommand} from '../frameworks/interactive/BaseInteractiveCommand.js';

export class MyPlugin implements Plugin {
  name = 'my-plugin';

  async initialize(command: BaseInteractiveCommand): Promise<void> {
    // Initialize plugin
  }

  async onMessage(message: string): Promise<boolean> {
    // Handle specific messages
    if (message.startsWith('/my-command')) {
      // Handle command
      return true;
    }
    return false;
  }

  renderComponents(): React.ReactElement[] {
    // Return UI components
    return [];
  }
}
```

## 🚀 Architecture Benefits

### For Developers
- **Rapid Development**: New commands ~50-100 lines vs 600+ lines
- **Type Safety**: Full TypeScript support with proper interfaces
- **Consistency**: Shared patterns and behaviors across all commands
- **Reusability**: Plugin system for unlimited customization
- **Testing**: Modular design makes testing straightforward

### For Users
- **Rich Interactions**: Autocomplete, history, streaming responses
- **AI Enhancement**: Optional LLM capabilities in any command
- **Consistency**: Unified experience across all commands
- **Extensibility**: Commands can be enhanced with plugins

### For Future Growth
- **Tool Calling**: Ready for when LLMs can call tools directly
- **Agents**: Autonomous agents that use tools to achieve goals
- **Scalability**: Supports 1000+ commands with shared infrastructure
- **Performance**: Optimized for real-time streaming and large datasets

## Migration Guide

### From Simple Commands to Interactive Commands

1. **Extend BaseInteractiveCommand** instead of implementing Command
2. **Add plugins** for desired functionality (chat, LLM, tools, etc.)
3. **Use renderInteractiveUI()** with interactive components
4. **Leverage built-in state management** and streaming

### Backward Compatibility

The architecture maintains full backward compatibility:
- Existing simple commands continue to work
- Gradual migration path to interactive commands
- Shared components can be used in both approaches

The new architecture transforms INK CLI from a collection of command-line tools into a powerful, extensible platform for building next-generation interactive CLI applications with AI capabilities.