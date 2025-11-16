/**
 * Core types for the script system
 */

/**
 * Script execution context
 * Contains all dependencies and parsed arguments
 */
export interface Context {
  // Parsed arguments (typed based on @Script config)
  args: Record<string, any>;

  // Core utilities (always available)
  logger: Logger;
  shell: ShellExecutor;
  fs: FileSystem;

  // Service dependencies (injected based on base class)
  git?: GitService;
  xcode?: XcodeService;
  openai?: OpenAIService;

  // Helper methods
  prompt(message: string, defaultValue?: string): Promise<string>;
  confirm(message: string): Promise<boolean>;
  select<T>(items: T[], display?: (item: T) => string): Promise<T | null>;
}

/**
 * Logger interface
 */
export interface Logger {
  info(message: string): void;
  success(message: string): void;
  warn(message: string): void;
  error(message: string): void;
  progress(message: string): void;
  section(title: string): void;
  banner(title: string): void;
  debug(message: string): void;
}

/**
 * Shell executor interface
 */
export interface ShellExecutor {
  exec(params: {
    command: string;
    description?: string;
    silent?: boolean;
    cwd?: string;
  }): Promise<ExecResult>;

  execOrThrow(command: string, errorMessage?: string): Promise<string>;
  commandExists(command: string): boolean;
}

/**
 * Shell execution result
 */
export interface ExecResult {
  success: boolean;
  stdout: string;
  stderr: string;
  exitCode: number;
}

/**
 * File system interface
 */
export interface FileSystem {
  exists(path: string): Promise<boolean>;
  isDirectory(path: string): Promise<boolean>;
  isFile(path: string): Promise<boolean>;
  readFile(path: string): Promise<string>;
  writeFile(path: string, content: string): Promise<void>;
  stat(path: string): Promise<FileStats>;
  glob(params: { pattern: string; cwd?: string; ignore?: string[] }): Promise<string[]>;
}

/**
 * File stats
 */
export interface FileStats {
  size: number;
  isFile: boolean;
  isDirectory: boolean;
  mtime: Date;
}

/**
 * Git service interface
 */
export interface GitService {
  validateRepository(): Promise<void>;
  getChangedFiles(params: { directory?: string; staged?: boolean }): Promise<GitFile[]>;
  stageFiles(params: { paths: string[] }): Promise<void>;
  commit(params: { message: string; noVerify?: boolean; amend?: boolean }): Promise<CommitInfo>;
  getCommitInfo(params: { ref: string }): Promise<CommitInfo>;
}

/**
 * Git file
 */
export interface GitFile {
  path: string;
  status: string;
  staged: boolean;
}

/**
 * Commit information
 */
export interface CommitInfo {
  hash: string;
  author: string;
  email: string;
  subject: string;
  date: Date;
}

/**
 * Xcode service interface (placeholder)
 */
export interface XcodeService {
  validateProject(): Promise<void>;
}

/**
 * OpenAI service interface
 */
export interface OpenAIService {
  baseURL: string;
  listModels(): Promise<any[]>;
  getModel(modelId: string): Promise<any | null>;
  chat(params: {
    model: string;
    messages: any[];
    temperature?: number;
    maxTokens?: number;
  }): Promise<string>;
  chatStream(params: {
    model: string;
    messages: any[];
    temperature?: number;
    maxTokens?: number;
  }): AsyncGenerator<string, void, unknown>;
  complete(params: {
    model: string;
    prompt: string;
    temperature?: number;
    maxTokens?: number;
  }): Promise<string>;
  createEmbedding(params: { model: string; input: string | string[] }): Promise<number[][]>;
  testConnection(): Promise<boolean>;
}

/**
 * Script metadata extracted from decorator and JSDoc
 */
export interface ScriptMetadata {
  // From decorator
  emoji?: string;
  tags?: string[];
  args: Record<string, ArgumentConfig>;

  // From file system conventions
  category: string;
  command: string;

  // From JSDoc
  description?: string;
  examples?: string[];
}

/**
 * Argument configuration
 */
export interface ArgumentConfig {
  // Type
  type: "string" | "integer" | "number" | "boolean" | "array";

  // Position or flag
  position?: number;
  flag?: string;

  // Basic config
  required?: boolean;
  default?: any;
  description?: string;

  // class-validator constraints
  min?: number;
  max?: number;
  minLength?: number;
  maxLength?: number;
  enum?: string[];
  pattern?: RegExp;
  email?: boolean;
  url?: boolean;

  // Custom validator
  validate?: (value: any, ctx: Context) => Promise<void> | void;
}

/**
 * Script configuration for @Script decorator
 */
export interface ScriptConfig {
  emoji?: string;
  tags?: string[];
  args: Record<string, ArgumentConfig>;
}

/**
 * Script class interface
 */
export interface ScriptClass {
  new (deps: ScriptDependencies): ScriptInstance;
}

/**
 * Script instance interface
 */
export interface ScriptInstance {
  run(ctx: Context): Promise<void>;
  validate?(ctx: Context): Promise<void>;
}

/**
 * Script dependencies (injected via constructor)
 */
export interface ScriptDependencies {
  logger: Logger;
  shell: ShellExecutor;
  fs: FileSystem;
  git?: GitService;
  xcode?: XcodeService;
  openai?: OpenAIService;
}
