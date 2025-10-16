# Rust Commands Architecture

## Overview

This is a modular command-line utility system built in Rust that provides an extensible architecture for building CLI tools. The system uses traits to define a common interface for all commands, making it easy to add new functionality while maintaining type safety and zero-cost abstractions.

**Binary name**: `utils`
**Location**: `/Users/hemantv/zshrc/bin/rust-cli/`

## Architecture Pattern

The system follows an **Abstract Command Pattern** with these key components:

### 1. CommandTrait (Abstract Base Class)

Located in `src/commands/command_trait.rs`, this is the base trait that all commands must implement:

```rust
pub trait CommandTrait {
    fn name() -> &'static str where Self: Sized;           // Command identifier
    fn help() -> &'static str where Self: Sized;           // Help text
    fn execute(matches: &ArgMatches) -> anyhow::Result<()> where Self: Sized;  // Main logic
    fn build_command() -> clap::Command where Self: Sized; // CLI configuration (with default)
}
```

**Why `where Self: Sized`?**

- Allows trait to be object-safe while using associated functions
- Enables static dispatch for zero-cost abstraction
- Required because these are associated functions (not methods)

This is equivalent to abstract classes in other languages:

- **Python**: `class Command(ABC): @abstractmethod def execute(self, *args)`
- **Java**: `abstract class Command { abstract String name(); abstract void execute(); }`
- **Go**: Interface with Name(), Help(), Execute() methods

### 2. Global Command Registry

Located in `src/commands/mod.rs`, this is the central command registry using lazy static initialization:

```rust
static COMMANDS: Lazy<HashMap<&'static str, CommandFunctions>> = Lazy::new(|| {
    let mut commands = HashMap::new();

    // Register disk-usage command
    commands.insert("disk-usage", CommandFunctions {
        build: DiskUsageCommand::build_command,
        execute: DiskUsageCommand::execute,
    });

    commands
});
```

**Key benefits:**

- **Lazy initialization**: Commands loaded only when first accessed
- **Thread-safe**: `once_cell::sync::Lazy` guarantees single initialization
- **Function pointers**: Zero overhead for command lookup
- **Static lifetime**: No runtime allocation costs

## File Structure

```
src/
├── main.rs              # Application entry point
├── commands/
│   ├── mod.rs          # Command registry and management
│   ├── command_trait.rs # Abstract base trait
│   └── disk_usage.rs   # Concrete command implementation
└── utils/              # Shared utilities
```

## Adding New Commands

Adding a new command is simple and requires changes in only **3 places**:

### 1. Create Command File (Optional)

Create `src/commands/my_command.rs`:

```rust
use crate::commands::command_trait::CommandTrait;
use clap::{Arg, ArgMatches};

pub struct MyCommand;

impl CommandTrait for MyCommand {
    fn name() -> &'static str {
        "my-command"
    }

    fn help() -> &'static str {
        "Description of my command"
    }

    fn execute(matches: &ArgMatches) -> anyhow::Result<()> {
        // Your implementation here
        println!("Executing my command!");
        Ok(())
    }

    fn build_command() -> clap::Command {
        clap::Command::new(Self::name())
            .about(Self::help())
            .arg(Arg::new("input").required(true))
    }
}
```

### 2. Update Module Declaration

Add to `src/commands/mod.rs`:

```rust
pub mod my_command;
pub use my_command::MyCommand;
```

### 3. Register Command

Add to the global registry in `src/commands/mod.rs`:

```rust
// In get_command_registry() function
commands.insert("my-command", CommandFunctions {
    build: MyCommand::build_command,
    execute: MyCommand::execute,
});
```

That's it! The system automatically:

- Registers the command
- Ensures name uniqueness (via HashMap)
- Handles CLI argument parsing
- Executes the command when called

## Key Benefits

### 1. **Single Source of Truth**

All commands are registered in one central HashMap. No more scattered command definitions.

### 2. **Type Safety**

The trait system ensures all commands implement the required methods with correct signatures.

### 3. **Zero Overhead**

Commands are only loaded when needed (lazy initialization) and function pointers are efficient.

### 4. **Easy Extension**

Add new commands by implementing the trait and adding one registration line.

### 5. **Automatic Uniqueness**

HashMap guarantees command names are unique - no duplicate command handling needed.

## Example: disk-usage Command

The existing `disk-usage` command demonstrates the pattern:

```rust
pub struct DiskUsageCommand;

impl CommandTrait for DiskUsageCommand {
    fn name() -> &'static str { "disk-usage" }
    fn help() -> &'static str { "Fast disk usage analyzer" }

    fn execute(matches: &ArgMatches) -> anyhow::Result<()> {
        // Parse arguments and run disk usage analysis
        let depth: usize = matches.get_one::<String>("depth")?.parse()?;
        let file_count: usize = matches.get_one::<String>("files")?.parse()?;
        // ... implementation
    }

    fn build_command() -> clap::Command {
        clap::Command::new(Self::name())
            .about(Self::help())
            .arg(Arg::new("depth").long("depth").default_value("3"))
            .arg(Arg::new("files").long("files").default_value("5"))
            .arg(Arg::new("input").required(true))
    }
}
```

## Flow of Execution

1. **Startup**: `main.rs` calls `register_commands()` → returns command names
2. **Validation**: `check_unique_names()` ensures all names are valid
3. **CLI Setup**: Each command's `build_command()` is called to create clap subcommands
4. **Execution**: User runs command → matching `execute()` function is called with parsed arguments

## Dependencies

- **clap**: Command-line argument parsing
- **anyhow**: Error handling
- **once_cell**: Lazy global initialization
- **HashMap**: Command registry storage

## Comparison to Other Languages

| Feature           | Rust                 | Python               | Java                     |
| ----------------- | -------------------- | -------------------- | ------------------------ |
| Abstract Base     | `trait CommandTrait` | `class Command(ABC)` | `abstract class Command` |
| Global Registry   | `static HashMap`     | `global dict`        | `static Map`             |
| Function Pointers | `fn() -> Result`     | `callable objects`   | `Method references`      |
| Type Safety       | Compile-time         | Runtime              | Compile-time             |
| Memory Safety     | ✅                   | ❌                   | ❌                       |

This architecture provides the extensibility of dynamic languages while maintaining Rust's type safety and performance guarantees.
