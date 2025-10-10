/**
 * Simple Dependency Injection Container
 *
 * Provides a centralized way to register and resolve services across the application.
 * This enables commands to optionally use LLM services without hard dependencies.
 */
export class ServiceContainer {
	private services: Map<string, any> = new Map();
	private factories: Map<string, () => any> = new Map();
	private singletons: Map<string, any> = new Map();

	/**
	 * Register a service instance
	 */
	register<T>(name: string, instance: T): void {
		this.services.set(name, instance);
	}

	/**
	 * Register a factory function for lazy loading
	 */
	registerFactory<T>(name: string, factory: () => T): void {
		this.factories.set(name, factory);
	}

	/**
	 * Register a singleton service (created once)
	 */
	registerSingleton<T>(name: string, factory: () => T): void {
		this.factories.set(name, factory);
		// Mark as singleton type
		this.singletons.set(name, null);
	}

	/**
	 * Resolve a service by name
	 */
	resolve<T>(name: string): T | undefined {
		// Check if we have a direct instance
		if (this.services.has(name)) {
			return this.services.get(name) as T;
		}

		// Check if we have a factory
		if (this.factories.has(name)) {
			const factory = this.factories.get(name)!;

			// Check if it's a singleton and already created
			if (this.singletons.has(name) && this.singletons.get(name) !== null) {
				return this.singletons.get(name) as T;
			}

			// Create the instance
			const instance = factory();

			// Store as singleton if needed
			if (this.singletons.has(name)) {
				this.singletons.set(name, instance);
			}

			return instance as T;
		}

		return undefined;
	}

	/**
	 * Check if a service is registered
	 */
	has(name: string): boolean {
		return (
			this.services.has(name) ||
			this.factories.has(name) ||
			this.singletons.has(name)
		);
	}

	/**
	 * Remove a service from the container
	 */
	unregister(name: string): void {
		this.services.delete(name);
		this.factories.delete(name);
		this.singletons.delete(name);
	}

	/**
	 * Clear all services
	 */
	clear(): void {
		this.services.clear();
		this.factories.clear();
		this.singletons.clear();
	}

	/**
	 * Get all registered service names
	 */
	getRegisteredServices(): string[] {
		return [
			...this.services.keys(),
			...this.factories.keys(),
			...this.singletons.keys(),
		];
	}
}

// Global service container instance
export const serviceContainer = new ServiceContainer();

/**
 * Global service resolver function
 */
export function resolve<T>(serviceName: string): T | undefined {
	return serviceContainer.resolve<T>(serviceName);
}

/**
 * Register a service globally
 */
export function register<T>(serviceName: string, instance: T): void {
	serviceContainer.register(serviceName, instance);
}

/**
 * Register a factory globally
 */
export function registerFactory<T>(serviceName: string, factory: () => T): void {
	serviceContainer.registerFactory(serviceName, factory);
}

/**
 * Register a singleton globally
 */
export function registerSingleton<T>(serviceName: string, factory: () => T): void {
	serviceContainer.registerSingleton(serviceName, factory);
}