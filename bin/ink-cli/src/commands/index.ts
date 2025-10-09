import {getRegistry} from '../base/index.js';

import AddCommand from './add.js';

export function registerAllCommands() {
	const registry = getRegistry();

	registry.register(new AddCommand());
}
