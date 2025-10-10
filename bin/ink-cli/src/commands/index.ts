import {getRegistry} from '../base/index.js';

import AddCommand from './add.js';
import LLMChatCommand from './llm-chat.js';

export function registerAllCommands() {
	const registry = getRegistry();

	registry.register(new AddCommand());
	registry.register(new LLMChatCommand());
}
