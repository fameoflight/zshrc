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

function getLogFile(commandName: string): string {
	const logDir = getLogDir(commandName);

	// current date in YYYY-MM-DD format and time in HH-MM-SS format
	const date = new Date();
	const dateStr = date.toISOString().split('T')[0];
	const timeStr = date.toLocaleTimeString().replace(/:/g, '-');

	return createIfNotExists(
		path.join(logDir, `${commandName}-${dateStr}-${timeStr}.log`),
		'file',
	);
}

function isDebugMode() {
	const val = _.get(process, 'env.DEBUG', '0');

	return val === '1' || val.toLowerCase() === 'true';
}

function getCurrentDir(): string {
	const value = process.env['ORIGINAL_WORKING_DIR'] || process.cwd();

	return path.resolve(value);
}

export {getCommandDir, isDebugMode, getLogFile, getCurrentDir};
