#!/usr/bin/env tsx
import { getTable, tableExists, type Memory } from './lib/db.js';
import { checkLMStudio, getEmbedding } from './lib/embed.js';

interface HookInput {
  session_id: string;
  cwd: string;
  transcript_path: string;
  permission_mode: string;
  hook_event_name: string;
  source: string;
}

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf-8');
}

async function main() {
  const raw = await readStdin();
  const input: HookInput = JSON.parse(raw);
  const { cwd } = input;

  // Skip if no table yet
  if (!await tableExists()) {
    process.exit(0);
  }

  // Check LM Studio
  if (!await checkLMStudio()) {
    console.error('LM Studio not running. Start it with the embedding model loaded.');
    process.exit(2);
  }

  try {
    const table = await getTable();

    // Generate query embedding based on project path
    const queryEmbedding = await getEmbedding(`project context: ${cwd}`);

    // Search for relevant memories in this project
    const results = await table
      .search(queryEmbedding)
      .where(`projectPath = '${cwd}'`)
      .limit(5)
      .toArray() as Memory[];

    // Filter out initialization record
    const memories = results.filter(r => r.id !== 'init' && r.summary);

    if (memories.length > 0) {
      console.log('<previous-context>');
      console.log('## Recent Sessions in This Project\n');
      for (const memory of memories) {
        const date = new Date(memory.createdAt).toLocaleDateString('en-US', {
          month: 'short',
          day: 'numeric',
          year: 'numeric'
        });
        console.log(`### ${date}`);
        console.log(memory.summary);
        if (memory.topics) {
          console.log(`Topics: ${memory.topics}`);
        }
        console.log('');
      }
      console.log('</previous-context>');
    }
  } catch (err) {
    // Non-blocking: if search fails, just continue without memories
    // This handles case where table is empty or schema mismatch
  }

  process.exit(0);
}

main().catch(() => process.exit(0));
