use anyhow::{Context, Result};
use openai::{
    chat::{ChatCompletion, ChatCompletionMessage, ChatCompletionMessageRole},
    Credentials,
};
use tokio_stream::wrappers::ReceiverStream;
use tokio_stream::StreamExt;

#[derive(Debug, Clone)]
pub struct Message {
    pub role: String,
    pub content: String,
}

impl From<Message> for ChatCompletionMessage {
    fn from(msg: Message) -> Self {
        let role = match msg.role.as_str() {
            "system" => ChatCompletionMessageRole::System,
            "user" => ChatCompletionMessageRole::User,
            "assistant" => ChatCompletionMessageRole::Assistant,
            _ => ChatCompletionMessageRole::User,
        };

        ChatCompletionMessage {
            role,
            content: Some(msg.content),
            name: None,
            function_call: None,
            tool_calls: None,
            tool_call_id: None,
        }
    }
}

impl From<ChatCompletionMessage> for Message {
    fn from(msg: ChatCompletionMessage) -> Self {
        let role = match msg.role {
            ChatCompletionMessageRole::System => "system",
            ChatCompletionMessageRole::User => "user",
            ChatCompletionMessageRole::Assistant => "assistant",
            ChatCompletionMessageRole::Function => "function",
            ChatCompletionMessageRole::Tool => "tool",
            ChatCompletionMessageRole::Developer => "developer",
        };

        Message {
            role: role.to_string(),
            content: msg.content.unwrap_or_default(),
        }
    }
}

pub struct LLMClient {
    credentials: Credentials,
    model: String,
    temperature: f32,
    max_tokens: Option<u16>,
}

impl LLMClient {
    pub fn new(
        base_url: String,
        api_key: Option<String>,
        model: String,
        temperature: f32,
        max_tokens: Option<i32>,
    ) -> Self {
        // Create credentials with base URL and API key
        let credentials = Credentials::new(
            api_key.unwrap_or_else(|| "dummy-key".to_string()),
            base_url,
        );

        Self {
            credentials,
            model,
            temperature,
            max_tokens: max_tokens.map(|t| t as u16),
        }
    }

    pub fn lm_studio_default() -> Self {
        Self::new(
            "http://localhost:1234/v1".to_string(),
            None,
            "local-model".to_string(),
            0.7,
            None,
        )
    }

    pub async fn stream_chat(
        &self,
        messages: Vec<Message>,
    ) -> Result<impl futures::Stream<Item = Result<String>>> {
        let openai_messages: Vec<ChatCompletionMessage> =
            messages.into_iter().map(|m| m.into()).collect();

        let mut builder = ChatCompletion::builder(&self.model, openai_messages)
            .credentials(self.credentials.clone())
            .temperature(self.temperature)
            .stream(true);

        if let Some(max_tokens) = self.max_tokens {
            builder = builder.max_tokens(max_tokens);
        }

        let stream = builder
            .create_stream()
            .await
            .context("Failed to create chat stream")?;

        // Convert Receiver to Stream using ReceiverStream
        let receiver_stream = ReceiverStream::new(stream);

        let content_stream = receiver_stream
            .filter_map(|response| {
                // Extract content from the first choice's delta
                // Filter out chunks without content (e.g., role-only chunks)
                response
                    .choices
                    .first()
                    .and_then(|choice| choice.delta.content.clone())
            })
            .map(Ok);

        Ok(content_stream)
    }

    pub async fn chat(&self, messages: Vec<Message>) -> Result<Message> {
        let openai_messages: Vec<ChatCompletionMessage> =
            messages.into_iter().map(|m| m.into()).collect();

        let mut builder = ChatCompletion::builder(&self.model, openai_messages)
            .credentials(self.credentials.clone())
            .temperature(self.temperature);

        if let Some(max_tokens) = self.max_tokens {
            builder = builder.max_tokens(max_tokens);
        }

        let response = builder
            .create()
            .await
            .context("Failed to create chat completion")?;

        let message = response
            .choices
            .first()
            .context("No response from API")?
            .message
            .clone();

        Ok(message.into())
    }
}

impl Clone for LLMClient {
    fn clone(&self) -> Self {
        Self {
            credentials: self.credentials.clone(),
            model: self.model.clone(),
            temperature: self.temperature,
            max_tokens: self.max_tokens,
        }
    }
}
