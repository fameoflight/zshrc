use console::{style, Emoji};
use std::env;
use std::io::{self, Write};

/// Custom emoji set for logging
#[allow(dead_code)]
static EMOJI_SUCCESS: Emoji = Emoji("✅", "[SUCCESS]");
#[allow(dead_code)]
static EMOJI_ERROR: Emoji = Emoji("❌", "[ERROR]");
#[allow(dead_code)]
static EMOJI_WARNING: Emoji = Emoji("⚠️", "[WARNING]");
#[allow(dead_code)]
static EMOJI_INFO: Emoji = Emoji("ℹ️", "[INFO]");
#[allow(dead_code)]
static EMOJI_DEBUG: Emoji = Emoji("🐛", "[DEBUG]");
#[allow(dead_code)]
static EMOJI_PROGRESS: Emoji = Emoji("🔄", "[PROGRESS]");

/// Check if debug mode is enabled via DEBUG environment variable
#[allow(dead_code)]
fn is_debug_enabled() -> bool {
    let env_debug = env::var("DEBUG").unwrap_or_default();
    // 1 or true (case insensitive) enables debug
    env_debug.eq_ignore_ascii_case("1") || env_debug.eq_ignore_ascii_case("true")
}

/// Log success message (green + emoji)
#[allow(dead_code)]
pub fn log_success(message: &str) {
    println!(
        "{} {}",
        style(EMOJI_SUCCESS).green(),
        style(message).green()
    );
}

/// Log error message (red + emoji, to stderr)
#[allow(dead_code)]
pub fn log_error(message: &str) {
    eprintln!("{} {}", style(EMOJI_ERROR).red(), style(message).red());
}

/// Log warning message (yellow + emoji)
#[allow(dead_code)]
pub fn log_warning(message: &str) {
    println!(
        "{} {}",
        style(EMOJI_WARNING).yellow(),
        style(message).yellow()
    );
}

/// Log info message (blue + emoji)
#[allow(dead_code)]
pub fn log_info(message: &str) {
    println!("{} {}", style(EMOJI_INFO).blue(), style(message).blue());
}

/// Log debug message (cyan + emoji, only if DEBUG=1)
#[allow(dead_code)]
pub fn log_debug(message: &str) {
    if is_debug_enabled() {
        println!("{} {}", style(EMOJI_DEBUG).cyan(), style(message).dim());
    }
}

/// Log progress message (cyan + emoji)
#[allow(dead_code)]
pub fn log_progress(message: &str) {
    println!("{} {}", style(EMOJI_PROGRESS).cyan(), style(message).cyan());
}

/// Log section header (magenta + emoji)
#[allow(dead_code)]
pub fn log_section(section_name: &str) {
    println!(
        "\n{} {}",
        style("🔧").magenta(),
        style(section_name).magenta().bold()
    );
}

/// Log banner for script start
#[allow(dead_code)]
pub fn log_banner(script_name: &str) {
    println!(
        "\n{} {}",
        style("🚀").blue().bright(),
        style(script_name).blue().bright().bold()
    );
    println!("{}", style("━".repeat(50)).blue().bright());
}

/// Log completion message
#[allow(dead_code)]
pub fn log_completion(script_name: &str) {
    println!("{}", style("━".repeat(50)).blue().bright());
    println!(
        "{} {}",
        style("🎉").green(),
        style(format!("{} completed!", script_name)).green().bold()
    );
}

/// Log file creation
#[allow(dead_code)]
pub fn log_file_created(file_path: &str) {
    println!(
        "{} {}",
        style("📄").cyan(),
        style(format!("Created file: {}", file_path)).cyan()
    );
}

/// Log installation
#[allow(dead_code)]
pub fn log_install(package: &str) {
    println!(
        "{} {}",
        style("📦").green(),
        style(format!("Installed: {}", package)).green()
    );
}

/// Log Git operations
#[allow(dead_code)]
pub fn log_git(message: &str) {
    println!("{} {}", style("🐙").white(), style(message).white());
}

/// Prompt user for confirmation
#[allow(dead_code)]
pub fn confirm_action(message: &str) -> bool {
    print!(
        "{} {} [y/N]: ",
        style("❓").yellow(),
        style(message).yellow()
    );
    io::stdout().flush().unwrap();

    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap();

    let response = input.trim().to_lowercase();
    response.starts_with('y')
}

/// Prompt user for input with a default value
#[allow(dead_code)]
pub fn prompt_with_default(message: &str, default: &str) -> String {
    print!("{} [{}]: ", style(message).cyan(), style(default).dim());
    io::stdout().flush().unwrap();

    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap();

    let response = input.trim();
    if response.is_empty() {
        default.to_string()
    } else {
        response.to_string()
    }
}

/// Log error with context for debugging
#[allow(dead_code)]
pub fn log_error_with_context(error: &str, context: &str) {
    log_error(error);
    if is_debug_enabled() {
        log_debug(&format!("Context: {}", context));
    }
}

/// Create a progress bar (for long operations)
#[allow(dead_code)]
pub fn create_progress_bar(total: u64) -> indicatif::ProgressBar {
    let pb = indicatif::ProgressBar::new(total);
    pb.set_style(
        indicatif::ProgressStyle::default_bar()
            .template(
                "{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} ({eta})",
            )
            .unwrap()
            .progress_chars("#>-"),
    );
    pb
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    #[test]
    fn test_debug_detection() {
        // Test with DEBUG not set
        env::remove_var("DEBUG");
        assert!(!is_debug_enabled());

        // Test with DEBUG=1
        env::set_var("DEBUG", "1");
        assert!(is_debug_enabled());

        // Test with DEBUG=0
        env::set_var("DEBUG", "0");
        assert!(!is_debug_enabled());

        // Clean up
        env::remove_var("DEBUG");
    }
}
