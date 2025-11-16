import { Script, BaseScript, type Context } from '../../core/decorators/script';
import { EpubGeneratorService } from '../../core/services/EpubGeneratorService';
import { PageFetcherService } from '../../core/services/PageFetcherService';
import { ArticleDetectorService } from '../../core/services/ArticleDetectorService';
import { existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { $, ShellError } from 'bun';
import { format } from 'date-fns';

/**
 * Safari Reading List to EPUB Converter
 *
 * Extracts URLs from Safari's reading list and converts them to EPUB format
 */
@Script({
  emoji: '🧭',
  tags: ['epub', 'safari', 'reading-list'],
  args: {
    epubTitle: {
      type: 'string',
      flag: '--epub-title <title>',
      description: 'Custom title for the EPUB',
    },
    epubAuthor: {
      type: 'string',
      flag: '--epub-author <author>',
      description: 'Custom author for the EPUB',
      default: 'Safari Reader',
    },
    saveToIcloud: {
      type: 'boolean',
      flag: '--save-to-icloud',
      description: 'Save EPUB to iCloud Drive',
      default: true,
    },
    downloadImages: {
      type: 'boolean',
      flag: '--download-images',
      description: 'Download and embed images in EPUB',
      default: true,
    },
    maxImageSize: {
      type: 'number',
      flag: '--max-image-size <bytes>',
      description: 'Maximum image size in bytes',
      default: 5 * 1024 * 1024, // 5MB
    },
    cacheEnabled: {
      type: 'boolean',
      flag: '--cache',
      description: 'Enable page caching',
      default: true,
    },
    maxArticles: {
      type: 'number',
      flag: '--max-articles <count>',
      description: 'Maximum articles to process',
      default: 33,
    },
    listOnly: {
      type: 'boolean',
      flag: '--list-only',
      description: 'Only list reading list URLs without creating EPUB',
      default: false,
    },
    cacheStats: {
      type: 'boolean',
      flag: '--cache-stats',
      description: 'Show cache statistics and exit',
      default: false,
    },
    clearCache: {
      type: 'boolean',
      flag: '--clear-cache',
      description: 'Clear all cache and exit',
      default: false,
    },
  },
})
export class SafariEpubScript extends BaseScript {
  private static BOOKMARKS_PLIST = join(
    process.env.HOME || '',
    'Library/Safari/Bookmarks.plist'
  );

  private pageFetcher!: PageFetcherService;
  private articleDetector!: ArticleDetectorService;

  async validate(ctx: Context): Promise<void> {
    const args = ctx.args as any;

    // Check if bookmarks file exists
    if (!existsSync(SafariEpubScript.BOOKMARKS_PLIST)) {
      this.logger.error(`Safari bookmarks file not found at: ${SafariEpubScript.BOOKMARKS_PLIST}`);
      this.logger.info('Make sure Safari is installed and has been used to add reading list items');
      process.exit(1);
    }

    // Initialize services
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

    this.logger.info('🧭 Safari Reading List to EPUB');

    // Handle cache operations
    if (args.cacheStats) {
      await this.showCacheStats();
      return;
    }

    if (args.clearCache) {
      this.clearCache();
      return;
    }

    // Extract reading list URLs
    const readingListUrls = await this.extractReadingListUrls();

    if (readingListUrls.length === 0) {
      this.logger.warn('No items found in Safari reading list');
      this.logger.info('Add some articles to your Safari reading list and try again');
      return;
    }

    this.logger.info(`Found ${readingListUrls.length} items in reading list`);

    // Apply max articles limit
    let urls = readingListUrls;
    if (args.maxArticles && readingListUrls.length > args.maxArticles) {
      urls = readingListUrls.slice(0, args.maxArticles);
      this.logger.info(`Limited to first ${args.maxArticles} articles`);
    }

    if (args.listOnly) {
      this.displayReadingList(urls);
    } else {
      await this.createEpubFromReadingList(urls, ctx);
    }

    this.logger.success('Safari reading list processing completed');
  }

  /**
   * Extract reading list URLs from Safari bookmarks
   */
  private async extractReadingListUrls(): Promise<string[]> {
    this.logger.info(`Reading Safari bookmarks from: ${SafariEpubScript.BOOKMARKS_PLIST}`);

    try {
      // Convert binary plist to JSON
      const result =
        await $`plutil -convert json -o - ${SafariEpubScript.BOOKMARKS_PLIST}`.quiet();
      const bookmarksData = JSON.parse(result.stdout.toString());

      // Navigate through the plist structure to find reading list
      const children = bookmarksData.Children;
      if (!children || !Array.isArray(children)) {
        this.logger.warn('No Children array found in bookmarks');
        return [];
      }

      // Find the reading list entry
      const readingList = children.find(
        (item: any) => item.Title === 'com.apple.ReadingList'
      );

      if (!readingList || !readingList.Children) {
        this.logger.warn('Reading list not found in bookmarks');
        return [];
      }

      // Extract URLs
      const urls = readingList.Children.map((item: any) => item.URLString).filter(
        (url: string) => url
      );

      this.logger.success(`Extracted ${urls.length} URLs from reading list`);
      return urls;
    } catch (error: any) {
      if (error instanceof ShellError) {
        this.logger.error('Failed to convert bookmarks plist. Make sure plutil is available.');
      } else {
        this.logger.error(`Failed to extract reading list: ${error.message}`);
      }
      return [];
    }
  }

  /**
   * Display reading list URLs
   */
  private displayReadingList(urls: string[]): void {
    this.logger.info('🔖 Safari Reading List URLs\n');

    urls.forEach((url, index) => {
      console.log(`${index + 1}. ${url}`);
    });

    console.log();
    this.logger.success(`Total: ${urls.length} reading list items`);
  }

  /**
   * Create EPUB from reading list
   */
  private async createEpubFromReadingList(urls: string[], ctx: Context): Promise<void> {
    const args = ctx.args as any;

    this.logger.info('📚 Creating EPUB from Reading List');

    // Fetch all pages
    this.logger.info(`Fetching ${urls.length} articles...`);
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

    // Handle images if enabled
    if (args.downloadImages) {
      this.logger.info('Processing images...');
      // Images will be handled during EPUB generation
    }

    // Generate EPUB
    const title = args.epubTitle || this.generateDefaultTitle();
    const author = args.epubAuthor || 'Safari Reader';

    const epubGenerator = new EpubGeneratorService(
      {
        title,
        author,
        description: `Reading list from Safari, created on ${format(new Date(), 'MMMM d, yyyy')}`,
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
    const outputPath = this.getOutputPath(title, args.saveToIcloud);
    await epubGenerator.generate(outputPath);

    this.logger.success('EPUB created successfully!');
    this.logger.info(`EPUB location: ${outputPath}`);

    if (args.saveToIcloud) {
      this.logger.info('Check your iCloud Drive for the EPUB in: SafariEPUB/reading-list/');
    }
  }

  /**
   * Get output path for EPUB
   */
  private getOutputPath(title: string, saveToIcloud: boolean): string {
    const filename = `${title.replace(/[^a-z0-9]/gi, '_').toLowerCase()}.epub`;

    if (saveToIcloud) {
      const icloudPath = join(
        process.env.HOME || '',
        'Library/Mobile Documents/com~apple~CloudDocs/SafariEPUB/reading-list'
      );
      mkdirSync(icloudPath, { recursive: true });
      return join(icloudPath, filename);
    } else {
      const downloadsPath = join(process.env.HOME || '', 'Downloads');
      return join(downloadsPath, filename);
    }
  }

  /**
   * Generate default title
   */
  private generateDefaultTitle(): string {
    return `Readings ${format(new Date(), 'MMM dd, yyyy')}`;
  }

  /**
   * Show cache statistics
   */
  private async showCacheStats(): Promise<void> {
    this.logger.info('📊 Cache Statistics\n');

    const stats = this.pageFetcher.getCacheStats();
    console.log(`Pages: ${stats.pages}`);
    console.log(`Images: ${stats.images}`);
    console.log(`Total size: ${(stats.sizeBytes / 1024 / 1024).toFixed(2)} MB`);

    this.logger.success('Cache statistics displayed');
  }

  /**
   * Clear cache
   */
  private clearCache(): void {
    this.logger.info('🧹 Clearing Cache');
    this.pageFetcher.clearCache();
    this.logger.success('All cache cleared');
  }
}
