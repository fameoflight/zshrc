import fs from 'fs';
import os from 'os';

import {getLogFile, isDebugMode} from './utils.js';

export interface LoggerConfig {
	commandName: string;
	logToFile?: boolean;
	logToConsole?: boolean;
}

export class Logger {
	private commandName: string;
	private logFile: string;
	private logToFile: boolean;
	private logToConsole: boolean;

	constructor(config: LoggerConfig) {
		this.commandName = config.commandName;
		this.logFile = getLogFile(this.commandName);
		this.logToFile = config.logToFile ?? true;
		this.logToConsole = isDebugMode() || (config.logToConsole ?? false);
	}

	private formatMessage(level: string, message: string, data?: any): string {
		const timestamp = new Date().toISOString();
		const dataStr = data ? ` ${JSON.stringify(data)}` : '';
		return `[${timestamp}] [${level}] [${this.commandName}] ${message}${dataStr}`;
	}

	private writeLog(level: string, message: string, data?: any): void {
		const formattedMessage = this.formatMessage(level, message, data);

		// Write to file
		if (this.logToFile) {
			try {
				fs.appendFileSync(this.logFile, formattedMessage + '\n');
			} catch (error) {
				// Fallback to console if file write fails
				console.error('Failed to write to log file:', error);
			}
		}

		// Write to console if in DEBUG mode
		if (this.logToConsole) {
			switch (level) {
				case 'ERROR':
					console.error(`🔴 ${formattedMessage}`);
					break;
				case 'WARN':
					console.warn(`🟡 ${formattedMessage}`);
					break;
				case 'INFO':
					console.log(`🔵 ${formattedMessage}`);
					break;
				case 'DEBUG':
					console.log(`🟢 ${formattedMessage}`);
					break;
				default:
					console.log(formattedMessage);
			}
		}
	}

	info(message: string, data?: any): void {
		this.writeLog('INFO', message, data);
	}

	warn(message: string, data?: any): void {
		this.writeLog('WARN', message, data);
	}

	error(message: string, data?: any): void {
		this.writeLog('ERROR', message, data);
	}

	debug(message: string, data?: any): void {
		this.writeLog('DEBUG', message, data);
	}

	success(message: string, data?: any): void {
		this.writeLog('SUCCESS', message, data);
	}

	logFlags(flags: any): void {
		this.info('Command executed with flags', {
			flags,
			nodeVersion: process.version,
			platform: os.platform(),
			arch: os.arch(),
		});
	}

	logError(error: Error | string, context?: string): void {
		const errorData = {
			message: error instanceof Error ? error.message : error,
			stack: error instanceof Error ? error.stack : undefined,
			context,
		};
		this.error('Error occurred', errorData);
	}

	getLogFilePath(): string {
		return this.logFile;
	}
}

// Factory function for creating loggers
export function createLogger(config: LoggerConfig): Logger {
	return new Logger(config);
}

// Convenience function for commands
export function createCommandLogger(commandName: string): Logger {
	return createLogger({commandName});
}
