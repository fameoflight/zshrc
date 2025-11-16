import { Script } from '../../core/decorators/Script';
import { Script as BaseScript } from '../../core/base/Script';
import type { Context } from '../../core/types';
import { LLMService } from '../../core/services/LLMService';
import { ConversationService } from '../../core/services/ConversationService';
import * as clack from '@clack/prompts';
import { execSync } from 'child_process';

type GenerationType = 'command' | 'script';
type ShellType = 'zsh' | 'bash' | 'python' | 'ruby';

/**
 * LLM-powered command and script generator
 *
 * Uses local or cloud LLMs to generate commands and scripts from natural
 * language descriptions. Supports multiple providers (Ollama, LM Studio,
 * OpenAI), interactive execution with retry logic, and conversation context.
 *
 * @example
 * llm-generate "find all PDF files larger than 10MB"
 * llm-generate -e "kill process on port 3000"
 * llm-generate -s "backup script for development projects"
 * llm-generate --model ollama:llama3:70b "compress all images"
 */
@Script({
  emoji: '🤖',
  tags: ['ai', 'llm', 'generator'],
  args: {
    description: {
      type: 'string',
      position: 0,
      description: 'Natural language description of command/script to generate',
    },
    command: {
      type: 'boolean',
      flag: '-c, --command',
      description: 'Generate a single command (default)',
    },
    script: {
      type: 'boolean',
      flag: '-s, --script',
      description: 'Generate a complete script',
    },
    bash: {
      type: 'boolean',
      flag: '-b, --bash',
      description: 'Generate bash script/command',
    },
    zsh: {
      type: 'boolean',
      flag: '-z, --zsh',
      description: 'Generate zsh script/command (default)',
    },
    ruby: {
      type: 'boolean',
      flag: '-r, --ruby',
      description: 'Generate ruby script',
    },
    python: {
      type: 'boolean',
      flag: '-p, --python',
      description: 'Generate python script',
    },
    execute: {
      type: 'boolean',
      flag: '-e, --execute',
      description: 'Execute generated command immediately',
    },
    output: {
      type: 'string',
      flag: '-o, --output <file>',
      description: 'Save generated script to file',
    },
    model: {
      type: 'string',
      flag: '-m, --model <model>',
      description: 'Use specific model (e.g., ollama:llama3:70b)',
    },
    temperature: {
      type: 'number',
      flag: '--temp <temperature>',
      description: 'Set temperature (0.0-1.0, default: 0.7)',
    },
    maxTokens: {
      type: 'number',
      flag: '--max-tokens <tokens>',
      description: 'Maximum tokens to generate (default: 4096)',
    },
    maxRetries: {
      type: 'number',
      flag: '--max-retries <retries>',
      description: 'Maximum retry attempts on failure (default: 2)',
    },
    autoRetry: {
      type: 'boolean',
      flag: '--auto-retry',
      description: 'Automatically retry failed commands without asking',
    },
    listModels: {
      type: 'boolean',
      flag: '--list-models',
      description: 'List available models and exit',
    },
  },
})
export class LLMGenerateScript extends BaseScript {
  private llm!: LLMService;
  private conversation!: ConversationService;
  private description!: string;
  private generationType: GenerationType = 'command';
  private shellType: ShellType = 'zsh';
  private temperature: number = 0.7;
  private maxTokens: number = 4096;
  private maxRetries: number = 2;

  async validate(ctx: Context): Promise<void> {
    const args = ctx.args;

    // Determine generation type
    if (args.script) this.generationType = 'script';

    // Determine shell type
    if (args.bash) this.shellType = 'bash';
    else if (args.python) this.shellType = 'python';
    else if (args.ruby) this.shellType = 'ruby';

    // Set temperature and maxTokens
    if (args.temperature !== undefined) this.temperature = args.temperature;
    if (args.maxTokens !== undefined) this.maxTokens = args.maxTokens;
    if (args.maxRetries !== undefined) this.maxRetries = args.maxRetries;

    // Initialize LLM service
    try {
      this.llm = new LLMService({
        model: args.model || process.env.MODEL || 'ollama:llama3:70b',
        logger: this.logger,
        temperature: this.temperature,
        maxTokens: this.maxTokens,
      });
    } catch (error: any) {
      throw new Error(`Failed to initialize LLM service: ${error.message}`);
    }

    // Check if service is available
    if (!(await this.llm.available())) {
      throw new Error(
        `LLM service is not available. Ensure ${this.llm.getCurrentProvider()} is running.`
      );
    }

    // Initialize conversation
    this.conversation = new ConversationService(this.llm);

    // Get description
    if (args.description) {
      this.description = args.description;
    } else if (!args.listModels) {
      // Interactive mode
      const input = await clack.text({
        message: '📝 What do you want to generate?',
        placeholder: 'e.g., find all PDF files larger than 10MB',
      });

      if (clack.isCancel(input)) {
        throw new Error('Operation cancelled');
      }

      this.description = input as string;
    }
  }

  async run(ctx: Context): Promise<void> {
    const args = ctx.args;

    // Handle list models
    if (args.listModels) {
      await this.listModels();
      return;
    }

    this.logger.section('LLM Command & Script Generator');
    this.showConfiguration();

    if (this.generationType === 'command') {
      await this.generateCommand(args);
    } else {
      await this.generateScript(args);
    }
  }

  private showConfiguration(): void {
    console.log();
    console.log('🤖 LLM Settings');
    console.log(`  Provider:     ${this.llm.getCurrentProvider()}`);
    console.log(`  Model:        ${this.llm.getCurrentModel()}`);
    console.log(`  Temperature:  ${this.temperature}`);
    console.log(`  Max Tokens:   ${this.maxTokens}`);
    console.log();
    console.log('⚙️  Generation Settings');
    console.log(`  Type:         ${this.generationType}`);
    console.log(`  Shell/Lang:   ${this.shellType}`);
    console.log(`  Max Retries:  ${this.maxRetries}`);
    console.log();
  }

  private async listModels(): Promise<void> {
    this.logger.info('Available models:');
    const models = await this.llm.listModels();

    if (models.length === 0) {
      this.logger.warn('No models found');
      return;
    }

    models.forEach((model, index) => {
      const marker = model === this.llm.getCurrentModel() ? ' ← current' : '';
      console.log(`  ${index + 1}. ${model}${marker}`);
    });
  }

  private async generateCommand(args: Context['args']): Promise<void> {
    const systemPrompt = this.buildCommandSystemPrompt();
    this.conversation.setSystemPrompt(systemPrompt);

    this.logger.info('🤖 Generating command...');

    const response = await this.conversation.sendMessage(this.description, {
      model: this.llm.getCurrentModel(),
      temperature: this.temperature,
      maxTokens: this.maxTokens,
    });

    const command = this.extractCommand(response);

    this.logger.success('Command generated:');
    console.log();
    console.log(`  ${command}`);
    console.log();

    if (args.execute) {
      await this.executeCommand(command, args.autoRetry);
    } else {
      await this.showCommandMenu(command, args);
    }
  }

  private async generateScript(args: Context['args']): Promise<void> {
    const systemPrompt = this.buildScriptSystemPrompt();
    this.conversation.setSystemPrompt(systemPrompt);

    this.logger.info('🤖 Generating script...');

    const response = await this.conversation.sendMessage(this.description, {
      model: this.llm.getCurrentModel(),
      temperature: this.temperature,
      maxTokens: this.maxTokens,
    });

    const scriptContent = this.extractScript(response);

    if (args.output) {
      await this.saveScript(scriptContent, args.output);
    } else {
      this.displayScript(scriptContent);
    }
  }

  private buildCommandSystemPrompt(): string {
    return `You are a command line expert specializing in ${this.shellType} commands.
Generate a single, efficient command for the given task.

Rules:
- Output ONLY the command, no explanations or formatting
- Use ${this.shellType}-compatible syntax with proper spacing
- Prefer commonly available tools (find, grep, awk, sed, etc.)
- Include proper escaping and safety measures
- For macOS systems, consider BSD vs GNU tool differences
- If multiple approaches exist, choose the most reliable one
- Ensure proper spacing: use "find ." not "find."
- Use full paths when needed for clarity

Example format:
find . -name "*.pdf" -size +10M -ls

The command should be ready to copy and paste into a terminal.`;
  }

  private buildScriptSystemPrompt(): string {
    const prompts: Record<ShellType, string> = {
      zsh: `You are an expert zsh script writer.
Generate a complete, well-structured zsh script for the given task.

Requirements:
- Start with proper shebang (#!/bin/zsh)
- Use 'set -euo pipefail' for error handling
- Include helpful comments
- Use functions for complex logic
- Add input validation where appropriate
- Handle errors gracefully
- Follow zsh best practices
- Make the script portable and robust

Format as a complete script ready to save and execute.`,

      bash: `You are an expert bash script writer.
Generate a complete, well-structured bash script for the given task.

Requirements:
- Start with proper shebang (#!/bin/bash)
- Use 'set -euo pipefail' for error handling
- Include helpful comments
- Use functions for complex logic
- Add input validation where appropriate
- Handle errors gracefully
- Follow bash best practices
- Make the script portable and robust

Format as a complete script ready to save and execute.`,

      python: `You are an expert Python developer.
Generate a complete, well-structured Python script for the given task.

Requirements:
- Start with proper shebang (#!/usr/bin/env python3)
- Use Python 3 syntax and features
- Include proper imports at the top
- Add helpful docstrings and comments
- Use exception handling (try/except)
- Follow PEP 8 style guidelines
- Include main guard (if __name__ == '__main__':)
- Make the script robust and maintainable

Format as a complete script ready to save and execute.`,

      ruby: `You are an expert Ruby developer.
Generate a complete, well-structured Ruby script for the given task.

Requirements:
- Start with proper shebang (#!/usr/bin/env ruby)
- Add 'frozen_string_literal: true' comment
- Use proper Ruby idioms and style
- Include error handling with begin/rescue
- Add helpful comments
- Use appropriate gems if needed (mention if they need installation)
- Follow Ruby best practices
- Make the script clear and maintainable

Format as a complete script ready to save and execute.`,
    };

    return prompts[this.shellType];
  }

  private extractCommand(response: string): string {
    // Remove markdown code blocks
    let cleaned = response.replace(/```[a-z]*\n?/g, '').replace(/```/g, '');

    // Split into lines
    const lines = cleaned.split('\n').map((line) => line.trim()).filter((line) => line);

    // Find first non-comment line
    const commandLine = lines.find(
      (line) => !line.startsWith('#') && !line.startsWith('//') && !line.startsWith('--')
    );

    let command = commandLine || lines[0] || cleaned.trim();

    // Fix common issues
    command = this.fixCommandIssues(command);

    return command;
  }

  private extractScript(response: string): string {
    // If response contains code blocks, extract content
    const codeBlockMatch = response.match(/```(?:[a-z]*\n)?(.*?)```/s);
    if (codeBlockMatch) {
      return codeBlockMatch[1].trim();
    }

    return response.trim();
  }

  private fixCommandIssues(command: string): string {
    let fixed = command;

    // Fix common spacing issues
    fixed = fixed.replace(/find\./g, 'find .');
    fixed = fixed.replace(/ls\./g, 'ls .');
    fixed = fixed.replace(/cd\./g, 'cd .');
    fixed = fixed.replace(/(\w)\./g, '$1 .');

    return fixed.trim();
  }

  private async showCommandMenu(command: string, args: Context['args']): Promise<void> {
    const action = await clack.select({
      message: 'What would you like to do?',
      options: [
        { value: 'execute', label: '✅ Execute command' },
        { value: 'copy', label: '📋 Copy to clipboard' },
        { value: 'edit', label: '✏️  Edit prompt' },
        { value: 'cancel', label: '❌ Cancel' },
      ],
    });

    if (clack.isCancel(action)) {
      this.logger.info('Operation cancelled');
      return;
    }

    switch (action) {
      case 'execute':
        await this.executeCommand(command, args.autoRetry);
        break;
      case 'copy':
        await this.copyToClipboard(command);
        this.logger.success('Command copied to clipboard!');
        break;
      case 'edit':
        const newDescription = await clack.text({
          message: '✏️  Edit your prompt:',
          defaultValue: this.description,
        });

        if (!clack.isCancel(newDescription)) {
          this.description = newDescription as string;
          await this.regenerateCommand();
        }
        break;
      case 'cancel':
        this.logger.info('Operation cancelled');
        break;
    }
  }

  private async regenerateCommand(): Promise<void> {
    this.logger.info('🔄 Regenerating command with conversation context...');

    const response = await this.conversation.continue(this.description, {
      model: this.llm.getCurrentModel(),
      temperature: this.temperature,
      maxTokens: this.maxTokens,
    });

    const command = this.extractCommand(response);

    this.logger.success('Updated command generated:');
    console.log();
    console.log(`  ${command}`);
    console.log();

    await this.showCommandMenu(command, {});
  }

  private async executeCommand(command: string, autoRetry?: boolean): Promise<void> {
    await this.executeCommandWithRetry(command, this.maxRetries, autoRetry);
  }

  private async executeCommandWithRetry(
    command: string,
    retriesLeft: number,
    autoRetry?: boolean
  ): Promise<boolean> {
    this.logger.info(`🚀 Executing: ${command}`);

    try {
      const startTime = Date.now();
      const output = execSync(command, { encoding: 'utf-8', stdio: 'pipe' });
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      this.logger.success(`✅ Command executed successfully (took ${duration}s)`);

      if (output.trim()) {
        const lines = output.split('\n');
        const displayLines = lines.slice(0, 10);

        this.logger.info('📄 Output (showing first 10 lines):');
        console.log(displayLines.join('\n'));

        if (lines.length > 10) {
          console.log();
          this.logger.info(`... and ${lines.length - 10} more line(s)`);
        }
      }

      return true;
    } catch (error: any) {
      const duration = ((Date.now() - Date.now()) / 1000).toFixed(2);
      this.logger.error(`❌ Command failed with exit code: ${error.status} (took ${duration}s)`);

      if (error.stdout || error.stderr) {
        this.logger.warn('📄 Error output:');
        console.log(error.stdout || error.stderr);
      }

      if (retriesLeft > 0) {
        return await this.handleCommandFailure(command, error.stdout || error.stderr, retriesLeft, autoRetry);
      }

      this.logger.error('💀 No more retry attempts remaining');
      return false;
    }
  }

  private async handleCommandFailure(
    originalCommand: string,
    errorOutput: string,
    retriesLeft: number,
    autoRetry?: boolean
  ): Promise<boolean> {
    this.logger.warn(`🔄 ${retriesLeft} retry attempt(s) remaining.`);

    let shouldRetry = autoRetry || false;

    if (!autoRetry) {
      const retry = await clack.confirm({
        message: '🔧 Would you like the LLM to analyze the error and suggest a fix?',
      });

      if (clack.isCancel(retry)) {
        this.logger.info('❌ Retry cancelled');
        return false;
      }

      shouldRetry = retry;
    }

    if (!shouldRetry) {
      return false;
    }

    this.logger.info('🤖 Analyzing error and generating improved command...');
    const improvedCommand = await this.generateImprovedCommand(originalCommand, errorOutput);

    if (!improvedCommand || improvedCommand === originalCommand) {
      this.logger.warn('⚠️  LLM suggested the same command. Stopping to avoid infinite loop.');
      return false;
    }

    this.logger.success('✅ Improved command generated:');
    console.log();
    console.log(`  ${improvedCommand}`);
    console.log();

    return await this.executeCommandWithRetry(improvedCommand, retriesLeft - 1, autoRetry);
  }

  private async generateImprovedCommand(
    originalCommand: string,
    errorOutput: string
  ): Promise<string | null> {
    const errorConversation = new ConversationService(this.llm);
    const systemPrompt = `You are a command line expert. Analyze failed commands and provide corrected versions.
Focus on fixing syntax errors, handling missing dependencies, correcting file paths, and using alternative approaches.
Output ONLY the corrected command, no explanations.`;

    errorConversation.setSystemPrompt(systemPrompt);

    const userPrompt = `Original command: ${originalCommand}

Error output:
${errorOutput}

The command failed. Please provide a corrected command.`;

    try {
      const response = await errorConversation.sendMessage(userPrompt, {
        model: this.llm.getCurrentModel(),
        temperature: 0.1, // Lower temperature for error fixing
        maxTokens: this.maxTokens,
      });

      return this.extractCommand(response);
    } catch {
      return null;
    }
  }

  private async copyToClipboard(text: string): Promise<void> {
    try {
      if (process.platform === 'darwin') {
        execSync(`echo '${text}' | pbcopy`);
      } else if (process.platform === 'linux') {
        try {
          execSync(`echo '${text}' | xclip -selection clipboard`);
        } catch {
          execSync(`echo '${text}' | xsel --clipboard --input`);
        }
      }
    } catch (error) {
      this.logger.warn('Could not copy to clipboard automatically');
      this.logger.info('Command (manual copy):');
      console.log(`  ${text}`);
    }
  }

  private async saveScript(content: string, outputFile: string): Promise<void> {
    await this.fs.writeFile(outputFile, content);
    this.logger.success(`Script saved to: ${outputFile}`);

    // Make executable
    try {
      execSync(`chmod +x "${outputFile}"`);
      this.logger.info('Script made executable');
    } catch {
      this.logger.warn('Could not make script executable');
    }
  }

  private displayScript(content: string): void {
    this.logger.section('Generated Script');
    console.log();
    console.log(content);
    console.log();
  }
}
