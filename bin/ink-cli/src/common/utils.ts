import os from 'os';
import fs from 'fs';
import path from 'path';
import _ from 'lodash';

function createIfNotExists(
	fullPath: string,
	type: 'file' | 'dir' = 'dir',
): string {
	fullPath = path.resolve(fullPath);
	const exists = fs.existsSync(fullPath);

	if (!exists) {
		if (type === 'dir') {
			fs.mkdirSync(fullPath, {recursive: true});
		} else {
			fs.mkdirSync(path.dirname(fullPath), {recursive: true});
			fs.writeFileSync(fullPath, '');
		}
	}

	return fullPath;
}

function cliDir(): string {
	return createIfNotExists(path.join(os.homedir(), '.ink-cli'));
}

function getCommandDir(commandName: string): string {
	return createIfNotExists(path.join(cliDir(), 'commands', commandName));
}

function getLogDir(commandName: string): string {
	return createIfNotExists(path.join(getCommandDir(commandName), 'logs'));
}

function getConfigPath(commandName: string): string {
	return path.join(getCommandDir(commandName), 'config.json');
}

// Global variable to store session log file path
let sessionLogFile: string | null = null;

function getLogFile(commandName: string): string {
	// Return existing session log file if already created
	if (sessionLogFile) {
		return sessionLogFile;
	}

	const logDir = getLogDir(commandName);

	// current date in YYYY-MM-DD format and time in HH-MM-SS format (24-hour)
	const date = new Date();
	const dateStr = date.toISOString().split('T')[0];
	const timeStr = date
		.toTimeString()
		?.split(' ')[0] // Get HH:MM:SS part only
		?.replace(/:/g, '-') || '00-00-00'; // Replace colons with hyphens, fallback if undefined

	sessionLogFile = createIfNotExists(
		path.join(logDir, `${commandName}-${dateStr}-${timeStr}.log`),
		'file',
	);

	return sessionLogFile;
}

function isDebugMode() {
	const val = _.get(process, 'env.DEBUG', '0');

	return val === '1' || val.toLowerCase() === 'true';
}

function getCurrentDir(): string {
	const value = process.env['ORIGINAL_WORKING_DIR'] || process.cwd();

	return path.resolve(value);
}

export {getCommandDir, isDebugMode, getLogFile, getCurrentDir, getConfigPath};
