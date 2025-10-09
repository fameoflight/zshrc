use crate::commands::command_trait::CommandTrait;
use crate::utils::{LLMClient, Message};
use anyhow::Result;
use arboard::Clipboard;
use clap::{Arg, ArgMatches};
use crossterm::{
    event::{self, Event, KeyCode, KeyModifiers},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use futures::StreamExt;
use pulldown_cmark::{Event as MarkdownEvent, Parser, Tag};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{Block, Borders, List, ListItem, Paragraph, Wrap},
    Frame, Terminal,
};
use std::io;
use tokio::sync::mpsc;

pub struct LLMChatCommand;

impl CommandTrait for LLMChatCommand {
    fn name() -> &'static str {
        "llm-chat"
    }

    fn help() -> &'static str {
        "Interactive chat with OpenAI-compatible LLM (LM Studio, Ollama, OpenAI, etc.)"
    }

    fn execute(matches: &ArgMatches) -> Result<()> {
        // Parse arguments
        let base_url = matches
            .get_one::<String>("baseurl")
            .map(|s| s.to_string())
            .unwrap_or_else(|| "http://localhost:1234/v1".to_string());

        let api_key = matches.get_one::<String>("apikey").map(|s| s.to_string());

        let model = matches
            .get_one::<String>("model")
            .map(|s| s.to_string())
            .unwrap_or_else(|| "local-model".to_string());

        let temperature = matches
            .get_one::<String>("temperature")
            .and_then(|s| s.parse::<f32>().ok())
            .unwrap_or(0.7);

        let max_tokens = matches
            .get_one::<String>("max-tokens")
            .and_then(|s| s.parse::<i32>().ok());

        let system_prompt = matches
            .get_one::<String>("system-prompt")
            .map(|s| s.to_string());

        // Create LLM client
        let client = LLMClient::new(base_url, api_key, model, temperature, max_tokens);

        // Run TUI
        run_tui(client, system_prompt)?;

        Ok(())
    }

    fn build_command() -> clap::Command {
        clap::Command::new(Self::name())
            .about(Self::help())
            .arg(
                Arg::new("baseurl")
                    .long("baseurl")
                    .help("Custom API base URL (default: http://localhost:1234/v1)")
                    .required(false),
            )
            .arg(
                Arg::new("apikey")
                    .long("apikey")
                    .help("API key for providers that require authentication")
                    .required(false),
            )
            .arg(
                Arg::new("model")
                    .long("model")
                    .help("Model name to use (default: local-model)")
                    .required(false),
            )
            .arg(
                Arg::new("temperature")
                    .long("temperature")
                    .help("Temperature for response randomness (0.0-2.0, default: 0.7)")
                    .required(false),
            )
            .arg(
                Arg::new("max-tokens")
                    .long("max-tokens")
                    .help("Maximum tokens in response")
                    .required(false),
            )
            .arg(
                Arg::new("system-prompt")
                    .long("system-prompt")
                    .help("System prompt to set conversation context")
                    .required(false),
            )
    }
}

struct ChatApp {
    messages: Vec<Message>,
    input: String,
    is_streaming: bool,
    current_response: String,
    error_message: Option<String>,
    scroll_offset: usize,
    clipboard: Option<Clipboard>,
    status_message: Option<String>,
    passthrough_mode: bool,
}

impl ChatApp {
    fn new(system_prompt: Option<String>) -> Self {
        let mut messages = Vec::new();
        if let Some(prompt) = system_prompt {
            messages.push(Message {
                role: "system".to_string(),
                content: prompt,
            });
        }
        let clipboard = Clipboard::new().ok();
        Self {
            messages,
            input: String::new(),
            is_streaming: false,
            current_response: String::new(),
            error_message: None,
            scroll_offset: 0,
            clipboard,
            status_message: None,
            passthrough_mode: false,
        }
    }

    fn add_message(&mut self, role: String, content: String) {
        self.messages.push(Message { role, content });
        self.scroll_offset = 0; // Reset scroll when new message arrives
    }

    fn clear_messages(&mut self) {
        // Keep system message if present
        if !self.messages.is_empty() && self.messages[0].role == "system" {
            self.messages = vec![self.messages[0].clone()];
        } else {
            self.messages.clear();
        }
        self.scroll_offset = 0;
    }

    fn copy_last_response(&mut self) {
        if let Some(clipboard) = &mut self.clipboard {
            // Find last assistant message
            if let Some(last_response) = self
                .messages
                .iter()
                .rev()
                .find(|m| m.role == "assistant")
            {
                match clipboard.set_text(&last_response.content) {
                    Ok(_) => {
                        self.status_message = Some("✓ Copied to clipboard".to_string());
                    }
                    Err(e) => {
                        self.status_message = Some(format!("✗ Copy failed: {}", e));
                    }
                }
            }
        } else {
            self.status_message = Some("✗ Clipboard not available".to_string());
        }
    }

    fn copy_all_conversation(&mut self) {
        if let Some(clipboard) = &mut self.clipboard {
            let conversation = self
                .messages
                .iter()
                .filter(|m| m.role != "system")
                .map(|m| {
                    let role = match m.role.as_str() {
                        "user" => "You",
                        "assistant" => "AI",
                        _ => &m.role,
                    };
                    format!("{}: {}", role, m.content)
                })
                .collect::<Vec<_>>()
                .join("\n\n");

            match clipboard.set_text(&conversation) {
                Ok(_) => {
                    self.status_message = Some("✓ Conversation copied to clipboard".to_string());
                }
                Err(e) => {
                    self.status_message = Some(format!("✗ Copy failed: {}", e));
                }
            }
        } else {
            self.status_message = Some("✗ Clipboard not available".to_string());
        }
    }
}

enum AppEvent {
    StreamChunk(String),
    StreamEnd,
    StreamError(String),
}

/// Parse markdown text into styled Lines for Ratatui with word wrapping
fn parse_markdown_wrapped(text: &str, max_width: usize) -> Vec<Line<'static>> {
    let parser = Parser::new(text);
    let mut lines = Vec::new();
    let mut current_line = Vec::new();
    let mut current_style = Style::default();
    let mut in_code_block = false;
    let mut in_code = false;
    let mut in_bold = false;
    let mut in_italic = false;
    let mut in_heading = false;

    for event in parser {
        match event {
            MarkdownEvent::Start(tag) => match tag {
                Tag::CodeBlock(_) => {
                    if !current_line.is_empty() {
                        lines.push(Line::from(current_line.clone()));
                        current_line.clear();
                    }
                    in_code_block = true;
                    current_style = Style::default().fg(Color::Cyan);
                }
                Tag::Heading { .. } => {
                    in_heading = true;
                    current_style = Style::default()
                        .fg(Color::Yellow)
                        .add_modifier(Modifier::BOLD);
                }
                Tag::Emphasis => {
                    in_italic = true;
                    current_style = current_style.add_modifier(Modifier::ITALIC);
                }
                Tag::Strong => {
                    in_bold = true;
                    current_style = current_style.add_modifier(Modifier::BOLD);
                }
                Tag::Link { .. } => {
                    current_style = current_style.fg(Color::Blue).add_modifier(Modifier::UNDERLINED);
                }
                _ => {}
            },
            MarkdownEvent::End(tag) => match tag {
                Tag::CodeBlock(_) => {
                    if !current_line.is_empty() {
                        lines.push(Line::from(current_line.clone()));
                        current_line.clear();
                    }
                    in_code_block = false;
                    current_style = Style::default();
                }
                Tag::Heading { .. } => {
                    if !current_line.is_empty() {
                        lines.push(Line::from(current_line.clone()));
                        current_line.clear();
                    }
                    lines.push(Line::from(""));
                    in_heading = false;
                    current_style = Style::default();
                }
                Tag::Emphasis => {
                    in_italic = false;
                    current_style = current_style.remove_modifier(Modifier::ITALIC);
                }
                Tag::Strong => {
                    in_bold = false;
                    current_style = current_style.remove_modifier(Modifier::BOLD);
                }
                Tag::Link { .. } => {
                    current_style = Style::default();
                }
                Tag::Paragraph => {
                    if !current_line.is_empty() {
                        lines.push(Line::from(current_line.clone()));
                        current_line.clear();
                    }
                    lines.push(Line::from(""));
                }
                _ => {}
            },
            MarkdownEvent::Text(text) => {
                let style = if in_code_block {
                    Style::default().fg(Color::Cyan)
                } else if in_code {
                    Style::default().fg(Color::Green)
                } else {
                    current_style
                };

                // Handle code blocks - add indentation
                if in_code_block {
                    for line in text.lines() {
                        // Wrap long code lines
                        let formatted = format!("  {}", line);
                        if formatted.len() > max_width {
                            let mut remaining = formatted.as_str();
                            while !remaining.is_empty() {
                                let end = remaining.len().min(max_width);
                                current_line.push(Span::styled(remaining[..end].to_string(), style));
                                lines.push(Line::from(current_line.clone()));
                                current_line.clear();
                                remaining = &remaining[end..];
                            }
                        } else {
                            current_line.push(Span::styled(formatted, style));
                            lines.push(Line::from(current_line.clone()));
                            current_line.clear();
                        }
                    }
                } else {
                    // Word wrap for normal text
                    let words = text.split_whitespace();
                    let mut line_length = current_line.iter().map(|s| s.content.len()).sum::<usize>();

                    for word in words {
                        let word_len = word.len() + 1; // +1 for space
                        if line_length + word_len > max_width && !current_line.is_empty() {
                            lines.push(Line::from(current_line.clone()));
                            current_line.clear();
                            line_length = 0;
                        }
                        current_line.push(Span::styled(format!("{} ", word), style));
                        line_length += word_len;
                    }
                }
            }
            MarkdownEvent::Code(code) => {
                current_line.push(Span::styled(
                    format!("`{}`", code),
                    Style::default().fg(Color::Green),
                ));
            }
            MarkdownEvent::SoftBreak | MarkdownEvent::HardBreak => {
                if !current_line.is_empty() {
                    lines.push(Line::from(current_line.clone()));
                    current_line.clear();
                }
            }
            _ => {}
        }
    }

    // Push remaining line
    if !current_line.is_empty() {
        lines.push(Line::from(current_line));
    }

    lines
}

#[tokio::main]
async fn run_tui(client: LLMClient, system_prompt: Option<String>) -> Result<()> {
    // Setup terminal - don't capture mouse to allow text selection
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = ChatApp::new(system_prompt);
    let (tx, mut rx) = mpsc::unbounded_channel::<AppEvent>();

    let result = loop {
        // In passthrough mode, show plain text and allow terminal selection
        if app.passthrough_mode {
            // Restore terminal temporarily
            disable_raw_mode()?;
            execute!(
                terminal.backend_mut(),
                LeaveAlternateScreen
            )?;
            terminal.show_cursor()?;

            // Print conversation in plain text
            println!("\n╔══════════════════════════════════════════════════════════════╗");
            println!("║  PASSTHROUGH MODE - You can now select and copy text        ║");
            println!("║  Press Enter to return to interactive mode                  ║");
            println!("╚══════════════════════════════════════════════════════════════╝\n");

            for msg in &app.messages {
                if msg.role == "system" {
                    continue;
                }
                let prefix = match msg.role.as_str() {
                    "user" => "You",
                    "assistant" => "AI",
                    _ => &msg.role,
                };
                println!("{}: {}\n", prefix, msg.content);
            }

            println!("\n[Press Enter to return to interactive mode]");

            // Wait for Enter key
            let mut input = String::new();
            std::io::stdin().read_line(&mut input)?;

            // Re-enter TUI mode
            enable_raw_mode()?;
            execute!(
                terminal.backend_mut(),
                EnterAlternateScreen
            )?;
            app.passthrough_mode = false;
            app.status_message = Some("✓ Returned to interactive mode".to_string());
            continue;
        }

        terminal.draw(|f| ui(f, &app))?;

        // Handle events
        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                        break Ok(());
                    }
                    KeyCode::Char('l') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                        app.clear_messages();
                        app.error_message = None;
                        app.status_message = None;
                    }
                    KeyCode::Char('y') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                        app.copy_last_response();
                    }
                    KeyCode::Char('a') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                        app.copy_all_conversation();
                    }
                    KeyCode::Char('p') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                        app.passthrough_mode = true;
                    }
                    KeyCode::Enter if !app.is_streaming && !app.input.is_empty() => {
                        let user_message = app.input.clone();
                        app.input.clear();
                        app.add_message("user".to_string(), user_message.clone());
                        app.is_streaming = true;
                        app.current_response.clear();
                        app.error_message = None;

                        // Start streaming in background
                        let client_clone = client.clone();
                        let messages_clone = app.messages.clone();
                        let tx_clone = tx.clone();

                        tokio::spawn(async move {
                            match stream_response(client_clone, messages_clone, tx_clone).await {
                                Ok(_) => {}
                                Err(e) => {
                                    // Error already sent via channel
                                    eprintln!("Stream error: {}", e);
                                }
                            }
                        });
                    }
                    KeyCode::Char(c) if !app.is_streaming => {
                        app.input.push(c);
                        app.status_message = None; // Clear status when typing
                    }
                    KeyCode::Backspace if !app.is_streaming => {
                        app.input.pop();
                    }
                    KeyCode::Up => {
                        app.scroll_offset = app.scroll_offset.saturating_add(1);
                    }
                    KeyCode::Down => {
                        app.scroll_offset = app.scroll_offset.saturating_sub(1);
                    }
                    KeyCode::PageUp => {
                        app.scroll_offset = app.scroll_offset.saturating_add(10);
                    }
                    KeyCode::PageDown => {
                        app.scroll_offset = app.scroll_offset.saturating_sub(10);
                    }
                    _ => {}
                }
            }
        }

        // Handle stream events
        while let Ok(event) = rx.try_recv() {
            match event {
                AppEvent::StreamChunk(chunk) => {
                    app.current_response.push_str(&chunk);
                }
                AppEvent::StreamEnd => {
                    app.add_message("assistant".to_string(), app.current_response.clone());
                    app.current_response.clear();
                    app.is_streaming = false;
                }
                AppEvent::StreamError(error) => {
                    app.error_message = Some(error);
                    app.is_streaming = false;
                    app.current_response.clear();
                }
            }
        }
    };

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen
    )?;
    terminal.show_cursor()?;

    result
}

async fn stream_response(
    client: LLMClient,
    messages: Vec<Message>,
    tx: mpsc::UnboundedSender<AppEvent>,
) -> Result<()> {
    match client.stream_chat(messages).await {
        Ok(mut stream) => {
            while let Some(result) = stream.next().await {
                match result {
                    Ok(chunk) => {
                        if tx.send(AppEvent::StreamChunk(chunk)).is_err() {
                            break; // Channel closed
                        }
                    }
                    Err(e) => {
                        let _ = tx.send(AppEvent::StreamError(e.to_string()));
                        return Err(e);
                    }
                }
            }
            let _ = tx.send(AppEvent::StreamEnd);
            Ok(())
        }
        Err(e) => {
            let _ = tx.send(AppEvent::StreamError(e.to_string()));
            Err(e)
        }
    }
}

fn ui(f: &mut Frame, app: &ChatApp) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),      // Header
            Constraint::Min(0),         // Messages
            Constraint::Length(3),      // Input
            Constraint::Length(2),      // Status bar
        ])
        .split(f.size());

    // Header
    let header = Paragraph::new("🤖 LLM Chat")
        .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
        .block(Block::default().borders(Borders::ALL).title("Header"));
    f.render_widget(header, chunks[0]);

    // Messages
    render_messages(f, app, chunks[1]);

    // Input box
    let input_text = if app.is_streaming {
        "[Streaming response...]".to_string()
    } else {
        format!("> {}_", app.input)
    };

    let input = Paragraph::new(input_text)
        .style(Style::default().fg(Color::Yellow))
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Input (Ctrl+C quit | Ctrl+L clear | Ctrl+Y copy last | Ctrl+A copy all | Ctrl+P select text)"),
        );
    f.render_widget(input, chunks[2]);

    // Status bar
    render_status_bar(f, app, chunks[3]);
}

fn render_messages(f: &mut Frame, app: &ChatApp, area: Rect) {
    let mut items = Vec::new();
    let max_width = area.width.saturating_sub(4) as usize; // Account for borders and padding

    // Show conversation history
    for msg in &app.messages {
        if msg.role == "system" {
            continue; // Don't show system messages in the chat
        }

        let (prefix, color) = match msg.role.as_str() {
            "user" => ("You", Color::Green),
            "assistant" => ("AI", Color::Blue),
            _ => ("?", Color::Gray),
        };

        // Header with role
        let mut message_lines = vec![Line::from(Span::styled(
            format!("{}: ", prefix),
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ))];

        // Parse and render markdown for assistant messages with wrapping
        if msg.role == "assistant" {
            let markdown_lines = parse_markdown_wrapped(&msg.content, max_width);
            message_lines.extend(markdown_lines);
        } else {
            // Word wrap for user messages
            let words = msg.content.split_whitespace();
            let mut current_line = String::new();
            for word in words {
                if current_line.len() + word.len() + 1 > max_width && !current_line.is_empty() {
                    message_lines.push(Line::from(current_line.clone()));
                    current_line.clear();
                }
                if !current_line.is_empty() {
                    current_line.push(' ');
                }
                current_line.push_str(word);
            }
            if !current_line.is_empty() {
                message_lines.push(Line::from(current_line));
            }
        }

        message_lines.push(Line::from(""));
        items.push(ListItem::new(message_lines));
    }

    // Show streaming response with markdown
    if app.is_streaming && !app.current_response.is_empty() {
        let mut streaming_lines = vec![Line::from(Span::styled(
            "AI: ",
            Style::default()
                .fg(Color::Blue)
                .add_modifier(Modifier::BOLD),
        ))];

        // Parse markdown for streaming response too
        let markdown_lines = parse_markdown_wrapped(&format!("{}▌", app.current_response), max_width);
        streaming_lines.extend(markdown_lines);
        streaming_lines.push(Line::from(""));

        items.push(ListItem::new(streaming_lines));
    } else if app.is_streaming {
        items.push(ListItem::new(Line::from(Span::styled(
            "🤔 Thinking...",
            Style::default().fg(Color::Gray),
        ))));
    }

    let messages_list = List::new(items).block(
        Block::default()
            .borders(Borders::ALL)
            .title("Conversation"),
    );

    f.render_widget(messages_list, area);
}

fn render_status_bar(f: &mut Frame, app: &ChatApp, area: Rect) {
    let status_text = if let Some(status_msg) = &app.status_message {
        status_msg.clone()
    } else if let Some(error) = &app.error_message {
        format!("❌ Error: {}", error)
    } else if app.is_streaming {
        "🔄 Streaming response...".to_string()
    } else {
        format!(
            "💬 Messages: {} | ⬆️⬇️ Scroll | Enter: Send",
            app.messages.len()
        )
    };

    let status = Paragraph::new(status_text).style(
        if app.status_message.is_some() {
            Style::default().fg(Color::Green)
        } else if app.error_message.is_some() {
            Style::default().fg(Color::Red)
        } else if app.is_streaming {
            Style::default().fg(Color::Yellow)
        } else {
            Style::default().fg(Color::Gray)
        },
    );

    f.render_widget(status, area);
}
