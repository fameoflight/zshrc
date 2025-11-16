import { Script } from '../../core/decorators/Script';
import { Script as BaseScript } from '../../core/base/Script';
import type { Context } from '../../core/types';
import { PDFDocument } from 'pdf-lib';
import { readFileSync, writeFileSync } from 'fs';
import { basename, extname } from 'path';

/**
 * Merge multiple PDF files into a single PDF
 *
 * Merges multiple PDF files into a single PDF file.
 * Uses pdf-lib library for reliable PDF merging.
 *
 * @example
 * merge-pdf output.pdf file1.pdf file2.pdf file3.pdf
 * merge-pdf merged.pdf document1.pdf document2.pdf
 */
@Script({
  emoji: '📄',
  tags: ['pdf', 'merge', 'utils'],
  args: {
    outputFile: {
      type: 'string',
      position: 0,
      required: true,
      description: 'Output PDF file path',
    },
    inputFiles: {
      type: 'array',
      position: 1,
      required: true,
      description: 'Input PDF files to merge (at least one required)',
    },
  },
})
export class MergePDFScript extends BaseScript {
  async validate(ctx: Context): Promise<void> {
    const { outputFile, inputFiles } = ctx.args;

    // Validate output file has .pdf extension
    if (extname(outputFile).toLowerCase() !== '.pdf') {
      throw new Error('Output file must have .pdf extension');
    }

    // Validate we have at least one input file
    if (!Array.isArray(inputFiles) || inputFiles.length === 0) {
      throw new Error('At least one input PDF file is required');
    }

    // Validate all input files exist and are PDFs
    for (const file of inputFiles) {
      if (!(await this.fs.exists(file))) {
        throw new Error(`Input file not found: ${file}`);
      }

      if (!(await this.fs.isFile(file))) {
        throw new Error(`Not a file: ${file}`);
      }

      if (extname(file).toLowerCase() !== '.pdf') {
        throw new Error(`Input file is not a PDF: ${file}`);
      }
    }
  }

  async run(ctx: Context): Promise<void> {
    const { outputFile, inputFiles } = ctx.args;

    this.logger.section('PDF Merging');
    this.logger.info(`Merging ${inputFiles.length} PDF files into ${outputFile}`);

    try {
      // Create a new PDF document
      const mergedPdf = await PDFDocument.create();
      let totalPages = 0;

      // Load and merge each input PDF
      for (let i = 0; i < inputFiles.length; i++) {
        const file = inputFiles[i];
        this.logger.progress(
          `Adding ${basename(file)} (${i + 1}/${inputFiles.length})`
        );

        // Load the PDF file
        const pdfBytes = readFileSync(file);
        const pdf = await PDFDocument.load(pdfBytes);

        // Copy all pages from this PDF
        const copiedPages = await mergedPdf.copyPages(pdf, pdf.getPageIndices());
        copiedPages.forEach((page) => {
          mergedPdf.addPage(page);
          totalPages++;
        });
      }

      // Save the merged PDF
      this.logger.progress('Saving merged PDF...');
      const mergedPdfBytes = await mergedPdf.save();
      writeFileSync(outputFile, mergedPdfBytes);

      this.logger.success(`Created merged PDF: ${outputFile}`);
      this.logger.info(`Total pages: ${totalPages}`);
    } catch (error: any) {
      this.logger.error(`Failed to merge PDFs: ${error.message}`);
      process.exit(1);
    }
  }
}
