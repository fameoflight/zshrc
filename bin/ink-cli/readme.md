# INK CLI Interactive Command Framework

A comprehensive framework for building interactive command-line interfaces with optional LLM integration. Transform complex CLI tools into intuitive, conversational experiences.

## 🚀 Quick Start

### Creating Your First Interactive Command

1. **Create a new command file** in `src/commands/`:

```typescript
// src/commands/my-command.tsx
import React, {ReactElement} from 'react';
import {BaseInteractiveCommand, BaseInteractiveState} from '../frameworks/interactive/BaseInteractiveCommand.js';
import {Command, CommandConfig, CommandFlags, CommandHelp} from '../base/command.js';
import {createChatPlugin} from '../plugins/ChatPlugin.js';
import {InteractiveLayout, InteractiveHeader, InteractiveFooter} from '../components/interactive/InteractiveLayout.js';

interface MyCommandState extends BaseInteractiveState {
	customData?: string;
}

class MyCommand extends BaseInteractiveCommand<MyCommandState> implements Command {
	name(): string {
		return 'my-command';
	}

	description(): string {
		return 'My awesome interactive command';
	}

	config(): CommandConfig {
		return {
			name: this.name(),
			description: this.description(),
			flags: {
				option: {
					type: 'string',
					description: 'A custom option',
					default: 'default-value',
				},
			},
		};
	}

	help(): CommandHelp {
		return {
			description: 'This is my awesome command',
			usage: 'my-command [OPTIONS]',
			examples: ['my-command', 'my-command --option=value'],
		};
	}

	createInitialState(): MyCommandState {
		return {
			...super.createInitialState(),
			customData: 'initial-value',
		};
	}

	async initializeServices(): Promise<void> {
		// Add plugins for desired functionality
		this.addPlugin(createChatPlugin());

		// Initialize parent services
		await super.initializeServices();
	}

	renderInteractiveUI(state: MyCommandState, flags: CommandFlags): ReactElement {
		return (
			<InteractiveLayout
				header={
					<InteractiveHeader
						title="My Awesome Command"
						titleIcon="⭐"
						infoItems={[
							{
								label: 'Custom Data',
								value: state.customData || 'not set',
								valueColor: 'cyan',
							},
						]}
					/>
				}
				footer={
					<InteractiveFooter
						status="Ready"
						info={`${state.messages.length} messages`}
						shortcuts={{
							'Ctrl+C': 'Quit',
							'/?': 'Help',
						}}
					/>
				}
			>
				{/* Content is rendered by plugins */}
				{this.renderPluginComponents()}
			</InteractiveLayout>
		);
	}
}

export default MyCommand;
```

2. **Register your command** in `src/commands/index.ts`:

```typescript
// Add to your imports
import MyCommand from './my-command.js';

// Add to the commands array
export const commands = [
	// ... existing commands
	MyCommand,
];
```

3. **Build and run**:

```bash
yarn build
ink-cli my-command
```

## 🏗️ Architecture Overview

### Core Components

#### Service Layer
- **LLMProvider**: Injectable LLM service interface
- **ServiceProvider**: Dependency injection container
- **ToolRegistry**: Tool registration and execution
- **ContextManager**: Shared state and conversation history

#### Foundation Layer
- **BaseInteractiveCommand**: Abstract base class for all interactive commands
- **CommandProcessor**: Unified command processing with middleware
- **StreamingManager**: Real-time response handling
- **Plugin Interface**: Extensible behavior system

#### UI Components
- **InteractiveLayout**: Standard layout structure
- **CommandInput**: Enhanced input with autocomplete and history
- **MessageDisplay**: Streaming message rendering
- **ToolResultDisplay**: Tool execution output formatting

#### Plugin System
- **ChatPlugin**: Conversational behavior
- **LLMPlugin**: LLM integration and configuration
- **ConfigPlugin**: Persistent configuration management
- **ToolPlugin**: Tool registration and execution
- **AgentPlugin**: Autonomous agent management
- **ToolCallingPlugin**: LLM tool calling preparation

## 🔌 Plugin System

Plugins add specific capabilities to your commands. Mix and match based on your needs:

### Basic Chat Command
```typescript
this.addPlugin(createChatPlugin());
```

### LLM-Enhanced Command
```typescript
this.addPlugin(createChatPlugin());
this.addPlugin(createLLMPlugin({
  systemPrompt: "You are a helpful assistant for my command",
  temperature: 0.7,
}));
```

### Tool-Enabled Command
```typescript
this.addPlugin(createToolPlugin({
  tools: [
    {
      name: 'search-files',
      description: 'Search for files matching a pattern',
      parameters: {
        type: 'object',
        properties: {
          pattern: { type: 'string', description: 'Search pattern' }
        }
      },
      execute: async (params) => {
        // Your tool logic here
        return { files: ['file1.txt', 'file2.txt'] };
      }
    }
  ]
}));
```

### Configuration Management
```typescript
this.addPlugin(createConfigPlugin({
  schema: {
    defaults: {
      theme: 'dark',
      maxResults: 10,
    },
    validation: {
      maxResults: (value) => value > 0 || 'Must be positive',
    }
  },
  namespace: 'my-command'
}));
```

### Autonomous Agent
```typescript
this.addPlugin(createAgentPlugin({
  autoStart: true,
  defaultGoal: "Help the user accomplish their task efficiently",
  enableToolCalling: true,
}));
```

## 🛠️ Advanced Examples

### LLM-Enhanced File Browser

```typescript
import { createLLMPlugin, createToolPlugin, createChatPlugin } from '../plugins/index.js';

class FileBrowserCommand extends BaseInteractiveCommand<FileBrowserState> {
  createInitialState(): FileBrowserState {
    return {
      ...super.createInitialState(),
      currentDirectory: process.cwd(),
      selectedFiles: [],
    };
  }

  async initializeServices(): Promise<void> {
    // File search tool
    this.addPlugin(createToolPlugin({
      tools: [
        {
          name: 'search-files',
          description: 'Search files using semantic or pattern matching',
          parameters: {
            type: 'object',
            properties: {
              query: { type: 'string' },
              directory: { type: 'string' }
            }
          },
          execute: async (params) => {
            // Implementation that can use LLM for semantic search
            return await this.searchFiles(params.query, params.directory);
          }
        }
      ]
    }));

    // LLM integration for intelligent file operations
    this.addPlugin(createLLMPlugin({
      systemPrompt: "You are a helpful file system assistant. You can search, read, and help organize files.",
    }));

    // Chat interface
    this.addPlugin(createChatPlugin());

    await super.initializeServices();
  }
}
```

### Database Manager with Query Generation

```typescript
class DatabaseManagerCommand extends BaseInteractiveCommand<DBState> {
  async initializeServices(): Promise<void> {
    this.addPlugin(createToolPlugin({
      tools: [
        {
          name: 'execute-query',
          description: 'Execute SQL query on database',
          parameters: {
            type: 'object',
            properties: {
              query: { type: 'string' },
              database: { type: 'string' }
            }
          },
          execute: async (params) => {
            return await this.executeQuery(params.query, params.database);
          }
        }
      ]
    }));

    this.addPlugin(createLLMPlugin({
      systemPrompt: "You are a database assistant. Convert natural language to SQL and execute queries.",
    }));

    this.addPlugin(createChatPlugin());

    await super.initializeServices();
  }
}
```

### Git Helper with Smart Commit Messages

```typescript
class GitHelperCommand extends BaseInteractiveCommand<GitState> {
  async initializeServices(): Promise<void> {
    this.addPlugin(createToolPlugin({
      tools: [
        {
          name: 'git-status',
          description: 'Get git repository status',
          execute: async () => await this.getGitStatus()
        },
        {
          name: 'git-diff',
          description: 'Get git diff for staged changes',
          execute: async () => await this.getGitDiff()
        },
        {
          name: 'git-commit',
          description: 'Create commit with message',
          parameters: {
            type: 'object',
            properties: {
              message: { type: 'string' }
            }
          },
          execute: async (params) => await this.createCommit(params.message)
        }
      ]
    }));

    this.addPlugin(createLLMPlugin({
      systemPrompt: "You are a Git assistant. Help users with version control, generate commit messages, and manage branches.",
    }));

    this.addPlugin(createChatPlugin());

    await super.initializeServices();
  }
}
```

## ⚙️ Configuration

### TypeScript Configuration

To ignore "is declared but its value is never read" warnings, add this to your `tsconfig.json`:

```json
{
  "compilerOptions": {
    "noUnusedLocals": false,
    "noUnusedParameters": false
  }
}
```

Or use inline comments for specific cases:

```typescript
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const unusedVariable = 'value';
```

### Environment Setup

The framework automatically integrates with your existing LLM setup through the service container:

```typescript
// LLM provider is automatically available to plugins
const llmProvider = serviceContainer.resolve<LLMProvider>('llm-provider');
```

## 🧪 Testing

### Testing Your Commands

```typescript
import { render } from '@testing-library/react';
import MyCommand from './my-command';

describe('MyCommand', () => {
  it('should render correctly', () => {
    const command = new MyCommand();
    const { getByText } = render(
      command.renderInteractiveUI(command.createInitialState(), {})
    );

    expect(getByText('My Awesome Command')).toBeInTheDocument();
  });
});
```

### Testing Plugins

```typescript
import { createChatPlugin } from '../plugins/ChatPlugin';

describe('ChatPlugin', () => {
  it('should handle chat commands', async () => {
    const plugin = createChatPlugin();
    const mockCommand = {
      addMessage: jest.fn(),
      getState: jest.fn(() => ({ messages: [] })),
    };

    await plugin.initialize(mockCommand);

    const handled = await plugin.onMessage('/help');
    expect(handled).toBe(true);
    expect(mockCommand.addMessage).toHaveBeenCalled();
  });
});
```

## 📚 API Reference

### BaseInteractiveCommand

The main class to extend for creating interactive commands:

```typescript
abstract class BaseInteractiveCommand<TState extends BaseInteractiveState> {
  // Abstract methods to implement
  abstract name(): string;
  abstract description(): string;
  abstract config(): CommandConfig;
  abstract help(): CommandHelp;
  abstract createInitialState(): TState;
  abstract renderInteractiveUI(state: TState, flags: CommandFlags): ReactElement;

  // Optional methods to override
  protected async initializeServices(): Promise<void>
  protected async processUserMessage(message: string): Promise<void>
  protected async handleCustomCommand(command: string): Promise<void>

  // Plugin management
  addPlugin(plugin: Plugin): void
  removePlugin(pluginName: string): void
  getPlugin(pluginName: string): Plugin | undefined

  // State management
  protected updateState(updates: Partial<TState>): void
  protected getState(): TState

  // Message handling
  protected async addMessage(role: string, content: string): Promise<string>
  protected clearMessages(): void
}
```

### Plugin Interface

```typescript
interface Plugin {
  name: string;
  initialize?(command: BaseInteractiveCommand): Promise<void>;
  cleanup?(): Promise<void>;
  onMessage?(message: string): Promise<boolean>;
  onStateChange?(state: any): void;
  renderComponents?(): ReactElement[];
}
```

## 🚀 Best Practices

1. **Start Simple**: Begin with `ChatPlugin` and add others as needed
2. **Use Type Safety**: Define proper TypeScript interfaces for your state
3. **Handle Errors**: Always implement proper error handling in tools and plugins
4. **Test Plugins**: Test each plugin independently before combining them
5. **Document Commands**: Provide clear help text and examples
6. **Validate Input**: Use `ConfigPlugin` validation for user inputs
7. **Graceful Degradation**: Ensure commands work without LLM when available

## 🔗 Advanced Topics

### Custom Plugins

Create your own plugins for domain-specific functionality:

```typescript
class MyCustomPlugin implements Plugin {
  name = 'my-custom';

  async initialize(command: BaseInteractiveCommand): Promise<void> {
    // Setup your plugin
  }

  async onMessage(message: string): Promise<boolean> {
    if (message.startsWith('/my-custom')) {
      // Handle your custom command
      return true;
    }
    return false;
  }

  renderComponents(): ReactElement[] {
    // Return custom UI components
    return [];
  }
}
```

### Tool Integration

Register tools for use by agents and LLMs:

```typescript
const myTool: ToolDefinition = {
  name: 'my-tool',
  description: 'Does something useful',
  parameters: {
    type: 'object',
    properties: {
      input: { type: 'string', description: 'Input parameter' }
    }
  },
  execute: async (params) => {
    // Your tool logic
    return { result: 'success' };
  }
};

toolRegistry.registerTool(myTool);
```

### Agent Creation

Create autonomous agents that can work towards goals:

```typescript
await startAgent(
  'my-agent',
  'Help the user organize their files',
  sessionId,
  llmProvider
);
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add your command to `src/commands/`
4. Include tests and documentation
5. Submit a pull request

## 📄 License

MIT License

---

Built with ❤️ using the INK CLI Interactive Command Framework