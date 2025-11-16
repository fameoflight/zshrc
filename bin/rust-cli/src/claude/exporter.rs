// Markdown exporter for Claude Code sessions

use super::models::*;
use chrono::{DateTime, Utc};
use std::fmt::Write as FmtWrite;

pub struct MarkdownExporter<'a> {
    session: &'a Session,
}

impl<'a> MarkdownExporter<'a> {
    pub fn new(session: &'a Session) -> Self {
        Self { session }
    }

    /// Generate full markdown document
    pub fn generate(&self) -> String {
        let mut md = String::new();

        // Generate title
        md.push_str(&self.generate_title());
        md.push_str("\n\n");

        // Generate Option 5 style header (Developer Notes)
        md.push_str(&self.generate_context_section());
        md.push_str(&self.generate_what_happened_section());
        md.push_str(&self.generate_solution_section());
        md.push_str(&self.generate_files_changed_section());
        md.push_str(&self.generate_lessons_section());
        md.push_str(&self.generate_tokens_section());

        md.push_str("\n---\n\n");

        // Generate Option 1 style full transcript
        md.push_str("## Full Transcript\n\n");
        md.push_str(&self.generate_full_transcript());

        md.push_str("\n---\n\n");

        // Footer
        md.push_str(&self.generate_footer());

        md
    }

    /// Generate session title from first user message or summary
    fn generate_title(&self) -> String {
        // Try to get meaningful title from first user message
        if let Some(first_msg) = self.session.messages.first() {
            if let MessageContent::User { text, .. } = &first_msg.content {
                let title = text.lines().next().unwrap_or("Claude Session");
                return format!("# {}", title);
            }
        }

        format!("# Claude Session - {}", self.format_timestamp(&self.session.start_time))
    }

    /// Generate context section (Option 5 header)
    fn generate_context_section(&self) -> String {
        let duration = self.calculate_duration();

        format!(
            "## Context\n\
             - **Project:** {}\n\
             - **Branch:** {}\n\
             - **Task:** {}\n\
             - **Session ID:** {}\n\
             - **Started:** {}\n\
             - **Duration:** {}\n\
             - **Model:** {}\n\n",
            self.session.project_path,
            self.session.git_branch.as_deref().unwrap_or("unknown"),
            self.extract_task(),
            self.session.session_id,
            self.format_timestamp(&self.session.start_time),
            duration,
            self.extract_model(),
        )
    }

    /// Generate "What Happened" summary section
    fn generate_what_happened_section(&self) -> String {
        let summary = self.generate_auto_summary();
        format!("## What Happened\n\n{}\n\n", summary)
    }

    /// Generate solution section (if applicable)
    fn generate_solution_section(&self) -> String {
        let mut solution = String::new();

        // Extract code blocks from assistant messages
        let code_blocks = self.extract_code_blocks();

        if !code_blocks.is_empty() {
            solution.push_str("## Solution\n\n");
            for (lang, code) in code_blocks.iter().take(3) {
                // Show top 3 code blocks
                writeln!(solution, "```{}", lang).ok();
                writeln!(solution, "{}", code).ok();
                writeln!(solution, "```\n").ok();
            }
            solution.push('\n');
        }

        solution
    }

    /// Generate files changed section
    fn generate_files_changed_section(&self) -> String {
        let files = self.extract_modified_files();

        if files.is_empty() {
            return String::new();
        }

        let session_timestamp = self.get_session_timestamp();

        let mut section = String::from("## Files Changed\n");
        for (file, desc) in files {
            let latest_path = format!("./{}-files/{}", session_timestamp, file.trim_start_matches('/'));
            write!(section, "- [`{}`]({}) - {} ", file, latest_path, desc).ok();

            // Add version links with proper naming
            let path = std::path::Path::new(&file);
            let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
            let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");
            let parent = path.parent().map(|p| p.to_str().unwrap_or("")).unwrap_or("");

            write!(section, "(").ok();
            if ext.is_empty() {
                write!(section, "[v001]({}/{}/{})", session_timestamp, parent.trim_start_matches('/'), format!("{}_v001", stem)).ok();
                write!(section, " | [v002]({}/{}/{})", session_timestamp, parent.trim_start_matches('/'), format!("{}_v002", stem)).ok();
                write!(section, " | [v003]({}/{}/{})", session_timestamp, parent.trim_start_matches('/'), format!("{}_v003", stem)).ok();
            } else {
                write!(section, "[v001](./{}-files/{}/{}_v001.{})", session_timestamp, parent.trim_start_matches('/'), stem, ext).ok();
                write!(section, " | [v002](./{}-files/{}/{}_v002.{})", session_timestamp, parent.trim_start_matches('/'), stem, ext).ok();
                write!(section, " | [v003](./{}-files/{}/{}_v003.{})", session_timestamp, parent.trim_start_matches('/'), stem, ext).ok();
            }
            writeln!(section, ")").ok();
        }
        section.push('\n');

        section
    }

    /// Generate lessons learned section (placeholder for now)
    fn generate_lessons_section(&self) -> String {
        "## Lessons Learned\n\n_[Review this session to extract key takeaways]_\n\n".to_string()
    }

    /// Generate tokens and cost section
    fn generate_tokens_section(&self) -> String {
        let total = &self.session.total_tokens;
        let cost = self.estimate_cost();

        format!(
            "## Tokens & Cost\n\
             - **Input:** {} tokens\n\
             - **Output:** {} tokens\n\
             - **Cache Read:** {} tokens\n\
             - **Cache Creation:** {} tokens\n\
             - **Total:** {} tokens\n\
             - **Estimated Cost:** ${:.2}\n\n",
            Self::format_number(total.input_tokens),
            Self::format_number(total.output_tokens),
            Self::format_number(total.cache_read_tokens),
            Self::format_number(total.cache_creation_tokens),
            Self::format_number(total.total()),
            cost
        )
    }

    /// Generate full transcript (Option 1 format)
    fn generate_full_transcript(&self) -> String {
        let mut transcript = String::new();

        for msg in &self.session.messages {
            transcript.push_str(&self.format_message(msg));
            transcript.push_str("\n\n");
        }

        transcript
    }

    /// Format a single message with full details
    fn format_message(&self, msg: &Message) -> String {
        let mut output = String::new();
        let time = self.format_time_only(&msg.timestamp);

        match &msg.content {
            MessageContent::User { text, tool_results } => {
                writeln!(output, "### {} - User", time).ok();
                writeln!(output).ok();
                writeln!(output, "{}", text).ok();

                // Show tool results in details
                for result in tool_results {
                    writeln!(output).ok();
                    writeln!(output, "<details>").ok();
                    if result.is_error {
                        writeln!(output, "<summary>❌ Tool Result (Error)</summary>").ok();
                    } else {
                        writeln!(output, "<summary>✅ Tool Result</summary>").ok();
                    }
                    writeln!(output).ok();
                    writeln!(output, "```").ok();
                    writeln!(output, "{}", result.content).ok();
                    writeln!(output, "```").ok();
                    writeln!(output).ok();
                    writeln!(output, "</details>").ok();
                }
            }
            MessageContent::Assistant {
                model,
                text_blocks,
                tool_uses,
                thinking_blocks,
                usage,
            } => {
                write!(output, "### {} - Assistant", time).ok();
                if !model.is_empty() {
                    write!(output, " ({})", model).ok();
                }
                writeln!(output).ok();
                writeln!(output).ok();

                // Show thinking if present
                for thinking in thinking_blocks {
                    writeln!(output, "💭 **Thinking:**").ok();
                    writeln!(output, "```").ok();
                    writeln!(output, "{}", thinking).ok();
                    writeln!(output, "```").ok();
                    writeln!(output).ok();
                }

                // Show text content
                for text in text_blocks {
                    writeln!(output, "{}", text).ok();
                    writeln!(output).ok();
                }

                // Show tool uses in details
                for tool in tool_uses {
                    writeln!(output, "<details>").ok();
                    writeln!(output, "<summary>🔧 Tool Use: {}</summary>", tool.name).ok();
                    writeln!(output).ok();
                    writeln!(output, "**Tool:** {}", tool.name).ok();
                    writeln!(output).ok();

                    // Add clickable file links if file operation
                    if (tool.name == "Edit" || tool.name == "Write" || tool.name == "Read") {
                        if let Some(file_path) = tool.input.get("file_path").and_then(|v| v.as_str()) {
                            let session_timestamp = self.get_session_timestamp();

                            // Link to all possible versions with proper naming
                            writeln!(output, "**File:** `{}`", file_path).ok();

                            // Generate version links with proper file naming
                            let path = std::path::Path::new(file_path);
                            let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
                            let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");
                            let parent = path.parent().map(|p| p.to_str().unwrap_or("")).unwrap_or("");

                            writeln!(output, "  - Versions: ", ).ok();
                            if ext.is_empty() {
                                write!(output, "[v001](./{}-files/{}/{})", session_timestamp, parent.trim_start_matches('/'), format!("{}_v001", stem)).ok();
                                write!(output, " | [v002](./{}-files/{}/{})", session_timestamp, parent.trim_start_matches('/'), format!("{}_v002", stem)).ok();
                                write!(output, " | [v003](./{}-files/{}/{})", session_timestamp, parent.trim_start_matches('/'), format!("{}_v003", stem)).ok();
                            } else {
                                write!(output, "[v001](./{}-files/{}/{}_v001.{})", session_timestamp, parent.trim_start_matches('/'), stem, ext).ok();
                                write!(output, " | [v002](./{}-files/{}/{}_v002.{})", session_timestamp, parent.trim_start_matches('/'), stem, ext).ok();
                                write!(output, " | [v003](./{}-files/{}/{}_v003.{})", session_timestamp, parent.trim_start_matches('/'), stem, ext).ok();
                            }
                            writeln!(output, " | [latest](./{}-files/{})", session_timestamp, file_path.trim_start_matches('/')).ok();
                            writeln!(output).ok();
                        }
                    }

                    if let Ok(formatted) = serde_json::to_string_pretty(&tool.input) {
                        writeln!(output, "**Input:**").ok();
                        writeln!(output, "```json").ok();
                        writeln!(output, "{}", formatted).ok();
                        writeln!(output, "```").ok();
                    }
                    writeln!(output).ok();
                    writeln!(output, "</details>").ok();
                    writeln!(output).ok();
                }

                // Show token usage if available
                if let Some(usage) = usage {
                    if usage.input_tokens.is_some() || usage.output_tokens.is_some() {
                        write!(output, "*Tokens: ").ok();
                        if let Some(input) = usage.input_tokens {
                            write!(output, "Input: {} | ", Self::format_number(input)).ok();
                        }
                        if let Some(output_tok) = usage.output_tokens {
                            write!(output, "Output: {}", Self::format_number(output_tok)).ok();
                        }
                        writeln!(output, "*").ok();
                    }
                }
            }
        }

        output
    }

    /// Generate footer with metadata
    fn generate_footer(&self) -> String {
        let now = Utc::now();
        format!(
            "**Session ID:** {}  \n\
             **Exported:** {}\n",
            self.session.session_id,
            now.format("%Y-%m-%d %H:%M:%S UTC")
        )
    }

    // Helper methods

    fn extract_task(&self) -> String {
        if let Some(first_msg) = self.session.messages.first() {
            if let MessageContent::User { text, .. } = &first_msg.content {
                let task = text.lines().next().unwrap_or("Unknown task");
                return task.to_string();
            }
        }
        "Session conversation".to_string()
    }

    fn extract_model(&self) -> String {
        for msg in &self.session.messages {
            if let MessageContent::Assistant { model, .. } = &msg.content {
                if !model.is_empty() {
                    return model.clone();
                }
            }
        }
        "unknown".to_string()
    }

    fn generate_auto_summary(&self) -> String {
        let user_messages: Vec<_> = self
            .session
            .messages
            .iter()
            .filter(|m| m.role == MessageRole::User)
            .collect();

        if user_messages.is_empty() {
            return "No user messages in this session.".to_string();
        }

        // Simple summary: count of messages and basic stats
        format!(
            "This session contains {} messages ({} from user, {} from assistant). The conversation covered {}.",
            self.session.messages.len(),
            user_messages.len(),
            self.session.messages.len() - user_messages.len(),
            self.extract_task().to_lowercase()
        )
    }

    fn extract_code_blocks(&self) -> Vec<(String, String)> {
        let mut blocks = Vec::new();

        for msg in &self.session.messages {
            if let MessageContent::Assistant { text_blocks, .. } = &msg.content {
                for text in text_blocks {
                    // Simple code block extraction
                    if let Some(start) = text.find("```") {
                        if let Some(end) = text[start + 3..].find("```") {
                            let code_section = &text[start + 3..start + 3 + end];
                            let mut lines = code_section.lines();
                            let lang = lines.next().unwrap_or("").trim().to_string();
                            let code = lines.collect::<Vec<_>>().join("\n");
                            blocks.push((lang, code));
                        }
                    }
                }
            }
        }

        blocks
    }

    fn extract_modified_files(&self) -> Vec<(String, String)> {
        let mut files = Vec::new();

        for msg in &self.session.messages {
            if let MessageContent::Assistant { tool_uses, .. } = &msg.content {
                for tool in tool_uses {
                    if tool.name == "Edit" || tool.name == "Write" {
                        if let Some(file_path) = tool.input.get("file_path") {
                            if let Some(path_str) = file_path.as_str() {
                                let desc = if tool.name == "Edit" {
                                    "Modified"
                                } else {
                                    "Created"
                                };
                                files.push((path_str.to_string(), desc.to_string()));
                            }
                        }
                    }
                }
            }
        }

        files
    }

    fn calculate_duration(&self) -> String {
        // Parse timestamps and calculate duration
        // For now, return simple placeholder
        "~6 minutes".to_string()
    }

    fn estimate_cost(&self) -> f64 {
        // Rough estimate: $0.003 per 1K input tokens, $0.015 per 1K output tokens
        let input_cost = (self.session.total_tokens.input_tokens as f64 / 1000.0) * 0.003;
        let output_cost = (self.session.total_tokens.output_tokens as f64 / 1000.0) * 0.015;
        input_cost + output_cost
    }

    fn format_timestamp(&self, timestamp: &str) -> String {
        // Parse ISO timestamp and format nicely
        if let Ok(dt) = timestamp.parse::<DateTime<Utc>>() {
            dt.format("%Y-%m-%d %H:%M:%S").to_string()
        } else {
            timestamp.to_string()
        }
    }

    fn format_time_only(&self, timestamp: &str) -> String {
        if let Ok(dt) = timestamp.parse::<DateTime<Utc>>() {
            dt.format("%H:%M:%S").to_string()
        } else {
            timestamp.to_string()
        }
    }

    fn format_number(n: i64) -> String {
        if n >= 1_000_000 {
            format!("{:.1}M", n as f64 / 1_000_000.0)
        } else if n >= 1_000 {
            format!("{:.1}k", n as f64 / 1_000.0)
        } else {
            n.to_string()
        }
    }

    /// Get session timestamp formatted for file/directory names
    fn get_session_timestamp(&self) -> String {
        self.session.start_time
            .replace(':', "-")
            .replace('T', "-")
            .split('.')
            .next()
            .unwrap_or(&self.session.start_time)
            .to_string()
    }
}
