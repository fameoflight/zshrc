# AI Scripts

Scripts for interacting with local LLMs and OpenAI-compatible APIs.

## 🤖 chat

Interactive chat with a local LLM (LM Studio, Ollama, etc.)

### Usage

```bash
# Basic usage (uses localhost:1234 by default)
bun run src/cli.ts ai chat

# With custom system prompt
bun run src/cli.ts ai chat --system "You are a helpful coding assistant"

# Adjust temperature
bun run src/cli.ts ai chat --temperature 0.9

# Disable streaming
bun run src/cli.ts ai chat --no-stream
```

### Features

- **Model Selection** - Browse and select from available models
- **Streaming Responses** - See AI responses as they're generated
- **Conversation History** - Maintains context throughout the session
- **Commands**:
  - `exit`, `quit` - Exit the chat
  - `clear`, `reset` - Clear conversation history
  - `save`, `export` - Save conversation to JSON
  - `help` - Show help message

### Requirements

A running LLM server with OpenAI-compatible API:
- **LM Studio**: http://localhost:1234/v1
- **Ollama**: http://localhost:11434/v1
- **Text Generation WebUI**: http://localhost:5000/v1

## 🔧 Creating AI Scripts

Extend the `AIScript` base class to create new AI-powered utilities:

```typescript
import { Script } from "../../core/decorators/Script";
import { AIScript } from "../../core/base/AIScript";
import type { Context } from "../../core/types";

@Script({
  emoji: "✨",
  args: {
    prompt: { type: "string", position: 0, required: true }
  }
})
export class MyAIScript extends AIScript {
  async run(ctx: Context): Promise<void> {
    // Access OpenAI service via this.openai
    const models = await this.openai.listModels();

    // Use helper to get models
    const models = await this.getAvailableModels();

    // Chat with the AI
    const response = await this.openai.chat({
      model: "llama-3.2-3b-instruct",
      messages: [
        this.createMessage("user", ctx.args.prompt)
      ]
    });

    console.log(response);
  }
}
```

## 📚 OpenAI Service API

The `OpenAIService` provides these methods:

### List Models
```typescript
const models = await openai.listModels();
// Returns: ModelInfo[]
```

### Chat (non-streaming)
```typescript
const response = await openai.chat({
  model: "model-name",
  messages: [{ role: "user", content: "Hello!" }],
  temperature: 0.7,
  maxTokens: 1000
});
```

### Chat (streaming)
```typescript
for await (const chunk of openai.chatStream({
  model: "model-name",
  messages: [...],
  temperature: 0.7
})) {
  process.stdout.write(chunk);
}
```

### Completions
```typescript
const text = await openai.complete({
  model: "model-name",
  prompt: "Once upon a time",
  temperature: 0.8
});
```

### Embeddings
```typescript
const embeddings = await openai.createEmbedding({
  model: "text-embedding-ada-002",
  input: ["text to embed", "another text"]
});
```

### Test Connection
```typescript
const connected = await openai.testConnection();
```

## 🔑 Configuration

The OpenAI service is configured in the CLI runner with defaults:
- **Base URL**: `http://localhost:1234/v1`
- **API Key**: `not-required`

Override in your scripts via arguments or environment variables.
