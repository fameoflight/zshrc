import { Script, BaseScript, type Context } from '../../core/decorators/script';
import { EpubGeneratorService } from '../../core/services/EpubGeneratorService';
import { PageFetcherService } from '../../core/services/PageFetcherService';
import { ArticleDetectorService } from '../../core/services/ArticleDetectorService';
import { BrowserService } from '../../core/services/BrowserService';
import { mkdirSync } from 'fs';
import { join } from 'path';
import { format } from 'date-fns';

/**
 * Website EPUB Creator
 *
 * Scrapes a website using browser automation and creates an EPUB from articles
 */
@Script({
  emoji: '🌐',
  tags: ['epub', 'website', 'scraper'],
  args: {
    url: {
      type: 'string',
      position: 0,
      description: 'URL to scrape',
      required: true,
    },
    maxClicks: {
      type: 'number',
      flag: '--max-clicks <count>',
      description: 'Maximum read more clicks',
      default: 5,
    },
    headless: {
      type: 'boolean',
      flag: '--headless',
      description: 'Run browser in headless mode',
      default: true,
    },
    timeout: {
      type: 'number',
      flag: '--timeout <seconds>',
      description: 'Browser timeout in seconds',
      default: 30,
    },
    wait: {
      type: 'number',
      flag: '--wait <seconds>',
      description: 'Wait time for page load in seconds',
      default: 3,
    },
    cacheEnabled: {
      type: 'boolean',
      flag: '--cache',
      description: 'Enable page caching',
      default: true,
    },
    articlesOnly: {
      type: 'boolean',
      flag: '--articles-only',
      description: 'Only process URLs that are detected as articles',
      default: false,
    },
    createEpub: {
      type: 'boolean',
      flag: '--create-epub',
      description: 'Create EPUB file from detected articles',
      default: false,
    },
    epubTitle: {
      type: 'string',
      flag: '--epub-title <title>',
      description: 'Custom title for the EPUB',
    },
    epubAuthor: {
      type: 'string',
      flag: '--epub-author <author>',
      description: 'Custom author for the EPUB',
    },
    saveToIcloud: {
      type: 'boolean',
      flag: '--save-to-icloud',
      description: 'Save EPUB to iCloud Drive',
      default: true,
    },
  },
})
export class WebsiteEpubScript extends BaseScript {
  private browserService!: BrowserService;
  private pageFetcher!: PageFetcherService;
  private articleDetector!: ArticleDetectorService;

  async validate(ctx: Context): Promise<void> {
    const args = ctx.args as any;

    // Validate URL
    const url = args.url;
    if (!url || !url.match(/^https?:\/\//)) {
      this.logger.error('URL must start with http:// or https://');
      process.exit(1);
    }

    // Initialize services
    this.browserService = new BrowserService({ logger: this.logger });
    this.pageFetcher = new PageFetcherService({
      logger: this.logger,
      rateLimitDelay: 1000,
      maxConcurrent: 5,
    });
    this.articleDetector = new ArticleDetectorService({
      logger: this.logger,
    });
  }

  async execute(ctx: Context): Promise<void> {
    const args = ctx.args as any;

    this.logger.info('🌐 Website EPUB Creator');
    this.logger.info(`Target URL: ${args.url}`);
    this.logger.info('Configuration:');
    this.logger.info(`  • Max clicks: ${args.maxClicks}`);
    this.logger.info(`  • Cache enabled: ${args.cacheEnabled}`);
    this.logger.info(`  • Articles only: ${args.articlesOnly}`);

    try {
      // Step 1: Initialize browser service
      const browserAvailable = await this.browserService.initialize();

      if (!browserAvailable) {
        this.logger.warn('Browser service not available, falling back to simple HTTP fetching');
      }

      // Step 2: Collect URLs
      const allUrls = await this.collectUrls(args.url, browserAvailable, args);

      if (allUrls.length === 0) {
        this.logger.warn('No URLs found on the webpage');
        return;
      }

      // Step 3: Filter to same domain
      const domain = this.extractDomain(args.url);
      const sameDomainUrls = allUrls.filter((url) => this.isSameDomain(url, domain));

      this.logger.info(
        `Domain filtering: ${allUrls.length} total → ${sameDomainUrls.length} same-domain URLs`
      );

      if (sameDomainUrls.length === 0) {
        this.logger.warn('No same-domain URLs found');
        return;
      }

      // Step 4: Article detection (if enabled)
      let finalUrls = sameDomainUrls;

      if (args.articlesOnly) {
        this.logger.info('🔍 Detecting articles...');
        finalUrls = await this.filterArticles(sameDomainUrls);

        this.logger.info(
          `Article detection: ${sameDomainUrls.length} URLs → ${finalUrls.length} articles`
        );

        if (finalUrls.length === 0) {
          this.logger.warn('No articles detected in the URLs');
          return;
        }
      }

      // Step 5: Create EPUB or display URLs
      if (args.createEpub) {
        await this.createEpubFromUrls(finalUrls, ctx);
      } else {
        this.displayUrls(finalUrls);
      }
    } catch (error: any) {
      this.logger.error(`Failed to process URLs: ${error.message}`);
      throw error;
    } finally {
      // Cleanup
      await this.browserService.close();
      this.logger.debug('Cleanup completed');
    }

    this.logger.success('Website processing completed');
  }

  /**
   * Collect URLs from the website
   */
  private async collectUrls(
    url: string,
    useBrowser: boolean,
    args: any
  ): Promise<string[]> {
    if (useBrowser) {
      return await this.collectUrlsWithBrowser(url, args);
    } else {
      return await this.collectUrlsWithHttp(url);
    }
  }

  /**
   * Collect URLs using browser automation
   */
  private async collectUrlsWithBrowser(url: string, args: any): Promise<string[]> {
    this.logger.info('📖 Collecting URLs with browser automation...');

    const urls = new Set<string>();

    // Navigate to the page
    const page = await this.browserService.newPage();

    try {
      await page.goto(url, {
        waitUntil: 'networkidle0',
        timeout: args.timeout * 1000,
      });

      // Wait for initial page load
      await page.waitForTimeout(args.wait * 1000);

      // Click "Read More" buttons
      for (let i = 0; i < args.maxClicks; i++) {
        this.logger.debug(`Click iteration ${i + 1}/${args.maxClicks}`);

        // Try to find and click "read more" type buttons
        const clicked = await this.tryClickReadMore(page);

        if (!clicked) {
          this.logger.debug('No more read more buttons found');
          break;
        }

        // Wait for content to load
        await page.waitForTimeout(args.wait * 1000);
      }

      // Extract all links
      const links = await this.browserService.extractLinks(url);
      links.forEach((link) => urls.add(link.href));

      this.logger.success(`Collected ${urls.size} URLs from browser`);
    } finally {
      await page.close();
    }

    return Array.from(urls);
  }

  /**
   * Try to click "read more" buttons
   */
  private async tryClickReadMore(page: any): Promise<boolean> {
    try {
      // Common selectors for "read more" buttons
      const selectors = [
        'button:has-text("Read More")',
        'button:has-text("Load More")',
        'button:has-text("Show More")',
        'a:has-text("Read More")',
        'a:has-text("Load More")',
        '.load-more',
        '.read-more',
        '[data-load-more]',
      ];

      for (const selector of selectors) {
        try {
          const element = await page.$(selector);
          if (element) {
            await element.click();
            return true;
          }
        } catch {
          // Continue to next selector
        }
      }

      return false;
    } catch {
      return false;
    }
  }

  /**
   * Collect URLs using simple HTTP fetching
   */
  private async collectUrlsWithHttp(url: string): Promise<string[]> {
    this.logger.info('📖 Collecting URLs with HTTP fetching...');

    const page = await this.pageFetcher.fetchPage(url);
    const links = this.articleDetector.extractLinks(page.content);

    const urls = links.map((link) => this.resolveUrl(link.href, url));

    this.logger.success(`Collected ${urls.length} URLs from HTTP`);
    return urls;
  }

  /**
   * Filter URLs to articles only
   */
  private async filterArticles(urls: string[]): Promise<string[]> {
    const articles: string[] = [];

    for (const url of urls) {
      try {
        const page = await this.pageFetcher.fetchPage(url);
        const isArticle = this.articleDetector.isProbablyArticle(page.content);

        if (isArticle) {
          articles.push(url);
        }
      } catch (error: any) {
        this.logger.debug(`Failed to check article status for ${url}: ${error.message}`);
      }
    }

    return articles;
  }

  /**
   * Create EPUB from URLs
   */
  private async createEpubFromUrls(urls: string[], ctx: Context): Promise<void> {
    const args = ctx.args as any;

    this.logger.info('📚 Creating EPUB');

    // Fetch all pages
    this.logger.info(`Fetching ${urls.length} pages...`);
    const pages = await this.pageFetcher.fetchPages(urls);

    if (pages.length === 0) {
      this.logger.error('Failed to fetch any pages');
      return;
    }

    this.logger.success(`Fetched ${pages.length}/${urls.length} pages`);

    // Extract articles
    this.logger.info('Extracting article content...');
    const articles = this.articleDetector.extractArticles(
      pages.map((p) => ({ html: p.content, url: p.url }))
    );

    if (articles.length === 0) {
      this.logger.error('Failed to extract any articles');
      return;
    }

    this.logger.success(`Extracted ${articles.length} articles`);

    // Generate EPUB
    const domain = this.extractDomain(args.url);
    const title = args.epubTitle || `${domain} Articles`;
    const author = args.epubAuthor || domain;

    const epubGenerator = new EpubGeneratorService(
      {
        title,
        author,
        description: `Articles from ${domain}, created on ${format(new Date(), 'MMMM d, yyyy')}`,
      },
      this.logger
    );

    // Add chapters
    articles.forEach((article) => {
      epubGenerator.addChapter({
        title: article.title,
        content: article.content,
        author: article.author,
        url: article.url,
        date: article.publishedTime ? new Date(article.publishedTime) : undefined,
      });
    });

    // Generate EPUB file
    const outputPath = this.getOutputPath(domain, args.saveToIcloud);
    await epubGenerator.generate(outputPath);

    this.logger.success('EPUB created successfully!');
    this.logger.info(`EPUB location: ${outputPath}`);

    if (args.saveToIcloud) {
      const niceDomain = domain.replace(/\./g, '-');
      this.logger.info(`Check your iCloud Drive for the EPUB in: WebsiteEPUB/${niceDomain}/`);
    }
  }

  /**
   * Display collected URLs
   */
  private displayUrls(urls: string[]): void {
    this.logger.info('📋 Final URLs\n');

    urls.forEach((url, index) => {
      console.log(`${index + 1}. ${url}`);
    });

    console.log();
    this.logger.success(`Total: ${urls.length} URLs`);
  }

  /**
   * Extract domain from URL
   */
  private extractDomain(url: string): string {
    try {
      const urlObj = new URL(url);
      return urlObj.hostname;
    } catch {
      return 'unknown';
    }
  }

  /**
   * Check if two URLs are from the same domain
   */
  private isSameDomain(url: string, domain: string): boolean {
    if (!url.startsWith('http')) return false;

    try {
      const urlObj = new URL(url);
      return urlObj.hostname === domain || urlObj.hostname.endsWith(`.${domain}`);
    } catch {
      return false;
    }
  }

  /**
   * Resolve relative URL to absolute URL
   */
  private resolveUrl(href: string, baseUrl: string): string {
    try {
      return new URL(href, baseUrl).href;
    } catch {
      return href;
    }
  }

  /**
   * Get output path for EPUB
   */
  private getOutputPath(domain: string, saveToIcloud: boolean): string {
    const niceDomain = domain.replace(/\./g, '-');
    const filename = `${niceDomain}_${format(new Date(), 'yyyy-MM-dd')}.epub`;

    if (saveToIcloud) {
      const icloudPath = join(
        process.env.HOME || '',
        `Library/Mobile Documents/com~apple~CloudDocs/WebsiteEPUB/${niceDomain}`
      );
      mkdirSync(icloudPath, { recursive: true });
      return join(icloudPath, filename);
    } else {
      const downloadsPath = join(process.env.HOME || '', 'Downloads');
      return join(downloadsPath, filename);
    }
  }
}
