#!pip install pypdf

from pypdf import PdfMerger
import sys

import argparse

import os


def get_pdf_files(dir):
    # make sure dir exists

    if not os.path.exists(dir):
        print(f'Directory {dir} does not exist')
        sys.exit(1)

    pdf_files = []
    for root, dirs, files in os.walk(dir):
        for file in files:
            if file.endswith('.pdf'):
                pdf_files.append(os.path.join(root, file))

    return sorted(pdf_files)


def merge_pdf(pdf_files, output_file):
    # make sure output file does not exist
    if os.path.exists(output_file):
        print(f'File {output_file} already exists')
        sys.exit(1)

    merger = PdfMerger()
    for pdf in pdf_files:
        merger.append(pdf)
    merger.write(output_file)
    merger.close()


def main():
    parser = argparse.ArgumentParser(description='Merge PDF files')
    parser.add_argument(
        'dir', type=str, help='Directory containing PDF files')
    parser.add_argument('output_file', type=str,
                        help='Output file', default='merged.pdf')
    args = parser.parse_args()

    dir = args.dir
    output_file = args.output_file

    # get base name of output file
    output_file = os.path.basename(output_file)

    # if output file does not end with .pdf, append it

    if not output_file.endswith('.pdf'):
        output_file += '.pdf'

    output_file = os.path.join(dir, output_file)

    pdf_files = get_pdf_files(dir)

    print(f'Found {len(pdf_files)} PDF files in {dir}')

    # ask for confirmation

    confirm = input('Do you want to continue? (y/n) ')

    if confirm.lower() != 'y':
        print('Exiting')
        sys.exit(1)

    merge_pdf(pdf_files, output_file)

    print(f'PDF files merged into {output_file}')


if __name__ == '__main__':
    main()
