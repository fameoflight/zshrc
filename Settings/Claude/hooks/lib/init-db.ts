#!/usr/bin/env tsx
import { tableExists, createTable } from './db.js';
import { checkLMStudio, getEmbedding } from './embed.js';

async function main() {
  console.log('Initializing Claude memory database...');

  // Check if table already exists
  if (await tableExists()) {
    console.log('Memory table already exists. Skipping initialization.');
    return;
  }

  // Check LM Studio availability
  if (!await checkLMStudio()) {
    console.error('LM Studio not running at http://127.0.0.1:1234');
    console.error('Please start LM Studio with text-embedding-nomic-embed-text-v1.5 model loaded.');
    process.exit(1);
  }

  // Create table with sample embedding to establish schema
  console.log('Generating sample embedding for schema...');
  const sampleVector = await getEmbedding('initialization');

  console.log('Creating memories table...');
  await createTable(sampleVector);

  console.log('Memory database initialized successfully!');
}

main().catch((err) => {
  console.error('Failed to initialize memory database:', err);
  process.exit(1);
});
