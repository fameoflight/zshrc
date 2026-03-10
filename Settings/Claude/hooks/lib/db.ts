import * as lancedb from '@lancedb/lancedb';
import { homedir } from 'os';
import { join } from 'path';

export interface Memory {
  id: string;
  sessionId: string;
  projectPath: string;
  summary: string;
  topics: string;
  createdAt: string;
  fullTranscript?: string;
  vector: number[];
}

const DB_PATH = join(homedir(), '.claude', 'memory', 'memories.lance');
const TABLE_NAME = 'memories';

let dbInstance: lancedb.Connection | null = null;

export async function getDb(): Promise<lancedb.Connection> {
  if (!dbInstance) {
    dbInstance = await lancedb.connect(DB_PATH);
  }
  return dbInstance;
}

export async function getTable(): Promise<lancedb.Table> {
  const db = await getDb();
  return db.openTable(TABLE_NAME);
}

export async function tableExists(): Promise<boolean> {
  try {
    const db = await getDb();
    const tables = await db.tableNames();
    return tables.includes(TABLE_NAME);
  } catch {
    return false;
  }
}

export async function createTable(sampleVector: number[]): Promise<lancedb.Table> {
  const db = await getDb();

  const initialRecord: Memory = {
    id: 'init',
    sessionId: 'init',
    projectPath: '/init',
    summary: 'Initialization record',
    topics: '',
    createdAt: new Date().toISOString(),
    vector: sampleVector
  };

  return db.createTable(TABLE_NAME, [initialRecord]);
}
