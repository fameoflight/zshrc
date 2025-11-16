use clap::Command;

mod claude;
mod commands;
mod utils;

fn main() -> anyhow::Result<()> {
    // Before starting work, read RUST.md to understand the command architecture
    // The system uses an Abstract Command Pattern with a global HashMap registry
    // All commands implement CommandTrait and are registered in commands/mod.rs
    // To add new commands: implement trait + add one registration line
    // Register all commands and check for name uniqueness
    let command_names = commands::register_commands();
    commands::check_unique_names(&command_names)?;

    // Build the main app with all subcommands
    let mut app = Command::new("utils")
        .version("0.1.0")
        .about("Utility programs collection")
        .subcommand_required(true);

    // Add all commands as subcommands
    for name in command_names {
        app = app.subcommand(commands::get_subcommand(&name));
    }

    let matches = app.get_matches();

    // Execute the matching command
    if let Some((subcommand_name, sub_matches)) = matches.subcommand() {
        commands::execute_command(subcommand_name, sub_matches)?;
    }

    Ok(())
}