import { exec } from '../utils/shell';

/**
 * Service for interacting with macOS system_profiler command
 * Provides a clean, structured interface to system_profiler data
 */

export interface SystemProfilerData {
  [key: string]: any;
}

export interface CacheEntry {
  data: SystemProfilerData;
  timestamp: number;
}

export const DATA_TYPES = {
  hardware: 'SPHardwareDataType',
  software: 'SPSoftwareDataType',
  network: 'SPNetworkDataType',
  bluetooth: 'SPBluetoothDataType',
  usb: 'SPUSBDataType',
  firewire: 'SPFireWireDataType',
  thunderbolt: 'SPThunderboltDataType',
  audio: 'SPAudioDataType',
  displays: 'SPDisplaysDataType',
  graphics: 'SPGraphicsDataType',
  memory: 'SPMemoryDataType',
  pci: 'SPPCIDataType',
  storage: 'SPStorageDataType',
  power: 'SPPowerDataType',
  parallel_ata: 'SPPARALLELATADisplayType',
  parallel_scsi: 'SPPARALLELSCSIDisplayType',
  serial_ata: 'SPSATADataType',
  serial_scsi: 'SPSerialSCSIDisplayType',
} as const;

export type DataTypeKey = keyof typeof DATA_TYPES;

export interface SystemProfilerOptions {
  cacheTTL?: number; // in seconds
  debug?: boolean;
}

export class SystemProfilerService {
  private cache: Map<string, CacheEntry> = new Map();
  private cacheTTL: number;
  private debug: boolean;

  constructor(options: SystemProfilerOptions = {}) {
    this.cacheTTL = (options.cacheTTL || 300) * 1000; // Convert to milliseconds, default 5 minutes
    this.debug = options.debug || false;
  }

  /**
   * Get system profiler data for specified data types
   */
  async getData(
    dataTypes: DataTypeKey | DataTypeKey[] = ['hardware', 'software'],
    useCache: boolean = true
  ): Promise<Record<DataTypeKey, SystemProfilerData>> {
    const types = Array.isArray(dataTypes) ? dataTypes : [dataTypes];
    const results: Partial<Record<DataTypeKey, SystemProfilerData>> = {};

    for (const type of types) {
      const typeStr = DATA_TYPES[type] || type;
      if (this.debug) {
        console.log(`Getting system profiler data for ${typeStr}`);
      }
      results[type] = await this.getSingleDataType(typeStr, useCache);
    }

    return results as Record<DataTypeKey, SystemProfilerData>;
  }

  /**
   * Get specific data type
   */
  async getSingleDataType(
    dataType: string,
    useCache: boolean = true
  ): Promise<SystemProfilerData> {
    const cacheKey = `system_profiler_${dataType}`;

    if (useCache && this.isCachedDataAvailable(cacheKey)) {
      if (this.debug) {
        console.log(`Using cached data for ${dataType}`);
      }
      return this.cache.get(cacheKey)!.data;
    }

    if (this.debug) {
      console.log(`Fetching fresh data for ${dataType}`);
    }

    const rawOutput = await exec(`system_profiler ${dataType}`, {
      description: `Getting ${dataType} data`,
    });

    const parsedData = this.parseSystemProfilerOutput(rawOutput);

    if (useCache) {
      this.cache.set(cacheKey, {
        data: parsedData,
        timestamp: Date.now(),
      });
    }

    return parsedData;
  }

  /**
   * Get hardware information
   */
  async hardwareInfo(useCache: boolean = true): Promise<SystemProfilerData> {
    const data = await this.getData('hardware', useCache);
    return data.hardware;
  }

  /**
   * Get software information
   */
  async softwareInfo(useCache: boolean = true): Promise<SystemProfilerData> {
    const data = await this.getData('software', useCache);
    return data.software;
  }

  /**
   * Get power information (battery, charger, etc.)
   */
  async powerInfo(useCache: boolean = true): Promise<SystemProfilerData> {
    const data = await this.getData('power', useCache);
    return data.power;
  }

  /**
   * Get storage information
   */
  async storageInfo(useCache: boolean = true): Promise<SystemProfilerData> {
    const data = await this.getData('storage', useCache);
    return data.storage;
  }

  /**
   * Get network information
   */
  async networkInfo(useCache: boolean = true): Promise<SystemProfilerData> {
    const data = await this.getData('network', useCache);
    return data.network;
  }

  /**
   * Clear cache
   */
  clearCache(): void {
    this.cache.clear();
    if (this.debug) {
      console.log('System profiler cache cleared');
    }
  }

  /**
   * Get cache statistics
   */
  cacheStats(): { entries: number; totalMemoryEstimate: number } {
    return {
      entries: this.cache.size,
      totalMemoryEstimate: this.cache.size * 1024, // Rough estimate
    };
  }

  /**
   * Check if cached data is available and valid
   */
  private isCachedDataAvailable(cacheKey: string): boolean {
    const entry = this.cache.get(cacheKey);
    if (!entry) {
      return false;
    }

    return Date.now() - entry.timestamp < this.cacheTTL;
  }

  /**
   * Parse system_profiler output into structured data
   */
  private parseSystemProfilerOutput(output: string): SystemProfilerData {
    if (!output || output.trim().length === 0) {
      return {};
    }

    const data: SystemProfilerData = {};
    let currentSection: string | null = null;
    let currentSubsection: string | null = null;
    let sectionIndentLevel = 0;

    const lines = output.split('\n');

    for (const line of lines) {
      const trimmedLine = line.trimEnd();
      if (trimmedLine.length === 0) {
        continue;
      }

      // Determine indentation level
      const indentLevel = line.length - line.trimStart().length;
      const contentLine = line.trimStart();

      // Handle section headers (lines ending with ":")
      if (contentLine.endsWith(':')) {
        const sectionName = contentLine.slice(0, -1).trim();

        if (currentSection === null) {
          // Top-level section
          currentSection = sectionName;
          currentSubsection = null;
          sectionIndentLevel = indentLevel;
          data[this.normalizeKey(sectionName)] = {};
        } else if (indentLevel > sectionIndentLevel) {
          // Subsection
          currentSubsection = sectionName;
          if (data[this.normalizeKey(currentSection)]) {
            data[this.normalizeKey(currentSection)][
              this.normalizeKey(sectionName)
            ] = {};
          }
        } else {
          // Back to top level
          currentSection = sectionName;
          currentSubsection = null;
          sectionIndentLevel = indentLevel;
          data[this.normalizeKey(sectionName)] = {};
        }

        continue;
      }

      // Parse key-value pairs
      if (contentLine.includes(':')) {
        const colonIndex = contentLine.indexOf(':');
        const key = contentLine.substring(0, colonIndex).trim();
        const value = contentLine.substring(colonIndex + 1).trim();

        if (!key || !value) {
          continue;
        }

        const normalizedKey = this.normalizeKey(key);
        const processedValue = this.processValue(value);

        if (
          currentSubsection &&
          currentSection &&
          data[this.normalizeKey(currentSection)]?.[
            this.normalizeKey(currentSubsection)
          ] !== undefined
        ) {
          data[this.normalizeKey(currentSection)][
            this.normalizeKey(currentSubsection)
          ][normalizedKey] = processedValue;
        } else if (currentSection && data[this.normalizeKey(currentSection)]) {
          data[this.normalizeKey(currentSection)][normalizedKey] =
            processedValue;
        }
      } else {
        // Handle list items or simple values
        if (
          currentSubsection &&
          currentSection &&
          data[this.normalizeKey(currentSection)]?.[
            this.normalizeKey(currentSubsection)
          ] !== undefined
        ) {
          const target =
            data[this.normalizeKey(currentSection)][
              this.normalizeKey(currentSubsection)
            ];
          if (Array.isArray(target)) {
            target.push(contentLine);
          } else {
            data[this.normalizeKey(currentSection)][
              this.normalizeKey(currentSubsection)
            ] = [contentLine];
          }
        } else if (currentSection && data[this.normalizeKey(currentSection)]) {
          const target = data[this.normalizeKey(currentSection)];
          if (Array.isArray(target)) {
            target.push(contentLine);
          } else {
            data[this.normalizeKey(currentSection)] = [contentLine];
          }
        }
      }
    }

    return data;
  }

  /**
   * Normalize keys to be consistent (snake_case)
   */
  private normalizeKey(key: string): string {
    return key
      .toLowerCase()
      .replace(/[^\w]/g, '_')
      .replace(/_+/g, '_')
      .replace(/^_|_$/g, '');
  }

  /**
   * Process and clean values
   */
  private processValue(value: string): string | number | boolean {
    // Remove extra whitespace
    const trimmedValue = value.trim();

    // Handle common value patterns
    if (/^Yes$/i.test(trimmedValue)) {
      return true;
    }
    if (/^No$/i.test(trimmedValue)) {
      return false;
    }
    if (/^\d+$/.test(trimmedValue)) {
      return parseInt(trimmedValue, 10);
    }
    if (/^\d+\.\d+$/.test(trimmedValue)) {
      return parseFloat(trimmedValue);
    }

    // Parse sizes like "256 GB" or "512 MB"
    const sizeMatch = trimmedValue.match(/^(\d+)\s*([KMGT]?B)$/i);
    if (sizeMatch) {
      const size = sizeMatch[1];
      const unit = sizeMatch[2].toUpperCase();
      return `${size} ${unit}`;
    }

    return trimmedValue;
  }
}
