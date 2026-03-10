import path from "path";
import { readdir, mkdir, rm, copyFile, stat } from "fs/promises";
import { Glob } from "bun";

export interface XcodeCategory {
  name: string;
  groupName: string;
  buildPhase: "sources" | "resources" | "frameworks";
  description: string;
  pathMatch: string[];
  targetSubdir: string;
}

export interface XcodeProjectInfo {
  name: string;
  projectFile: string;
  projectPath: string;
  sourceRoot: string;
}

export interface XcodeFileEntry {
  name: string;
  path: string;
  type: "file" | "directory";
  size?: number;
}

export interface LocatedFile {
  path: string;
  exists: boolean;
  size?: number;
}

const XCODE_CATEGORIES: XcodeCategory[] = [
  {
    name: "app",
    groupName: "App",
    buildPhase: "sources",
    description: "Application entrypoints and app lifecycle files",
    pathMatch: ["app", "application", "main", "scene", "delegate"],
    targetSubdir: "App",
  },
  {
    name: "ui",
    groupName: "UI",
    buildPhase: "sources",
    description: "Views, screens, and UI components",
    pathMatch: ["ui", "views", "screens", "components", "swiftui"],
    targetSubdir: "UI",
  },
  {
    name: "viewmodels",
    groupName: "ViewModels",
    buildPhase: "sources",
    description: "View models and presentation state",
    pathMatch: ["viewmodel", "viewmodels", "presentation"],
    targetSubdir: "ViewModels",
  },
  {
    name: "models",
    groupName: "Models",
    buildPhase: "sources",
    description: "Models, entities, and domain types",
    pathMatch: ["models", "model", "entities", "domain"],
    targetSubdir: "Models",
  },
  {
    name: "services",
    groupName: "Services",
    buildPhase: "sources",
    description: "Networking, persistence, and application services",
    pathMatch: ["services", "service", "network", "api", "repository"],
    targetSubdir: "Services",
  },
  {
    name: "utils",
    groupName: "Utils",
    buildPhase: "sources",
    description: "Utilities, helpers, and shared support code",
    pathMatch: ["utils", "utility", "helpers", "support"],
    targetSubdir: "Utils",
  },
  {
    name: "extensions",
    groupName: "Extensions",
    buildPhase: "sources",
    description: "Swift and Objective-C extensions",
    pathMatch: ["extensions", "extension"],
    targetSubdir: "Extensions",
  },
  {
    name: "resources",
    groupName: "Resources",
    buildPhase: "resources",
    description: "Storyboards, xibs, plist files, JSON, and bundled assets",
    pathMatch: ["resources", "assets", "storyboard", "xib", "plist", "json"],
    targetSubdir: "Resources",
  },
  {
    name: "tests",
    groupName: "Tests",
    buildPhase: "sources",
    description: "Unit tests and UI tests",
    pathMatch: ["tests", "test", "uitests", "spec"],
    targetSubdir: "Tests",
  },
];

const RESOURCE_EXTENSIONS = new Set([
  ".xcassets",
  ".imageset",
  ".appiconset",
  ".storyboard",
  ".xib",
  ".plist",
  ".json",
  ".strings",
  ".xcstrings",
  ".mlmodel",
  ".mlpackage",
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".pdf",
  ".svg",
  ".mov",
  ".mp4",
  ".mp3",
  ".wav",
  ".ttf",
  ".otf",
]);

const SOURCE_EXTENSIONS = new Set([
  ".swift",
  ".m",
  ".mm",
  ".h",
  ".hpp",
  ".cpp",
  ".c",
]);

const IGNORED_DIRS = new Set([
  ".git",
  ".build",
  "build",
  "DerivedData",
  "node_modules",
  "Pods",
  ".idea",
  ".zed",
]);

export class XcodeService {
  static listCategories(): XcodeCategory[] {
    return [...XCODE_CATEGORIES];
  }

  static getCategoryInfo(categoryName: string): XcodeCategory | null {
    return XCODE_CATEGORIES.find((category) => category.name === categoryName) || null;
  }

  static validCategory(categoryName: string): boolean {
    return this.getCategoryInfo(categoryName) !== null;
  }

  static async projectExists(cwd: string = process.cwd()): Promise<boolean> {
    return (await this.currentProject(cwd)) !== null;
  }

  static async currentProject(cwd: string = process.cwd()): Promise<XcodeProjectInfo | null> {
    const glob = new Glob("**/*.xcodeproj");
    const matches: string[] = [];

    for await (const match of glob.scan({ cwd, onlyFiles: false })) {
      if (match.endsWith(".xcodeproj")) {
        matches.push(match);
      }
    }

    if (matches.length === 0) {
      return null;
    }

    matches.sort((a, b) => a.length - b.length || a.localeCompare(b));
    const projectFile = matches[0];
    const projectName = path.basename(projectFile, ".xcodeproj");
    const projectPath = path.resolve(cwd, path.dirname(projectFile));
    const projectRootCandidate = path.join(projectPath, projectName);
    const sourceRoot = await this.exists(projectRootCandidate) ? projectRootCandidate : projectPath;

    return {
      name: projectName,
      projectFile: path.resolve(cwd, projectFile),
      projectPath,
      sourceRoot,
    };
  }

  static async projectSummary(cwd: string = process.cwd()) {
    const project = await this.currentProject(cwd);
    if (!project) {
      return null;
    }

    const rootGroups = await this.getRootGroups(cwd);
    return {
      projectName: project.name,
      projectFile: project.projectFile,
      projectPath: project.projectPath,
      rootGroupsCount: rootGroups.length,
      categoriesAvailable: XCODE_CATEGORIES.length,
    };
  }

  static async getRootGroups(cwd: string = process.cwd()): Promise<Array<{ name: string; path: string }>> {
    const project = await this.currentProject(cwd);
    if (!project) {
      return [];
    }

    const rootEntries = await readdir(project.sourceRoot, { withFileTypes: true });
    return rootEntries
      .filter((entry) => entry.isDirectory())
      .filter((entry) => !IGNORED_DIRS.has(entry.name))
      .map((entry) => ({
        name: entry.name,
        path: path.relative(cwd, path.join(project.sourceRoot, entry.name)) || entry.name,
      }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  static async listDirectoryFiles(directoryPath: string): Promise<XcodeFileEntry[]> {
    const absolutePath = path.resolve(directoryPath);
    const entries = await readdir(absolutePath, { withFileTypes: true });
    const files: XcodeFileEntry[] = [];

    for (const entry of entries) {
      const entryPath = path.join(absolutePath, entry.name);
      if (entry.isDirectory()) {
        files.push({ name: entry.name, path: entryPath, type: "directory" });
      } else {
        const fileStats = await stat(entryPath);
        files.push({ name: entry.name, path: entryPath, type: "file", size: fileStats.size });
      }
    }

    return files.sort((a, b) => {
      if (a.type !== b.type) {
        return a.type === "directory" ? -1 : 1;
      }
      return a.name.localeCompare(b.name);
    });
  }

  static async findFilesInProject(fileName: string, cwd: string = process.cwd()): Promise<LocatedFile[]> {
    const project = await this.currentProject(cwd);
    if (!project) {
      return [];
    }

    const glob = new Glob("**/*");
    const matches: LocatedFile[] = [];
    for await (const candidate of glob.scan({ cwd: project.sourceRoot, onlyFiles: false })) {
      const absolute = path.join(project.sourceRoot, candidate);
      const baseName = path.basename(candidate);
      if (baseName !== fileName) {
        continue;
      }
      if (this.pathContainsIgnoredDirectory(candidate)) {
        continue;
      }

      const fileStats = await stat(absolute).catch(() => null);
      matches.push({
        path: absolute,
        exists: fileStats !== null,
        size: fileStats?.isFile() ? fileStats.size : undefined,
      });
    }

    return matches.sort((a, b) => a.path.localeCompare(b.path));
  }

  static async fileExistsInProject(fileName: string, cwd: string = process.cwd()): Promise<boolean> {
    const matches = await this.findFilesInProject(fileName, cwd);
    return matches.length > 0;
  }

  static inferCategoryFromPath(filePath: string): string {
    const normalized = filePath.toLowerCase();
    const extension = path.extname(normalized);

    if (RESOURCE_EXTENSIONS.has(extension)) {
      return "resources";
    }

    const byPattern = XCODE_CATEGORIES.find((category) =>
      category.pathMatch.some((pattern) => normalized.includes(pattern))
    );

    if (byPattern) {
      return byPattern.name;
    }

    if (normalized.includes("test")) {
      return "tests";
    }

    if (SOURCE_EXTENSIONS.has(extension)) {
      return "ui";
    }

    return "utils";
  }

  static getFileType(filePath: string): string {
    const extension = path.extname(filePath).toLowerCase();
    if (SOURCE_EXTENSIONS.has(extension)) {
      return extension === ".swift" ? "Swift Source" : "Source File";
    }
    if (RESOURCE_EXTENSIONS.has(extension)) {
      return "Resource";
    }
    if (extension === ".framework" || extension === ".xcframework") {
      return "Framework";
    }
    return extension ? `${extension.slice(1).toUpperCase()} File` : "Unknown";
  }

  static getBuildPhase(filePath: string, categoryName?: string): XcodeCategory["buildPhase"] {
    const extension = path.extname(filePath).toLowerCase();
    if (extension === ".framework" || extension === ".xcframework") {
      return "frameworks";
    }

    if (RESOURCE_EXTENSIONS.has(extension)) {
      return "resources";
    }

    return this.getCategoryInfo(categoryName || this.inferCategoryFromPath(filePath))?.buildPhase || "sources";
  }

  static async getTargetDirectory(categoryName: string, cwd: string = process.cwd()): Promise<string> {
    const project = await this.currentProject(cwd);
    const category = this.getCategoryInfo(categoryName);
    if (!project || !category) {
      return cwd;
    }

    return path.join(project.sourceRoot, category.targetSubdir);
  }

  static isResourceFile(filePath: string): boolean {
    return RESOURCE_EXTENSIONS.has(path.extname(filePath).toLowerCase());
  }

  static isAssetCatalog(filePath: string): boolean {
    const lowerPath = filePath.toLowerCase();
    return lowerPath.endsWith(".xcassets") || lowerPath.endsWith(".imageset") || lowerPath.endsWith(".appiconset");
  }

  static getResourceHandlingInfo(filePath: string, categoryName?: string) {
    const extension = path.extname(filePath).toLowerCase();
    const type =
      extension === ".plist"
        ? "info_plist"
        : extension === ".storyboard" || extension === ".xib"
          ? "interface_builder"
          : extension === ".mlmodel" || extension === ".mlpackage"
            ? "core_ml_model"
            : this.isAssetCatalog(filePath)
              ? "asset_catalog"
              : "resource";

    return {
      type,
      targetLocation:
        categoryName && this.getCategoryInfo(categoryName)
          ? this.getCategoryInfo(categoryName)!.targetSubdir
          : "Resources",
      instructions: [
        "Move the file into the recommended project directory.",
        "Xcode will usually detect file system changes automatically in synchronized groups.",
        "Refresh the project navigator if the file does not appear immediately.",
      ],
    };
  }

  static async ensureDirectoryExists(directoryPath: string): Promise<void> {
    await mkdir(directoryPath, { recursive: true });
  }

  static async removePath(targetPath: string): Promise<void> {
    await rm(targetPath, { recursive: true, force: true });
  }

  static async copyDirectoryRecursive(source: string, destination: string): Promise<void> {
    await mkdir(destination, { recursive: true });
    const entries = await readdir(source, { withFileTypes: true });
    for (const entry of entries) {
      const sourcePath = path.join(source, entry.name);
      const destinationPath = path.join(destination, entry.name);
      if (entry.isDirectory()) {
        await this.copyDirectoryRecursive(sourcePath, destinationPath);
      } else {
        await copyFile(sourcePath, destinationPath);
      }
    }
  }

  private static async exists(targetPath: string): Promise<boolean> {
    try {
      await stat(targetPath);
      return true;
    } catch {
      return false;
    }
  }

  private static pathContainsIgnoredDirectory(candidatePath: string): boolean {
    return candidatePath.split(path.sep).some((segment) => IGNORED_DIRS.has(segment));
  }
}
