pub mod command_trait;
pub mod claude_export;
pub mod disk_usage;
pub mod llm_chat;

pub use claude_export::ClaudeExportCommand;
pub use command_trait::CommandTrait;
pub use disk_usage::DiskUsageCommand;
pub use llm_chat::LLMChatCommand;

use once_cell::sync::Lazy;
use std::collections::HashMap;

/// Command struct to hold build and execute functions
#[derive(Clone)]
struct CommandFunctions {
    build: fn() -> clap::Command,
    execute: fn(&clap::ArgMatches) -> anyhow::Result<()>,
}

/// Global command registry - add new commands here only!
static COMMANDS: Lazy<HashMap<&'static str, CommandFunctions>> = Lazy::new(|| {
    let mut commands = HashMap::new();

    // Register disk-usage command
    commands.insert(
        "disk-usage",
        CommandFunctions {
            build: DiskUsageCommand::build_command,
            execute: DiskUsageCommand::execute,
        },
    );

    // Register llm-chat command
    commands.insert(
        "llm-chat",
        CommandFunctions {
            build: LLMChatCommand::build_command,
            execute: LLMChatCommand::execute,
        },
    );

    // Register claude-export command
    commands.insert(
        "claude-export",
        CommandFunctions {
            build: ClaudeExportCommand::build_command,
            execute: ClaudeExportCommand::execute,
        },
    );

    // Add new commands here:
    // commands.insert("another-command", CommandFunctions {
    //     build: AnotherCommand::build_command,
    //     execute: AnotherCommand::execute,
    // });

    commands
});

/// Register all available commands - just returns the keys
pub fn register_commands() -> Vec<&'static str> {
    COMMANDS.keys().copied().collect()
}

/// Ensure all command names are unique (already guaranteed by HashMap)
pub fn check_unique_names(names: &[&str]) -> anyhow::Result<()> {
    for &name in names {
        if !COMMANDS.contains_key(name) {
            return Err(anyhow::anyhow!("Command not registered: {}", name));
        }
    }
    Ok(())
}

/// Get the clap Command for a given command name
pub fn get_subcommand(name: &str) -> clap::Command {
    if let Some(cmd_funcs) = COMMANDS.get(name) {
        (cmd_funcs.build)()
    } else {
        panic!("Unknown command: {}", name);
    }
}

/// Execute the command matching the subcommand name
pub fn execute_command(name: &str, matches: &clap::ArgMatches) -> anyhow::Result<()> {
    if let Some(cmd_funcs) = COMMANDS.get(name) {
        (cmd_funcs.execute)(matches)
    } else {
        Err(anyhow::anyhow!("Unknown command: {}", name))
    }
}
