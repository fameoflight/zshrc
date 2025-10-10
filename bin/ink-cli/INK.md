# INK CLI Architecture

## Overview

INK CLI is a modular command-line interface application built with React and Ink, following a plugin-based architecture inspired by Rust's command pattern. The system provides a foundation for building interactive CLI applications with reusable React components.

## Core Architecture

### Command System

The architecture centers around a trait-based command system similar to Rust's pattern:

- **Command Interface** (`src/base/command.ts`) - Defines the `Command` trait with required methods
- **Command Registry** (`src/base/registry.ts`) - Manages command registration and lookup
- **Global Registry** (`src/base/index.ts`) - Provides singleton access to the command registry

Each command must implement the `Command` interface:
- `name()` - Unique command identifier
- `description()` - Brief command description
- `config()` - Command configuration including flags
- `help()` - Detailed help with examples and usage
- `execute()` - Main command logic returning React elements

### Application Flow

1. **CLI Entry** (`src/cli.tsx`) - Main entry point using meow for argument parsing
2. **Command Resolution** - Looks up commands in the global registry
3. **Execution** - Renders React components via Ink
4. **Help System** - Dynamic help generation from command metadata

### Component Architecture

- **React Components** - All commands return React elements for rendering
- **Ink Integration** - Uses Ink for terminal rendering and interactivity
- **Component Library** - Extensive collection of Ink components for UI elements

### Flag System

Commands define their flag requirements through the `CommandConfig` interface:
- Type-safe flag definitions (string, number, boolean)
- Required vs optional flags
- Default values and descriptions
- Automatic help generation

## Module Structure

```
src/
├── cli.tsx              # Main entry point and command routing
├── Help.tsx             # Dynamic help component
├── base/                # Core framework
│   ├── command.ts       # Command interface and types
│   ├── registry.ts      # Command registration system
│   └── index.ts         # Global registry exports
└── commands/            # Command implementations
    ├── index.ts         # Command registration
    └── [command].tsx    # Individual command files
```

## Design Patterns

### Plugin Architecture
- Commands self-register via the global registry
- No central command list maintenance
- Easy to add new commands without modifying core code

### Trait System
- Interface-based design ensures consistency
- Type-safe command implementation
- Clear separation of concerns

### React Rendering
- Commands return React elements rather than printing directly
- Enables rich, interactive CLI interfaces
- Reusable component patterns

### Configuration-Driven
- Commands declare their requirements through configuration objects
- Automatic help generation and validation
- Consistent flag handling across commands

## Example Command Implementation

```tsx
import React from 'react';
import {Text, Box} from 'ink';
import {Command, CommandConfig, CommandFlags, CommandHelp} from '../base/command.js';

/**
 * Add Command - adds two numbers and shows the output
 */
class AddCommand implements Command {
	name(): string {
		return 'add';
	}

	description(): string {
		return 'Add two numbers and show the result';
	}

	config(): CommandConfig {
		return {
			name: this.name(),
			description: this.description(),
			flags: {
				a: {
					type: 'number',
					description: 'First number to add',
					required: true,
				},
				b: {
					type: 'number',
					description: 'Second number to add',
					required: true,
				},
			},
		};
	}

	help(): CommandHelp {
		return {
			description: 'Adds two numbers together and displays the result with a visual calculation.',
			usage: 'add --a=<number> --b=<number>',
			examples: [
				'add --a=5 --b=3',
				'add --a=10.5 --b=2.3',
				'add -a=100 -b=200',
			],
			notes: [
				'Both numbers are required parameters',
				'Supports both integers and decimal numbers',
				'Results are displayed with color-coded formatting',
			],
		};
	}

	execute(flags: CommandFlags): React.ReactElement {
		const a = flags['a'] || 0;
		const b = flags['b'] || 0;
		const sum = a + b;

		return (
			<Box flexDirection="column">
				<Text color="cyan">🧮 Adding two numbers:</Text>
				<Text>
					<Text color="yellow">{a}</Text>
					{' + '}
					<Text color="yellow">{b}</Text>
					{' = '}
					<Text color="green" bold>
						{sum}
					</Text>
				</Text>
			</Box>
		);
	}
}

export default AddCommand;
```

## Adding New Commands

1. Create command class implementing `Command` interface
2. Add to `src/commands/index.ts` registration
3. Export command for automatic discovery

The architecture ensures isolation between commands while providing shared infrastructure for common functionality like help generation, flag parsing, and React rendering.