import JSZip from 'jszip';
import { v4 as uuidv4 } from 'uuid';
import { format } from 'date-fns';
import { writeFileSync, mkdirSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import Handlebars from 'handlebars';
import type { Logger } from '../types';

/**
 * EPUB chapter/article
 */
export interface EpubChapter {
  title: string;
  content: string; // HTML content
  author?: string;
  url?: string;
  date?: Date;
  images?: EpubImage[];
}

/**
 * EPUB image
 */
export interface EpubImage {
  id: string;
  filename: string;
  data: Buffer;
  mediaType: string;
  url?: string;
}

/**
 * EPUB metadata
 */
export interface EpubMetadata {
  title: string;
  author: string;
  language?: string;
  description?: string;
  publisher?: string;
  date?: Date;
  identifier?: string;
}

/**
 * EPUB Generator Service
 *
 * Creates EPUB3-compliant ebook files from HTML content
 */
export class EpubGeneratorService {
  private logger: Logger;
  private zip: JSZip;
  private metadata: EpubMetadata;
  private chapters: EpubChapter[] = [];
  private images: Map<string, EpubImage> = new Map();
  private imageCounter = 0;
  private templates: Map<string, HandlebarsTemplateDelegate> = new Map();
  private templateDir: string;

  constructor(metadata: EpubMetadata, logger: Logger) {
    this.logger = logger;
    this.metadata = {
      language: 'en',
      date: new Date(),
      identifier: uuidv4(),
      ...metadata,
    };
    this.zip = new JSZip();
    this.templateDir = join(__dirname, '../templates/epub');
    this.loadTemplates();
  }

  /**
   * Load all Handlebars templates
   */
  private loadTemplates(): void {
    const templateFiles = [
      'container.xml.hbs',
      'content.opf.hbs',
      'toc.ncx.hbs',
      'nav.xhtml.hbs',
      'chapter.xhtml.hbs',
    ];

    for (const file of templateFiles) {
      const templatePath = join(this.templateDir, file);
      const templateSource = readFileSync(templatePath, 'utf-8');
      const templateName = file.replace('.hbs', '');
      this.templates.set(templateName, Handlebars.compile(templateSource));
    }

    // Register Handlebars helpers
    Handlebars.registerHelper('escapeXML', (text: string) => {
      return this.escapeXML(text);
    });
  }

  /**
   * Add a chapter to the EPUB
   */
  addChapter(chapter: EpubChapter): void {
    // Process chapter content to extract and register images
    const processedChapter = this.processChapterImages(chapter);
    this.chapters.push(processedChapter);
  }

  /**
   * Add an image to the EPUB
   */
  addImage(image: EpubImage): string {
    this.images.set(image.id, image);
    return image.id;
  }

  /**
   * Generate the EPUB file
   */
  async generate(outputPath: string): Promise<void> {
    this.logger.info('Generating EPUB file...');

    // Create EPUB structure
    this.createMimetype();
    this.createContainer();
    this.createContentOPF();
    this.createTOC();
    this.createChapterFiles();
    this.createStyles();
    this.addImages();

    // Generate ZIP file
    const content = await this.zip.generateAsync({
      type: 'nodebuffer',
      compression: 'DEFLATE',
      compressionOptions: { level: 9 },
    });

    // Ensure output directory exists
    mkdirSync(dirname(outputPath), { recursive: true });

    // Write to file
    writeFileSync(outputPath, content);
    this.logger.success(`EPUB created: ${outputPath}`);
  }

  /**
   * Process chapter content to extract and register images
   */
  private processChapterImages(chapter: EpubChapter): EpubChapter {
    if (!chapter.images || chapter.images.length === 0) {
      return chapter;
    }

    let content = chapter.content;

    // Register images and update references in content
    chapter.images.forEach((image) => {
      this.images.set(image.id, image);

      // Replace image references in content
      const oldSrc = image.url || image.filename;
      const newSrc = `../Images/${image.filename}`;
      content = content.replace(
        new RegExp(`src=["']${oldSrc}["']`, 'g'),
        `src="${newSrc}"`
      );
    });

    return { ...chapter, content };
  }

  /**
   * Create mimetype file (must be first and uncompressed)
   */
  private createMimetype(): void {
    this.zip.file('mimetype', 'application/epub+zip', {
      compression: 'STORE', // No compression for mimetype
    });
  }

  /**
   * Create META-INF/container.xml
   */
  private createContainer(): void {
    const template = this.templates.get('container.xml');
    if (!template) throw new Error('Template container.xml not found');

    const containerXML = template({});
    this.zip.folder('META-INF')!.file('container.xml', containerXML);
  }

  /**
   * Create OEBPS/content.opf (package document)
   */
  private createContentOPF(): void {
    const template = this.templates.get('content.opf');
    if (!template) throw new Error('Template content.opf not found');

    const date = this.metadata.date
      ? format(this.metadata.date, 'yyyy-MM-dd')
      : format(new Date(), 'yyyy-MM-dd');

    const manifestItems = this.generateManifestItems();
    const spineItems = this.generateSpineItems();

    const contentOPF = template({
      identifier: this.escapeXML(this.metadata.identifier!),
      title: this.escapeXML(this.metadata.title),
      author: this.escapeXML(this.metadata.author),
      language: this.metadata.language,
      date,
      description: this.metadata.description ? this.escapeXML(this.metadata.description) : undefined,
      publisher: this.metadata.publisher ? this.escapeXML(this.metadata.publisher) : undefined,
      modified: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
      manifestItems,
      spineItems,
    });

    this.zip.folder('OEBPS')!.file('content.opf', contentOPF);
  }

  /**
   * Generate manifest items for all content
   */
  private generateManifestItems(): Array<{ id: string; href: string; mediaType: string }> {
    const items: Array<{ id: string; href: string; mediaType: string }> = [];

    // Add chapter files
    this.chapters.forEach((_, index) => {
      items.push({
        id: `chapter${index + 1}`,
        href: `Text/chapter${index + 1}.xhtml`,
        mediaType: 'application/xhtml+xml',
      });
    });

    // Add images
    this.images.forEach((image) => {
      items.push({
        id: image.id,
        href: `Images/${image.filename}`,
        mediaType: image.mediaType,
      });
    });

    return items;
  }

  /**
   * Generate spine items for reading order
   */
  private generateSpineItems(): Array<{ idref: string }> {
    return this.chapters.map((_, index) => ({
      idref: `chapter${index + 1}`,
    }));
  }

  /**
   * Create OEBPS/toc.ncx (NCX table of contents for EPUB2 compatibility)
   */
  private createTOC(): void {
    const template = this.templates.get('toc.ncx');
    if (!template) throw new Error('Template toc.ncx not found');

    const navPoints = this.chapters.map((chapter, index) => ({
      playOrder: index + 1,
      text: this.escapeXML(chapter.title),
      src: `Text/chapter${index + 1}.xhtml`,
    }));

    const tocNCX = template({
      identifier: this.escapeXML(this.metadata.identifier!),
      title: this.escapeXML(this.metadata.title),
      navPoints,
    });

    this.zip.folder('OEBPS')!.file('toc.ncx', tocNCX);

    // Also create nav.xhtml for EPUB3
    this.createNav();
  }

  /**
   * Create EPUB3 navigation document
   */
  private createNav(): void {
    const template = this.templates.get('nav.xhtml');
    if (!template) throw new Error('Template nav.xhtml not found');

    const navItems = this.chapters.map((chapter, index) => ({
      href: `Text/chapter${index + 1}.xhtml`,
      title: this.escapeXML(chapter.title),
    }));

    const navXHTML = template({ navItems });
    this.zip.folder('OEBPS')!.file('nav.xhtml', navXHTML);
  }

  /**
   * Create chapter XHTML files
   */
  private createChapterFiles(): void {
    const textFolder = this.zip.folder('OEBPS')!.folder('Text')!;

    this.chapters.forEach((chapter, index) => {
      const chapterXHTML = this.createChapterXHTML(chapter, index + 1);
      textFolder.file(`chapter${index + 1}.xhtml`, chapterXHTML);
    });
  }

  /**
   * Create XHTML content for a chapter
   */
  private createChapterXHTML(chapter: EpubChapter, chapterNum: number): string {
    const template = this.templates.get('chapter.xhtml');
    if (!template) throw new Error('Template chapter.xhtml not found');

    return template({
      title: this.escapeXML(chapter.title),
      author: chapter.author ? this.escapeXML(chapter.author) : undefined,
      date: chapter.date ? format(chapter.date, 'MMMM d, yyyy') : undefined,
      url: chapter.url ? this.escapeXML(chapter.url) : undefined,
      content: chapter.content,
    });
  }

  /**
   * Create default stylesheet
   */
  private createStyles(): void {
    const cssPath = join(this.templateDir, 'style.css');
    const css = readFileSync(cssPath, 'utf-8');
    this.zip.folder('OEBPS')!.folder('Styles')!.file('style.css', css);
  }

  /**
   * Add images to EPUB
   */
  private addImages(): void {
    if (this.images.size === 0) return;

    const imagesFolder = this.zip.folder('OEBPS')!.folder('Images')!;

    this.images.forEach((image) => {
      imagesFolder.file(image.filename, image.data);
    });

    this.logger.info(`Added ${this.images.size} images to EPUB`);
  }

  /**
   * Escape XML special characters
   */
  private escapeXML(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  /**
   * Get chapter count
   */
  getChapterCount(): number {
    return this.chapters.length;
  }

  /**
   * Get image count
   */
  getImageCount(): number {
    return this.images.size;
  }
}
