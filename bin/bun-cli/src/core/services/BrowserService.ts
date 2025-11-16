import type { Logger } from '../types';

/**
 * Browser page result
 */
export interface BrowserPageResult {
  html: string;
  url: string;
  title: string;
  screenshot?: Buffer;
}

/**
 * Browser navigation options
 */
export interface NavigationOptions {
  waitUntil?: 'load' | 'domcontentloaded' | 'networkidle0' | 'networkidle2';
  timeout?: number;
  userAgent?: string;
  viewport?: {
    width: number;
    height: number;
    deviceScaleFactor?: number;
  };
}

/**
 * Screenshot options
 */
export interface ScreenshotOptions {
  fullPage?: boolean;
  type?: 'png' | 'jpeg';
  quality?: number;
  omitBackground?: boolean;
}

/**
 * Browser Service
 *
 * Provides headless browser automation using Puppeteer
 * Falls back gracefully when Puppeteer is not available
 */
export class BrowserService {
  private logger: Logger;
  private browser: any = null;
  private puppeteer: any = null;
  private available: boolean = false;

  constructor(options: { logger: Logger }) {
    this.logger = options.logger;
  }

  /**
   * Initialize the browser service
   */
  async initialize(): Promise<boolean> {
    if (this.available) return true;

    try {
      // Dynamically import puppeteer
      this.puppeteer = await import('puppeteer');

      // Launch browser
      this.browser = await this.puppeteer.launch({
        headless: 'new',
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-accelerated-2d-canvas',
          '--disable-gpu',
        ],
      });

      this.available = true;
      this.logger.debug('Browser service initialized');
      return true;
    } catch (error: any) {
      this.logger.warn(
        `Browser service not available: ${error.message}. Install puppeteer to enable browser automation.`
      );
      this.available = false;
      return false;
    }
  }

  /**
   * Check if browser service is available
   */
  isAvailable(): boolean {
    return this.available;
  }

  /**
   * Navigate to a URL and get the rendered HTML
   */
  async fetchPage(url: string, options?: NavigationOptions): Promise<BrowserPageResult> {
    if (!this.available) {
      throw new Error('Browser service is not available. Call initialize() first.');
    }

    const page = await this.browser.newPage();

    try {
      // Set user agent if provided
      if (options?.userAgent) {
        await page.setUserAgent(options.userAgent);
      }

      // Set viewport if provided
      if (options?.viewport) {
        await page.setViewport(options.viewport);
      }

      // Navigate to the page
      this.logger.debug(`Navigating to ${url}`);
      await page.goto(url, {
        waitUntil: options?.waitUntil || 'networkidle0',
        timeout: options?.timeout || 30000,
      });

      // Wait for any dynamic content to load
      await page.waitForTimeout(2000);

      // Get the HTML content
      const html = await page.content();
      const title = await page.title();

      return {
        html,
        url,
        title,
      };
    } finally {
      await page.close();
    }
  }

  /**
   * Navigate to multiple URLs and get their rendered HTML
   */
  async fetchPages(
    urls: string[],
    options?: NavigationOptions
  ): Promise<BrowserPageResult[]> {
    if (!this.available) {
      throw new Error('Browser service is not available. Call initialize() first.');
    }

    this.logger.info(`Fetching ${urls.length} pages with browser...`);

    const results: BrowserPageResult[] = [];
    const errors: Array<{ url: string; error: string }> = [];

    for (const url of urls) {
      try {
        const result = await this.fetchPage(url, options);
        results.push(result);
      } catch (error: any) {
        this.logger.error(`Failed to fetch ${url}: ${error.message}`);
        errors.push({ url, error: error.message });
      }
    }

    if (errors.length > 0) {
      this.logger.warn(`Failed to fetch ${errors.length}/${urls.length} pages`);
    }

    return results;
  }

  /**
   * Take a screenshot of a page
   */
  async screenshot(
    url: string,
    options?: NavigationOptions & ScreenshotOptions
  ): Promise<Buffer> {
    if (!this.available) {
      throw new Error('Browser service is not available. Call initialize() first.');
    }

    const page = await this.browser.newPage();

    try {
      // Set user agent if provided
      if (options?.userAgent) {
        await page.setUserAgent(options.userAgent);
      }

      // Set viewport if provided
      if (options?.viewport) {
        await page.setViewport(options.viewport);
      }

      // Navigate to the page
      await page.goto(url, {
        waitUntil: options?.waitUntil || 'networkidle0',
        timeout: options?.timeout || 30000,
      });

      // Wait for any dynamic content to load
      await page.waitForTimeout(2000);

      // Take screenshot
      const screenshot = await page.screenshot({
        fullPage: options?.fullPage ?? true,
        type: options?.type || 'png',
        quality: options?.quality,
        omitBackground: options?.omitBackground ?? false,
      });

      return Buffer.from(screenshot);
    } finally {
      await page.close();
    }
  }

  /**
   * Execute JavaScript in the page context
   */
  async evaluate<T>(
    url: string,
    pageFunction: string | ((args: any) => T),
    args?: any,
    options?: NavigationOptions
  ): Promise<T> {
    if (!this.available) {
      throw new Error('Browser service is not available. Call initialize() first.');
    }

    const page = await this.browser.newPage();

    try {
      // Set user agent if provided
      if (options?.userAgent) {
        await page.setUserAgent(options.userAgent);
      }

      // Set viewport if provided
      if (options?.viewport) {
        await page.setViewport(options.viewport);
      }

      // Navigate to the page
      await page.goto(url, {
        waitUntil: options?.waitUntil || 'networkidle0',
        timeout: options?.timeout || 30000,
      });

      // Execute the function
      return await page.evaluate(pageFunction, args);
    } finally {
      await page.close();
    }
  }

  /**
   * Extract links from a page
   */
  async extractLinks(
    url: string,
    options?: NavigationOptions
  ): Promise<Array<{ href: string; text: string }>> {
    return this.evaluate<Array<{ href: string; text: string }>>(
      url,
      () => {
        const links = Array.from(document.querySelectorAll('a[href]'));
        return links.map((link) => ({
          href: (link as HTMLAnchorElement).href,
          text: link.textContent?.trim() || '',
        }));
      },
      undefined,
      options
    );
  }

  /**
   * Extract images from a page
   */
  async extractImages(
    url: string,
    options?: NavigationOptions
  ): Promise<Array<{ src: string; alt: string; width?: number; height?: number }>> {
    return this.evaluate<Array<{ src: string; alt: string; width?: number; height?: number }>>(
      url,
      () => {
        const images = Array.from(document.querySelectorAll('img[src]'));
        return images.map((img) => ({
          src: (img as HTMLImageElement).src,
          alt: (img as HTMLImageElement).alt || '',
          width: (img as HTMLImageElement).width || undefined,
          height: (img as HTMLImageElement).height || undefined,
        }));
      },
      undefined,
      options
    );
  }

  /**
   * Wait for a selector to appear on the page
   */
  async waitForSelector(
    url: string,
    selector: string,
    timeout: number = 30000
  ): Promise<boolean> {
    if (!this.available) {
      throw new Error('Browser service is not available. Call initialize() first.');
    }

    const page = await this.browser.newPage();

    try {
      await page.goto(url, { waitUntil: 'networkidle0', timeout });

      await page.waitForSelector(selector, { timeout });
      return true;
    } catch (error) {
      return false;
    } finally {
      await page.close();
    }
  }

  /**
   * Render a page with JavaScript and return the final HTML
   */
  async renderPage(url: string, options?: NavigationOptions): Promise<string> {
    const result = await this.fetchPage(url, options);
    return result.html;
  }

  /**
   * Close the browser
   */
  async close(): Promise<void> {
    if (this.browser) {
      await this.browser.close();
      this.browser = null;
      this.available = false;
      this.logger.debug('Browser service closed');
    }
  }

  /**
   * Get a new page instance
   */
  async newPage(): Promise<any> {
    if (!this.available) {
      throw new Error('Browser service is not available. Call initialize() first.');
    }

    return await this.browser.newPage();
  }

  /**
   * Execute a custom function with a page instance
   */
  async withPage<T>(fn: (page: any) => Promise<T>): Promise<T> {
    if (!this.available) {
      throw new Error('Browser service is not available. Call initialize() first.');
    }

    const page = await this.browser.newPage();

    try {
      return await fn(page);
    } finally {
      await page.close();
    }
  }
}
