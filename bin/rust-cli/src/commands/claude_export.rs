// claude-export command - Export Claude Code sessions to Markdown

use crate::claude::{MarkdownExporter, ProjectMatcher, TranscriptParser};
use crate::commands::CommandTrait;
use crate::utils::logger;
use anyhow::{Context, Result};
use clap::{Arg, ArgMatches, Command};
use console::style;
use indicatif::{ProgressBar, ProgressStyle};
use std::fs;
use std::path::PathBuf;

pub struct ClaudeExportCommand;

impl CommandTrait for ClaudeExportCommand {
    fn name() -> &'static str {
        "claude-export"
    }

    fn help() -> &'static str {
        "Export Claude Code sessions to Markdown files"
    }

    fn build_command() -> Command {
        Command::new(Self::name())
            .about(Self::help())
            .arg(
                Arg::new("project")
                    .short('p')
                    .long("project")
                    .value_name("NAME")
                    .help("Project name (supports fuzzy matching)"),
            )
            .arg(
                Arg::new("output")
                    .short('o')
                    .long("output")
                    .value_name("DIR")
                    .help("Output directory (default: ~/Documents/Claude)"),
            )
            .arg(
                Arg::new("dry-run")
                    .long("dry-run")
                    .action(clap::ArgAction::SetTrue)
                    .help("Show what would be exported without writing files"),
            )
            .arg(
                Arg::new("verbose")
                    .short('v')
                    .long("verbose")
                    .action(clap::ArgAction::SetTrue)
                    .help("Verbose output"),
            )
            .arg(
                Arg::new("clean")
                    .long("clean")
                    .action(clap::ArgAction::SetTrue)
                    .help("Delete existing output directory before exporting (fresh backup)"),
            )
            .arg(
                Arg::new("without-files")
                    .long("without-files")
                    .action(clap::ArgAction::SetTrue)
                    .help("Skip exporting file snapshots (markdown only)"),
            )
    }

    fn execute(matches: &ArgMatches) -> Result<()> {
        let project = matches.get_one::<String>("project").map(|s| s.to_string());
        let output = matches.get_one::<String>("output").map(PathBuf::from);
        let dry_run = matches.get_flag("dry-run");
        let verbose = matches.get_flag("verbose");
        let clean = matches.get_flag("clean");
        let without_files = matches.get_flag("without-files");
        let with_files = !without_files; // Include files by default

        execute_export(project, output, dry_run, verbose, clean, with_files)
    }
}

fn execute_export(
    project: Option<String>,
    output: Option<PathBuf>,
    dry_run: bool,
    verbose: bool,
    clean: bool,
    with_files: bool,
) -> Result<()> {
    logger::log_banner("Claude Session Exporter");

    // Determine Claude projects directory
    let home = std::env::var("HOME").context("HOME environment variable not set")?;
    let projects_dir = PathBuf::from(&home).join(".claude/projects");
    let file_history_dir = PathBuf::from(&home).join(".claude/file-history");

    if !projects_dir.exists() {
        anyhow::bail!(
            "Claude projects directory not found: {}",
            projects_dir.display()
        );
    }

    if verbose {
        logger::log_debug(&format!(
            "Reading transcripts from: {}",
            projects_dir.display()
        ));
    }

    // Find all transcript files
    let transcripts =
        TranscriptParser::find_all_transcripts(&projects_dir).context("Failed to find transcripts")?;

    if transcripts.is_empty() {
        logger::log_warning("No transcript files found");
        return Ok(());
    }

    logger::log_success(&format!("Found {} transcript files", transcripts.len()));

    // Group by project
    let grouped = TranscriptParser::group_by_project(transcripts);
    if verbose {
        logger::log_debug(&format!("Found {} projects", grouped.len()));
    }

    // Filter by project if specified
    let projects_to_export = if let Some(pattern) = &project {
        let matcher = ProjectMatcher::new();
        let project_names: Vec<String> = grouped.keys().cloned().collect();
        let matches = matcher.match_projects(pattern, &project_names);

        if matches.is_empty() {
            logger::log_error(&format!("No projects match pattern: {}", pattern));
            logger::log_info("Available projects:");
            for name in project_names {
                logger::log_info(&format!("  - {}", ProjectMatcher::friendly_name(&name)));
            }
            return Ok(());
        }

        logger::log_success(&format!(
            "Matched {} project(s): {}",
            matches.len(),
            matches
                .iter()
                .map(|p| ProjectMatcher::friendly_name(p))
                .collect::<Vec<_>>()
                .join(", ")
        ));

        matches
    } else {
        grouped.keys().cloned().collect()
    };

    // Determine output directory
    let output_dir = if let Some(dir) = &output {
        dir.clone()
    } else {
        PathBuf::from(home).join("Documents/Claude")
    };

    logger::log_info(&format!("Output directory: {}", output_dir.display()));

    if dry_run {
        logger::log_warning("DRY RUN MODE - No files will be written");
    }

    // Clean existing files if requested (for fresh backup)
    if clean && output_dir.exists() {
        if dry_run {
            logger::log_warning(&format!("[DRY-RUN] Would delete: {}", output_dir.display()));
        } else {
            logger::log_warning(&format!("Cleaning existing directory: {}", output_dir.display()));
            fs::remove_dir_all(&output_dir).with_context(|| {
                format!("Failed to clean directory: {}", output_dir.display())
            })?;
            fs::create_dir_all(&output_dir).with_context(|| {
                format!("Failed to recreate directory: {}", output_dir.display())
            })?;
            logger::log_success("Directory cleaned");
        }
    }

    // Export each project
    let mut total_sessions = 0;
    let mut total_files_created = 0;

    for project_name in projects_to_export {
        if let Some(transcript_files) = grouped.get(&project_name) {
            logger::log_section(&format!(
                "Project: {}",
                style(ProjectMatcher::friendly_name(&project_name)).cyan()
            ));

            let project_output_dir = output_dir.join(ProjectMatcher::friendly_name(&project_name));

            if !dry_run {
                fs::create_dir_all(&project_output_dir).with_context(|| {
                    format!("Failed to create directory: {}", project_output_dir.display())
                })?;
            }

            // Progress bar
            let pb = ProgressBar::new(transcript_files.len() as u64);
            pb.set_style(
                ProgressStyle::default_bar()
                    .template("  {bar:40.cyan/blue} {pos}/{len} {msg}")
                    .unwrap()
                    .progress_chars("█▓▒░  "),
            );

            for transcript_file in transcript_files {
                let file_name = transcript_file
                    .file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("unknown");

                pb.set_message(format!("Processing {}", file_name));

                // Parse transcript
                match TranscriptParser::parse_file(transcript_file) {
                    Ok(entries) => {
                        if let Some(session) = TranscriptParser::entries_to_session(entries) {
                            // Generate markdown
                            let exporter = MarkdownExporter::new(&session);
                            let markdown = exporter.generate();

                            // Create output filename from session start time
                            let output_filename =
                                format!("{}.md", session.start_time.replace(':', "-").replace('T', "-").split('.').next().unwrap_or(&session.start_time));

                            let output_path = project_output_dir.join(output_filename);

                            if !dry_run {
                                fs::write(&output_path, markdown).with_context(|| {
                                    format!("Failed to write file: {}", output_path.display())
                                })?;
                                total_files_created += 1;

                                // Export file snapshots if requested
                                if with_files {
                                    let session_file_history = file_history_dir.join(&session.session_id);
                                    if session_file_history.exists() && !session.file_map.is_empty() {
                                        let files_output_dir = project_output_dir.join(format!(
                                            "{}-files",
                                            session.start_time.replace(':', "-").replace('T', "-").split('.').next().unwrap_or(&session.start_time)
                                        ));

                                        // Copy all file snapshots with their original paths + version suffix
                                        // Also track latest version for creating symlink
                                        use std::collections::HashMap;
                                        let mut latest_versions: HashMap<String, PathBuf> = HashMap::new();

                                        for entry in fs::read_dir(&session_file_history)? {
                                            let entry = entry?;
                                            let source = entry.path();
                                            if source.is_file() {
                                                let filename = source.file_name().unwrap().to_string_lossy();
                                                // Parse filename: hash@vN
                                                let parts: Vec<&str> = filename.split('@').collect();
                                                if parts.len() == 2 {
                                                    let hash = parts[0];
                                                    let version_str = parts[1]; // e.g., "v1", "v2"

                                                    if let Some(original_path) = session.file_map.get(hash) {
                                                        // Parse version number
                                                        let version_num = version_str.trim_start_matches('v').parse::<u32>().unwrap_or(1);

                                                        // Format with proper extension preservation
                                                        // e.g., main.rs -> main_v001.rs
                                                        let path = std::path::Path::new(original_path);
                                                        let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
                                                        let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");
                                                        let parent = path.parent().map(|p| p.to_str().unwrap_or("")).unwrap_or("");

                                                        let dest_path = if ext.is_empty() {
                                                            format!("{}/{}_v{:03}", parent, stem, version_num).trim_start_matches('/').to_string()
                                                        } else {
                                                            format!("{}/{}_v{:03}.{}", parent, stem, version_num, ext).trim_start_matches('/').to_string()
                                                        };

                                                        let dest = files_output_dir.join(&dest_path);

                                                        if let Some(parent) = dest.parent() {
                                                            fs::create_dir_all(parent).with_context(|| {
                                                                format!("Failed to create directory: {}", parent.display())
                                                            })?;
                                                        }

                                                        fs::copy(&source, &dest).with_context(|| {
                                                            format!("Failed to copy file: {}", source.display())
                                                        })?;

                                                        // Track latest version (highest vN)
                                                        let base_path = original_path.trim_start_matches('/').to_string();
                                                        latest_versions.insert(base_path, dest);
                                                    }
                                                }
                                            }
                                        }

                                        // Create "latest" copy (without version suffix) for each file
                                        for (base_path, latest_src) in latest_versions {
                                            let dest = files_output_dir.join(&base_path);
                                            if let Some(parent) = dest.parent() {
                                                fs::create_dir_all(parent).ok();
                                            }
                                            fs::copy(&latest_src, &dest).ok();
                                        }

                                        if verbose {
                                            logger::log_debug(&format!("  Copied {} file(s) to: {}", session.file_map.len(), files_output_dir.display()));
                                        }
                                    }
                                }
                            }

                            total_sessions += 1;

                            if verbose {
                                logger::log_debug(&format!(
                                    "  Exported: {} ({} messages, {} tokens)",
                                    output_path.display(),
                                    session.messages.len(),
                                    session.total_tokens.total()
                                ));
                            }
                        }
                    }
                    Err(e) => {
                        if verbose {
                            logger::log_warning(&format!("Failed to parse {}: {}", file_name, e));
                        }
                    }
                }

                pb.inc(1);
            }

            pb.finish_with_message(format!(
                "Completed {} sessions",
                transcript_files.len()
            ));
        }
    }

    // Summary
    println!();
    logger::log_success("Export complete!");
    logger::log_info(&format!("  Sessions processed: {}", total_sessions));

    if !dry_run {
        logger::log_info(&format!("  Files created: {}", total_files_created));
        logger::log_info(&format!("  Output location: {}", output_dir.display()));
    } else {
        logger::log_info("  (Dry run - no files written)");
    }

    Ok(())
}
