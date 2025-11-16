// JSONL transcript parser

use super::models::*;
use anyhow::{Context, Result};
use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};

pub struct TranscriptParser;

impl TranscriptParser {
    /// Parse a single JSONL transcript file
    pub fn parse_file(path: &Path) -> Result<Vec<TranscriptEntry>> {
        let file = File::open(path)
            .with_context(|| format!("Failed to open transcript file: {}", path.display()))?;

        let reader = BufReader::new(file);
        let mut entries = Vec::new();

        for (line_num, line) in reader.lines().enumerate() {
            let line = line.with_context(|| {
                format!("Failed to read line {} in {}", line_num + 1, path.display())
            })?;

            // Skip empty lines
            if line.trim().is_empty() {
                continue;
            }

            // Try to parse the line as a transcript entry
            match serde_json::from_str::<TranscriptEntry>(&line) {
                Ok(entry) => entries.push(entry),
                Err(e) => {
                    // Log warning but continue processing
                    eprintln!(
                        "Warning: Failed to parse line {} in {}: {}",
                        line_num + 1,
                        path.display(),
                        e
                    );
                }
            }
        }

        Ok(entries)
    }

    /// Find all transcript files in the projects directory
    pub fn find_all_transcripts(projects_dir: &Path) -> Result<Vec<PathBuf>> {
        if !projects_dir.exists() {
            anyhow::bail!("Projects directory does not exist: {}", projects_dir.display());
        }

        let mut transcripts = Vec::new();

        for entry in std::fs::read_dir(projects_dir)
            .with_context(|| format!("Failed to read directory: {}", projects_dir.display()))?
        {
            let entry = entry?;
            let path = entry.path();

            // Only process directories
            if !path.is_dir() {
                continue;
            }

            // Find all .jsonl files in this project directory
            for file_entry in std::fs::read_dir(&path)? {
                let file_entry = file_entry?;
                let file_path = file_entry.path();

                if file_path.extension().and_then(|s| s.to_str()) == Some("jsonl") {
                    transcripts.push(file_path);
                }
            }
        }

        Ok(transcripts)
    }

    /// Parse transcript entries into structured sessions
    pub fn entries_to_session(entries: Vec<TranscriptEntry>) -> Option<Session> {
        if entries.is_empty() {
            return None;
        }

        // Build file hash -> path mapping from file-history-snapshots
        let mut file_map: HashMap<String, String> = HashMap::new();
        for entry in &entries {
            if let TranscriptEntry::FileHistorySnapshot(snapshot) = entry {
                if let Some(tracked) = snapshot.snapshot.get("trackedFileBackups") {
                    if let Some(obj) = tracked.as_object() {
                        for (path, file_info) in obj {
                            if let Some(hash) = file_info.get("fileHash").and_then(|h| h.as_str()) {
                                file_map.insert(hash.to_string(), path.clone());
                            }
                        }
                    }
                }
            }
        }

        // Extract session metadata from first entry
        let (session_id, project_path, git_branch) = match &entries[0] {
            TranscriptEntry::User(user) => (
                user.session_id.clone(),
                user.cwd.clone(),
                user.git_branch.clone(),
            ),
            TranscriptEntry::Assistant(asst) => (
                asst.session_id.clone(),
                asst.cwd.clone().unwrap_or_default(),
                asst.git_branch.clone(),
            ),
            TranscriptEntry::System(sys) => (
                sys.session_id.clone(),
                String::new(),
                None,
            ),
            TranscriptEntry::Summary(summary) => (
                summary.session_id.clone(),
                String::new(),
                None,
            ),
            TranscriptEntry::FileHistorySnapshot(_) | TranscriptEntry::Unknown => return None,
        };

        let project_name = Self::extract_project_name(&project_path);

        let mut messages = Vec::new();
        let mut total_tokens = TokenStats::default();
        let mut start_time = String::new();
        let mut end_time = String::new();

        for entry in entries {
            match entry {
                TranscriptEntry::User(user) => {
                    if start_time.is_empty() {
                        start_time = user.timestamp.clone();
                    }
                    end_time = user.timestamp.clone();

                    messages.push(Self::user_entry_to_message(user));
                }
                TranscriptEntry::Assistant(asst) => {
                    if start_time.is_empty() {
                        start_time = asst.timestamp.clone();
                    }
                    end_time = asst.timestamp.clone();

                    if let Some(msg) = &asst.message {
                        if let Some(usage) = &msg.usage {
                            total_tokens.add(usage);
                        }
                    }

                    messages.push(Self::assistant_entry_to_message(asst));
                }
                TranscriptEntry::System(_) => {
                    // Skip system messages for now
                    continue;
                }
                TranscriptEntry::Summary(_) => {
                    // Skip summaries for now (could use for better titles later)
                    continue;
                }
                TranscriptEntry::FileHistorySnapshot(_) | TranscriptEntry::Unknown => {
                    // Skip file history snapshots and unknown entry types
                    continue;
                }
            }
        }

        Some(Session {
            session_id,
            project_name,
            project_path,
            git_branch,
            messages,
            start_time,
            end_time,
            total_tokens,
            file_map,
        })
    }

    /// Convert user entry to unified message format
    fn user_entry_to_message(entry: UserTranscriptEntry) -> Message {
        let message = entry.message.unwrap_or(UserMessage {
            role: "user".to_string(),
            content: UserContent::Text(String::new()),
        });

        let (text, tool_results) = match message.content {
            UserContent::Text(t) => (t, Vec::new()),
            UserContent::ContentBlocks(blocks) => {
                let mut text_parts = Vec::new();
                let mut tool_results = Vec::new();

                for block in blocks {
                    match block {
                        ContentBlock::Text { text } => text_parts.push(text),
                        ContentBlock::ToolResult {
                            tool_use_id,
                            content,
                            is_error,
                        } => {
                            let content_str = match content {
                                ToolResultContent::Text(t) => t,
                                ToolResultContent::Structured(v) => {
                                    serde_json::to_string_pretty(&v).unwrap_or_default()
                                }
                            };
                            tool_results.push(ToolResult {
                                tool_use_id,
                                content: content_str,
                                is_error: is_error.unwrap_or(false),
                            });
                        }
                        _ => {}
                    }
                }

                (text_parts.join("\n"), tool_results)
            }
        };

        Message {
            uuid: entry.uuid,
            timestamp: entry.timestamp,
            role: MessageRole::User,
            content: MessageContent::User { text, tool_results },
        }
    }

    /// Convert assistant entry to unified message format
    fn assistant_entry_to_message(entry: AssistantTranscriptEntry) -> Message {
        let mut text_blocks = Vec::new();
        let mut tool_uses = Vec::new();
        let mut thinking_blocks = Vec::new();

        let message = entry.message.as_ref();
        let content = message.map(|m| &m.content).cloned().unwrap_or_default();

        for block in content {
            match block {
                ContentBlock::Text { text } => text_blocks.push(text),
                ContentBlock::ToolUse { id, name, input } => {
                    tool_uses.push(ToolUse { id, name, input });
                }
                ContentBlock::Thinking { thinking, .. } => thinking_blocks.push(thinking),
                _ => {}
            }
        }

        Message {
            uuid: entry.uuid,
            timestamp: entry.timestamp,
            role: MessageRole::Assistant,
            content: MessageContent::Assistant {
                model: message.map(|m| m.model.clone()).unwrap_or_default(),
                text_blocks,
                tool_uses,
                thinking_blocks,
                usage: message.and_then(|m| m.usage.clone()),
            },
        }
    }

    /// Extract project name from project path
    /// Converts "/Users/hemantv/zshrc" to "zshrc"
    fn extract_project_name(path: &str) -> String {
        Path::new(path)
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("unknown")
            .to_string()
    }

    /// Group transcripts by project directory name
    pub fn group_by_project(transcripts: Vec<PathBuf>) -> HashMap<String, Vec<PathBuf>> {
        let mut groups: HashMap<String, Vec<PathBuf>> = HashMap::new();

        for transcript in transcripts {
            if let Some(parent) = transcript.parent() {
                if let Some(project_name) = parent.file_name().and_then(|s| s.to_str()) {
                    groups
                        .entry(project_name.to_string())
                        .or_insert_with(Vec::new)
                        .push(transcript);
                }
            }
        }

        groups
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_project_name() {
        assert_eq!(
            TranscriptParser::extract_project_name("/Users/hemantv/zshrc"),
            "zshrc"
        );
        assert_eq!(
            TranscriptParser::extract_project_name("/workspace/my-project"),
            "my-project"
        );
    }
}
