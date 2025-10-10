import React, { createContext, useContext } from 'react';
import { Logger } from '../logger.js';

interface AppContextType {
	logger: Logger;
	commandName: string;
}

const AppContext = createContext<AppContextType | null>(null);

export const AppProvider: React.FC<{
	children: React.ReactNode;
	logger: Logger;
	commandName: string;
}> = ({ children, logger, commandName }) => {
	return (
		<AppContext.Provider value={{ logger, commandName }}>
			{children}
		</AppContext.Provider>
	);
};

export const useAppContext = (): AppContextType => {
	const context = useContext(AppContext);
	if (!context) {
		throw new Error('useAppContext must be used within an AppProvider');
	}
	return context;
};