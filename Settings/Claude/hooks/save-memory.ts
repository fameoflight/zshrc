#!/usr/bin/env tsx
import { readFileSync } from 'fs';
import { getTable, tableExists, createTable, type Memory } from './lib/db.js';
import { checkLMStudio, getEmbedding } from './lib/embed.js';

interface HookInput {
  session_id: string;
  cwd: string;
  transcript_path: string;
  permission_mode: string;
  hook_event_name: string;
  reason: string;
}

interface TranscriptMessage {
  role: string;
  content?: string | Array<{ type: string; text?: string }>;
  tool_use?: { name: string };
}

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf-8');
}

function extractTextContent(message: TranscriptMessage): string {
  if (typeof message.content === 'string') {
    return message.content;
  }
  if (Array.isArray(message.content)) {
    return message.content
      .filter(c => c.type === 'text' && c.text)
      .map(c => c.text)
      .join(' ');
  }
  return '';
}

function extractTopics(messages: TranscriptMessage[]): string {
  const topics = new Set<string>();

  // Look for patterns in the conversation
  const patterns = [
    /(?:implement|add|create|build)\s+(\w+(?:\s+\w+)?)/gi,
    /(?:fix|debug|resolve)\s+(\w+(?:\s+\w+)?)/gi,
    /(?:refactor|update|modify)\s+(\w+(?:\s+\w+)?)/gi,
  ];

  for (const msg of messages) {
    const text = extractTextContent(msg);
    for (const pattern of patterns) {
      const matches = text.matchAll(pattern);
      for (const match of matches) {
        if (match[1] && match[1].length > 2) {
          topics.add(match[1].toLowerCase());
        }
      }
    }
  }

  // Also extract tool names used
  for (const msg of messages) {
    if (msg.tool_use?.name) {
      topics.add(`tool:${msg.tool_use.name}`);
    }
  }

  return Array.from(topics).slice(0, 10).join(', ');
}

function generateSummary(messages: TranscriptMessage[], compress: boolean): string {
  const userMessages = messages.filter(m => m.role === 'user');
  const assistantMessages = messages.filter(m => m.role === 'assistant');

  if (compress) {
    // Compressed summary: just key actions
    const actions: string[] = [];

    for (const msg of assistantMessages) {
      const text = extractTextContent(msg);
      // Extract action-oriented sentences
      const actionPatterns = [
        /I(?:'ll|'ve| have| will)\s+([^.!?]+[.!?])/gi,
        /(?:Created|Updated|Fixed|Implemented|Added|Removed|Refactored)\s+([^.!?]+[.!?])/gi,
      ];
      for (const pattern of actionPatterns) {
        const matches = text.matchAll(pattern);
        for (const match of matches) {
          if (match[0].length > 10 && match[0].length < 200) {
            actions.push(match[0].trim());
          }
        }
      }
    }

    if (actions.length > 0) {
      return `Session summary:\n- ${actions.slice(0, 5).join('\n- ')}`;
    }

    // Fallback: first user message
    const firstUser = userMessages[0];
    if (firstUser) {
      const text = extractTextContent(firstUser);
      return `User request: ${text.slice(0, 300)}${text.length > 300 ? '...' : ''}`;
    }

    return 'Session with multiple exchanges';
  }

  // Full summary: include more context
  const parts: string[] = [];

  // First user message (the request)
  const firstUser = userMessages[0];
  if (firstUser) {
    const text = extractTextContent(firstUser);
    parts.push(`Request: ${text.slice(0, 500)}`);
  }

  // Key actions from assistant
  const actions: string[] = [];
  for (const msg of assistantMessages.slice(0, 3)) {
    const text = extractTextContent(msg);
    if (text.length > 50) {
      actions.push(text.slice(0, 200));
    }
  }
  if (actions.length > 0) {
    parts.push(`\nActions:\n- ${actions.join('\n- ')}`);
  }

  return parts.join('\n');
}

async function main() {
  const raw = await readStdin();
  const input: HookInput = JSON.parse(raw);
  const { session_id, cwd, transcript_path, reason } = input;

  // Skip if session was cleared
  if (reason === 'clear') {
    process.exit(0);
  }

  // Read transcript
  let lines: string[];
  try {
    const content = readFileSync(transcript_path, 'utf-8');
    lines = content.split('\n').filter(Boolean);
  } catch {
    // Can't read transcript, skip
    process.exit(0);
  }

  const messages: TranscriptMessage[] = lines.map(line => {
    try {
      return JSON.parse(line);
    } catch {
      return { role: 'unknown' };
    }
  }).filter(m => m.role !== 'unknown');

  // Apply discretion: skip trivial sessions
  const meaningfulMessages = messages.filter(m =>
    m.role === 'user' || m.role === 'assistant'
  );
  if (meaningfulMessages.length < 3) {
    process.exit(0);
  }

  // Check LM Studio
  if (!await checkLMStudio()) {
    console.error('LM Studio not running. Memory not saved.');
    process.exit(2);
  }

  // Determine if we should compress
  const shouldCompress = meaningfulMessages.length > 10;

  // Generate summary
  const summary = generateSummary(messages, shouldCompress);
  const topics = extractTopics(messages);

  // Generate embedding
  const embeddingText = `${summary}\n\nTopics: ${topics}\n\nProject: ${cwd}`;
  const vector = await getEmbedding(embeddingText);

  // Ensure table exists
  let table;
  if (!await tableExists()) {
    table = await createTable(vector);
  } else {
    table = await getTable();
  }

  // Create memory record
  const memory: Memory = {
    id: crypto.randomUUID(),
    sessionId: session_id,
    projectPath: cwd,
    summary,
    topics,
    createdAt: new Date().toISOString(),
    fullTranscript: shouldCompress ? undefined : JSON.stringify(messages.slice(0, 20)),
    vector
  };

  await table.add([memory]);

  process.exit(0);
}

main().catch(() => process.exit(0));
