import { Readability } from '@mozilla/readability';
import { JSDOM } from 'jsdom';
import * as cheerio from 'cheerio';
import type { Logger } from '../types';

/**
 * Extracted article data
 */
export interface Article {
  title: string;
  content: string;
  textContent: string;
  excerpt: string;
  byline: string | null;
  author?: string;
  dir: string | null;
  siteName: string | null;
  lang: string | null;
  publishedTime: string | null;
  url: string;
}

/**
 * Article detection options
 */
export interface ArticleDetectionOptions {
  charThreshold?: number;
  classesToPreserve?: string[];
  keepClasses?: boolean;
  disableJSONLD?: boolean;
  maxElemsToParse?: number;
  nbTopCandidates?: number;
}

/**
 * Article Detector Service
 *
 * Extracts readable article content from HTML using Mozilla Readability
 */
export class ArticleDetectorService {
  private logger: Logger;
  private defaultOptions: ArticleDetectionOptions;

  constructor(options: { logger: Logger; detectionOptions?: ArticleDetectionOptions }) {
    this.logger = options.logger;
    this.defaultOptions = {
      charThreshold: 500,
      keepClasses: false,
      disableJSONLD: false,
      maxElemsToParse: 0,
      nbTopCandidates: 5,
      ...options.detectionOptions,
    };
  }

  /**
   * Extract article content from HTML
   */
  extractArticle(html: string, url: string, options?: ArticleDetectionOptions): Article | null {
    try {
      // Parse HTML with JSDOM
      const dom = new JSDOM(html, { url });
      const document = dom.window.document;

      // Create Readability instance
      const reader = new Readability(document, {
        ...this.defaultOptions,
        ...options,
      });

      // Parse the article
      const article = reader.parse();

      if (!article) {
        this.logger.debug(`No article content found for ${url}`);
        return null;
      }

      // Clean and enhance the content
      const cleanedContent = this.cleanContent(article.content);

      return {
        title: article.title,
        content: cleanedContent,
        textContent: article.textContent,
        excerpt: article.excerpt,
        byline: article.byline,
        author: this.extractAuthor(article.byline),
        dir: article.dir,
        siteName: article.siteName,
        lang: article.lang,
        publishedTime: article.publishedTime,
        url,
      };
    } catch (error: any) {
      this.logger.error(`Failed to extract article from ${url}: ${error.message}`);
      return null;
    }
  }

  /**
   * Extract multiple articles from HTML pages
   */
  extractArticles(
    pages: Array<{ html: string; url: string }>,
    options?: ArticleDetectionOptions
  ): Article[] {
    const articles: Article[] = [];

    for (const page of pages) {
      const article = this.extractArticle(page.html, page.url, options);
      if (article) {
        articles.push(article);
      }
    }

    this.logger.info(`Extracted ${articles.length}/${pages.length} articles`);
    return articles;
  }

  /**
   * Check if HTML contains article content
   */
  isProbablyArticle(html: string): boolean {
    try {
      const dom = new JSDOM(html);
      const document = dom.window.document;

      const reader = new Readability(document);
      const article = reader.parse();

      return article !== null;
    } catch {
      return false;
    }
  }

  /**
   * Extract images from article content
   */
  extractImages(
    html: string
  ): Array<{ src: string; alt: string; width?: number; height?: number }> {
    const $ = cheerio.load(html);
    const images: Array<{ src: string; alt: string; width?: number; height?: number }> = [];

    $('img').each((_, elem) => {
      const $img = $(elem);
      const src = $img.attr('src');
      const alt = $img.attr('alt') || '';
      const width = $img.attr('width') ? parseInt($img.attr('width')!) : undefined;
      const height = $img.attr('height') ? parseInt($img.attr('height')!) : undefined;

      if (src) {
        images.push({ src, alt, width, height });
      }
    });

    return images;
  }

  /**
   * Extract links from article content
   */
  extractLinks(html: string): Array<{ href: string; text: string; rel?: string }> {
    const $ = cheerio.load(html);
    const links: Array<{ href: string; text: string; rel?: string }> = [];

    $('a').each((_, elem) => {
      const $link = $(elem);
      const href = $link.attr('href');
      const text = $link.text().trim();
      const rel = $link.attr('rel');

      if (href && text) {
        links.push({ href, text, rel });
      }
    });

    return links;
  }

  /**
   * Clean and enhance article content
   */
  private cleanContent(html: string): string {
    const $ = cheerio.load(html);

    // Remove script and style tags
    $('script, style').remove();

    // Remove empty paragraphs
    $('p').each((_, elem) => {
      const $p = $(elem);
      if ($p.text().trim() === '') {
        $p.remove();
      }
    });

    // Remove excessive whitespace
    $('*').each((_, elem) => {
      const $elem = $(elem);
      const text = $elem.text();
      if (text) {
        $elem.text(text.replace(/\s+/g, ' ').trim());
      }
    });

    // Ensure images have proper attributes
    $('img').each((_, elem) => {
      const $img = $(elem);

      // Ensure alt attribute exists
      if (!$img.attr('alt')) {
        $img.attr('alt', '');
      }

      // Add loading attribute for modern browsers
      $img.attr('loading', 'lazy');
    });

    // Clean up links
    $('a').each((_, elem) => {
      const $link = $(elem);

      // Remove target="_blank" for EPUB compatibility
      $link.removeAttr('target');

      // Remove JavaScript links
      if ($link.attr('href')?.startsWith('javascript:')) {
        $link.removeAttr('href');
      }
    });

    return $.html();
  }

  /**
   * Extract author name from byline
   */
  private extractAuthor(byline: string | null): string | undefined {
    if (!byline) return undefined;

    // Common byline patterns
    const patterns = [
      /^by\s+(.+)$/i,
      /^(.+?)\s*,\s*\w+/i, // "John Doe, Reporter"
      /^(.+?)\s*\|/i, // "John Doe | Publication"
    ];

    for (const pattern of patterns) {
      const match = byline.match(pattern);
      if (match) {
        return match[1].trim();
      }
    }

    // If no pattern matches, return the byline as-is (trimmed)
    return byline.trim();
  }

  /**
   * Get article word count
   */
  getWordCount(textContent: string): number {
    return textContent.split(/\s+/).filter((word) => word.length > 0).length;
  }

  /**
   * Get reading time estimate (in minutes)
   */
  getReadingTime(textContent: string, wordsPerMinute: number = 200): number {
    const wordCount = this.getWordCount(textContent);
    return Math.ceil(wordCount / wordsPerMinute);
  }

  /**
   * Extract metadata from HTML
   */
  extractMetadata(html: string): Record<string, string> {
    const $ = cheerio.load(html);
    const metadata: Record<string, string> = {};

    // Open Graph metadata
    $('meta[property^="og:"]').each((_, elem) => {
      const $meta = $(elem);
      const property = $meta.attr('property')?.replace('og:', '');
      const content = $meta.attr('content');

      if (property && content) {
        metadata[property] = content;
      }
    });

    // Twitter Card metadata
    $('meta[name^="twitter:"]').each((_, elem) => {
      const $meta = $(elem);
      const name = $meta.attr('name')?.replace('twitter:', '');
      const content = $meta.attr('content');

      if (name && content) {
        metadata[`twitter_${name}`] = content;
      }
    });

    // Standard meta tags
    const standardTags = ['description', 'keywords', 'author', 'published-time', 'modified-time'];
    standardTags.forEach((tag) => {
      const content = $(`meta[name="${tag}"]`).attr('content');
      if (content) {
        metadata[tag] = content;
      }
    });

    return metadata;
  }
}
