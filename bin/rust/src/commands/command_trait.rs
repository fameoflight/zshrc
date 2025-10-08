use clap::ArgMatches;

/// Base CommandTrait - similar to abstract class Command in other languages
/// All commands must implement these methods
pub trait CommandTrait {
    /// Return unique command name - like class variable 'name'
    fn name() -> &'static str
    where
        Self: Sized;

    /// Return help text for the command
    fn help() -> &'static str
    where
        Self: Sized;

    /// Execute the command - like execute(*args, **kwargs)
    fn execute(matches: &ArgMatches) -> anyhow::Result<()>
    where
        Self: Sized;

    /// Build clap command configuration (optional, can use defaults)
    fn build_command() -> clap::Command
    where
        Self: Sized,
    {
        clap::Command::new(Self::name()).about(Self::help())
    }
}
