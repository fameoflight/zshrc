// Data models for Claude Code session transcripts

use serde::{Deserialize, Serialize};

/// Top-level transcript entry - handles all known types plus unknown variants
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "type", rename_all = "kebab-case")]
pub enum TranscriptEntry {
    #[serde(rename = "user")]
    User(UserTranscriptEntry),
    #[serde(rename = "assistant")]
    Assistant(AssistantTranscriptEntry),
    #[serde(rename = "system")]
    System(SystemTranscriptEntry),
    #[serde(rename = "summary")]
    Summary(SummaryTranscriptEntry),
    #[serde(rename = "file-history-snapshot")]
    FileHistorySnapshot(FileHistoryEntry),
    /// Catch-all for any other entry types we don't explicitly handle
    #[serde(other)]
    Unknown,
}

/// User message entry
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserTranscriptEntry {
    #[serde(default)]
    pub uuid: String,
    #[serde(default)]
    pub session_id: String,
    #[serde(default)]
    pub timestamp: String,
    #[serde(default)]
    pub cwd: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub git_branch: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<UserMessage>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parent_uuid: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub is_sidechain: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_use_result: Option<serde_json::Value>,
}

/// Assistant message entry
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AssistantTranscriptEntry {
    #[serde(default)]
    pub uuid: String,
    #[serde(default)]
    pub session_id: String,
    #[serde(default)]
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<AssistantMessage>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parent_uuid: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub is_sidechain: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cwd: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub git_branch: Option<String>,
}

/// System message entry
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemTranscriptEntry {
    #[serde(default)]
    pub uuid: String,
    #[serde(default)]
    pub session_id: String,
    #[serde(default)]
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parent_uuid: Option<String>,
}

/// Summary entry (async-generated session summaries)
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SummaryTranscriptEntry {
    #[serde(default)]
    pub uuid: String,
    #[serde(default)]
    pub session_id: String,
    #[serde(default)]
    pub timestamp: String,
    #[serde(default)]
    pub summary: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub leaf_uuid: Option<String>,
}

/// File history snapshot entry
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FileHistoryEntry {
    pub message_id: String,
    pub snapshot: serde_json::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub is_snapshot_update: Option<bool>,
}

/// User message content
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct UserMessage {
    pub role: String,
    pub content: UserContent,
}

/// User message content - can be string or array of content items
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(untagged)]
pub enum UserContent {
    Text(String),
    ContentBlocks(Vec<ContentBlock>),
}

/// Assistant message from API
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct AssistantMessage {
    pub id: String,
    #[serde(rename = "type")]
    pub message_type: String,
    pub role: String,
    pub model: String,
    pub content: Vec<ContentBlock>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stop_reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stop_sequence: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub usage: Option<Usage>,
}

/// Content block in a message
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ContentBlock {
    Text {
        text: String,
    },
    ToolUse {
        id: String,
        name: String,
        input: serde_json::Value,
    },
    ToolResult {
        tool_use_id: String,
        content: ToolResultContent,
        #[serde(skip_serializing_if = "Option::is_none")]
        is_error: Option<bool>,
    },
    Thinking {
        thinking: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        signature: Option<String>,
    },
    Image {
        source: ImageSource,
    },
}

/// Tool result content - can be string or structured content
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(untagged)]
pub enum ToolResultContent {
    Text(String),
    Structured(Vec<serde_json::Value>),
}

/// Image source
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ImageSource {
    #[serde(rename = "type")]
    pub source_type: String,
    pub media_type: String,
    pub data: String,
}

/// Token usage information
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Usage {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub input_tokens: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_tokens: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cache_creation_input_tokens: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cache_read_input_tokens: Option<i64>,
}

/// Session - aggregated view of a conversation
#[derive(Debug, Clone)]
pub struct Session {
    pub session_id: String,
    pub project_name: String,
    pub project_path: String,
    pub git_branch: Option<String>,
    pub messages: Vec<Message>,
    pub start_time: String,
    pub end_time: String,
    pub total_tokens: TokenStats,
    pub file_map: std::collections::HashMap<String, String>, // hash -> file path
}

/// Unified message type for export
#[derive(Debug, Clone)]
pub struct Message {
    pub uuid: String,
    pub timestamp: String,
    pub role: MessageRole,
    pub content: MessageContent,
}

#[derive(Debug, Clone, PartialEq)]
pub enum MessageRole {
    User,
    Assistant,
}

#[derive(Debug, Clone)]
pub enum MessageContent {
    User {
        text: String,
        tool_results: Vec<ToolResult>,
    },
    Assistant {
        model: String,
        text_blocks: Vec<String>,
        tool_uses: Vec<ToolUse>,
        thinking_blocks: Vec<String>,
        usage: Option<Usage>,
    },
}

#[derive(Debug, Clone)]
pub struct ToolUse {
    pub id: String,
    pub name: String,
    pub input: serde_json::Value,
}

#[derive(Debug, Clone)]
pub struct ToolResult {
    pub tool_use_id: String,
    pub content: String,
    pub is_error: bool,
}

#[derive(Debug, Clone, Default)]
pub struct TokenStats {
    pub input_tokens: i64,
    pub output_tokens: i64,
    pub cache_creation_tokens: i64,
    pub cache_read_tokens: i64,
}

impl TokenStats {
    pub fn total(&self) -> i64 {
        self.input_tokens + self.output_tokens
    }

    pub fn add(&mut self, usage: &Usage) {
        self.input_tokens += usage.input_tokens.unwrap_or(0);
        self.output_tokens += usage.output_tokens.unwrap_or(0);
        self.cache_creation_tokens += usage.cache_creation_input_tokens.unwrap_or(0);
        self.cache_read_tokens += usage.cache_read_input_tokens.unwrap_or(0);
    }
}
