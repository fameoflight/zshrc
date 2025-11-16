import { writeFileSync, readFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { createHash } from 'crypto';
import type { Logger } from '../types';

/**
 * Fetch options
 */
export interface FetchOptions {
  userAgent?: string;
  timeout?: number;
  maxRedirects?: number;
  headers?: Record<string, string>;
  retries?: number;
  retryDelay?: number;
}

/**
 * Image fetch options
 */
export interface ImageFetchOptions extends FetchOptions {
  maxWidth?: number;
  maxHeight?: number;
  quality?: number;
  format?: 'jpeg' | 'png' | 'webp';
}

/**
 * Cached page data
 */
export interface CachedPage {
  url: string;
  content: string;
  contentType: string;
  fetchedAt: Date;
  headers: Record<string, string>;
}

/**
 * Cached image data
 */
export interface CachedImage {
  url: string;
  data: Buffer;
  mediaType: string;
  width?: number;
  height?: number;
  fetchedAt: Date;
}

/**
 * Page Fetcher Service
 *
 * Handles HTTP requests with caching, rate limiting, and image optimization
 */
export class PageFetcherService {
  private logger: Logger;
  private cacheDir: string;
  private userAgent: string;
  private timeout: number;
  private maxRedirects: number;
  private rateLimitDelay: number;
  private lastFetchTime: number = 0;
  private maxConcurrent: number;
  private activeRequests: number = 0;

  constructor(options: {
    logger: Logger;
    cacheDir?: string;
    userAgent?: string;
    timeout?: number;
    maxRedirects?: number;
    rateLimitDelay?: number;
    maxConcurrent?: number;
  }) {
    this.logger = options.logger;
    this.cacheDir = options.cacheDir || join(process.env.HOME || '/tmp', '.cache/epub-fetcher');
    this.userAgent =
      options.userAgent ||
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    this.timeout = options.timeout || 30000;
    this.maxRedirects = options.maxRedirects || 5;
    this.rateLimitDelay = options.rateLimitDelay || 1000; // 1 second between requests
    this.maxConcurrent = options.maxConcurrent || 5;

    // Ensure cache directory exists
    if (!existsSync(this.cacheDir)) {
      mkdirSync(this.cacheDir, { recursive: true });
    }
  }

  /**
   * Fetch a page with caching
   */
  async fetchPage(url: string, options?: FetchOptions): Promise<CachedPage> {
    const cacheKey = this.getCacheKey(url);
    const cachePath = this.getCachePath(cacheKey);

    // Check cache
    if (existsSync(cachePath)) {
      try {
        const cached = JSON.parse(readFileSync(cachePath, 'utf-8'));
        this.logger.debug(`Cache hit for ${url}`);
        return {
          ...cached,
          fetchedAt: new Date(cached.fetchedAt),
        };
      } catch (error) {
        this.logger.debug(`Cache read failed for ${url}, re-fetching`);
      }
    }

    // Rate limiting
    await this.waitForRateLimit();

    // Concurrency control
    await this.waitForSlot();

    try {
      this.activeRequests++;
      this.logger.debug(`Fetching ${url}`);

      const response = await this.fetchWithRetry(url, options);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const content = await response.text();
      const contentType = response.headers.get('content-type') || 'text/html';

      const headers: Record<string, string> = {};
      response.headers.forEach((value, key) => {
        headers[key] = value;
      });

      const cached: CachedPage = {
        url,
        content,
        contentType,
        fetchedAt: new Date(),
        headers,
      };

      // Save to cache
      try {
        mkdirSync(dirname(cachePath), { recursive: true });
        writeFileSync(cachePath, JSON.stringify(cached, null, 2));
      } catch (error: any) {
        this.logger.warn(`Failed to cache ${url}: ${error.message}`);
      }

      return cached;
    } finally {
      this.activeRequests--;
    }
  }

  /**
   * Fetch an image with caching and optional optimization
   */
  async fetchImage(url: string, options?: ImageFetchOptions): Promise<CachedImage> {
    const cacheKey = this.getCacheKey(url);
    const cachePath = this.getCachePath(cacheKey, 'img');

    // Check cache
    if (existsSync(cachePath)) {
      try {
        const cached = JSON.parse(readFileSync(cachePath, 'utf-8'));
        const dataPath = cachePath.replace('.json', '.bin');
        const data = readFileSync(dataPath);

        this.logger.debug(`Image cache hit for ${url}`);
        return {
          ...cached,
          data,
          fetchedAt: new Date(cached.fetchedAt),
        };
      } catch (error) {
        this.logger.debug(`Image cache read failed for ${url}, re-fetching`);
      }
    }

    // Rate limiting
    await this.waitForRateLimit();

    // Concurrency control
    await this.waitForSlot();

    try {
      this.activeRequests++;
      this.logger.debug(`Fetching image ${url}`);

      const response = await this.fetchWithRetry(url, options);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      let data = Buffer.from(await response.arrayBuffer());
      const contentType = response.headers.get('content-type') || 'image/jpeg';
      const mediaType = this.normalizeMediaType(contentType);

      // Optimize image if sharp is available and options are provided
      if (options?.maxWidth || options?.maxHeight || options?.format) {
        try {
          const sharp = await import('sharp');
          let pipeline = sharp.default(data);

          // Resize if needed
          if (options.maxWidth || options.maxHeight) {
            pipeline = pipeline.resize(options.maxWidth, options.maxHeight, {
              fit: 'inside',
              withoutEnlargement: true,
            });
          }

          // Convert format if specified
          if (options.format) {
            if (options.format === 'jpeg') {
              pipeline = pipeline.jpeg({ quality: options.quality || 85 });
            } else if (options.format === 'png') {
              pipeline = pipeline.png({ quality: options.quality || 85 });
            } else if (options.format === 'webp') {
              pipeline = pipeline.webp({ quality: options.quality || 85 });
            }
          }

          data = await pipeline.toBuffer();
        } catch (error: any) {
          this.logger.warn(`Image optimization failed for ${url}: ${error.message}`);
        }
      }

      const cached: CachedImage = {
        url,
        data,
        mediaType,
        fetchedAt: new Date(),
      };

      // Save to cache
      try {
        mkdirSync(dirname(cachePath), { recursive: true });
        const dataPath = cachePath.replace('.json', '.bin');
        writeFileSync(dataPath, data);
        writeFileSync(
          cachePath,
          JSON.stringify(
            {
              url: cached.url,
              mediaType: cached.mediaType,
              width: cached.width,
              height: cached.height,
              fetchedAt: cached.fetchedAt,
            },
            null,
            2
          )
        );
      } catch (error: any) {
        this.logger.warn(`Failed to cache image ${url}: ${error.message}`);
      }

      return cached;
    } finally {
      this.activeRequests--;
    }
  }

  /**
   * Fetch multiple pages in parallel with concurrency limit
   */
  async fetchPages(urls: string[], options?: FetchOptions): Promise<CachedPage[]> {
    this.logger.info(`Fetching ${urls.length} pages...`);

    const results: CachedPage[] = [];
    const errors: Array<{ url: string; error: string }> = [];

    for (const url of urls) {
      try {
        const page = await this.fetchPage(url, options);
        results.push(page);
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
   * Fetch multiple images in parallel with concurrency limit
   */
  async fetchImages(urls: string[], options?: ImageFetchOptions): Promise<CachedImage[]> {
    this.logger.info(`Fetching ${urls.length} images...`);

    const results: CachedImage[] = [];
    const errors: Array<{ url: string; error: string }> = [];

    for (const url of urls) {
      try {
        const image = await this.fetchImage(url, options);
        results.push(image);
      } catch (error: any) {
        this.logger.error(`Failed to fetch image ${url}: ${error.message}`);
        errors.push({ url, error: error.message });
      }
    }

    if (errors.length > 0) {
      this.logger.warn(`Failed to fetch ${errors.length}/${urls.length} images`);
    }

    return results;
  }

  /**
   * Clear cache for a specific URL or all cache
   */
  clearCache(url?: string): void {
    if (url) {
      const cacheKey = this.getCacheKey(url);
      const cachePath = this.getCachePath(cacheKey);
      if (existsSync(cachePath)) {
        try {
          const fs = require('fs');
          fs.unlinkSync(cachePath);
          this.logger.info(`Cleared cache for ${url}`);
        } catch (error: any) {
          this.logger.error(`Failed to clear cache for ${url}: ${error.message}`);
        }
      }
    } else {
      try {
        const fs = require('fs');
        fs.rmSync(this.cacheDir, { recursive: true, force: true });
        mkdirSync(this.cacheDir, { recursive: true });
        this.logger.info('Cleared all cache');
      } catch (error: any) {
        this.logger.error(`Failed to clear cache: ${error.message}`);
      }
    }
  }

  /**
   * Fetch with retry logic
   */
  private async fetchWithRetry(
    url: string,
    options?: FetchOptions,
    attempt: number = 1
  ): Promise<Response> {
    const maxRetries = options?.retries || 3;
    const retryDelay = options?.retryDelay || 2000;

    const headers = {
      'User-Agent': options?.userAgent || this.userAgent,
      ...options?.headers,
    };

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), options?.timeout || this.timeout);

      const response = await fetch(url, {
        headers,
        redirect: 'follow',
        signal: controller.signal,
      });

      clearTimeout(timeout);
      return response;
    } catch (error: any) {
      if (attempt >= maxRetries) {
        throw error;
      }

      this.logger.debug(`Fetch failed (attempt ${attempt}/${maxRetries}), retrying...`);
      await this.sleep(retryDelay * attempt);
      return this.fetchWithRetry(url, options, attempt + 1);
    }
  }

  /**
   * Wait for rate limit
   */
  private async waitForRateLimit(): Promise<void> {
    const now = Date.now();
    const timeSinceLastFetch = now - this.lastFetchTime;

    if (timeSinceLastFetch < this.rateLimitDelay) {
      const delay = this.rateLimitDelay - timeSinceLastFetch;
      await this.sleep(delay);
    }

    this.lastFetchTime = Date.now();
  }

  /**
   * Wait for available concurrency slot
   */
  private async waitForSlot(): Promise<void> {
    while (this.activeRequests >= this.maxConcurrent) {
      await this.sleep(100);
    }
  }

  /**
   * Sleep for specified milliseconds
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Get cache key for URL
   */
  private getCacheKey(url: string): string {
    return createHash('sha256').update(url).digest('hex');
  }

  /**
   * Get cache file path
   */
  private getCachePath(key: string, type: 'page' | 'img' = 'page'): string {
    const subdir = type === 'img' ? 'images' : 'pages';
    const prefix = key.substring(0, 2);
    return join(this.cacheDir, subdir, prefix, `${key}.json`);
  }

  /**
   * Normalize media type
   */
  private normalizeMediaType(contentType: string): string {
    const type = contentType.split(';')[0].trim().toLowerCase();

    const mediaTypeMap: Record<string, string> = {
      'image/jpeg': 'image/jpeg',
      'image/jpg': 'image/jpeg',
      'image/png': 'image/png',
      'image/gif': 'image/gif',
      'image/webp': 'image/webp',
      'image/svg+xml': 'image/svg+xml',
    };

    return mediaTypeMap[type] || 'image/jpeg';
  }

  /**
   * Get cache statistics
   */
  getCacheStats(): { pages: number; images: number; sizeBytes: number } {
    let pages = 0;
    let images = 0;
    let sizeBytes = 0;

    try {
      const fs = require('fs');
      const path = require('path');

      const walkDir = (dir: string) => {
        if (!existsSync(dir)) return;

        const files = fs.readdirSync(dir);
        for (const file of files) {
          const filePath = path.join(dir, file);
          const stat = fs.statSync(filePath);

          if (stat.isDirectory()) {
            walkDir(filePath);
          } else {
            sizeBytes += stat.size;
            if (filePath.includes('/pages/')) pages++;
            if (filePath.includes('/images/')) images++;
          }
        }
      };

      walkDir(this.cacheDir);
    } catch (error: any) {
      this.logger.error(`Failed to get cache stats: ${error.message}`);
    }

    return { pages: pages / 2, images: images / 2, sizeBytes }; // Divide by 2 because we have .json + .bin
  }
}
