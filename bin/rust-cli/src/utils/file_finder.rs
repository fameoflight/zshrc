use std::path::{Path, PathBuf};
use std::fs;

/// Types of items to search for
#[allow(dead_code)]
#[derive(Debug, Clone, Copy)]
pub enum SearchType {
    File,
    Directory,
    Both,
}

/// Result of a search operation
#[allow(dead_code)]
#[derive(Debug, Clone)]
pub struct SearchResult {
    pub path: PathBuf,
    pub search_type: SearchType,
    pub depth: usize,
}

/// Find items in directory tree with flexible search criteria
///
/// # Arguments
/// * `start_dir` - Directory to start searching from (usually ".")
/// * `name` - Optional name pattern to match (None matches any name)
/// * `extension` - Optional file extension to match (None matches any extension)
/// * `search_type` - What to search for (files, directories, or both)
/// * `max_depth` - Maximum depth to search (None for unlimited)
///
/// # Examples
/// ```
/// // Find all .xcodeproj directories recursively
/// let results = find_subtree(".", None, Some("xcodeproj"), SearchType::Directory, None);
///
/// // Find all Swift files named "Main"
/// let results = find_subtree(".", Some("Main"), Some("swift"), SearchType::File, None);
///
/// // Find anything named "config" in current directory only
/// let results = find_subtree(".", Some("config"), None, SearchType::Both, Some(1));
/// ```
#[allow(dead_code)]
pub fn find_subtree(
    start_dir: &str,
    name: Option<&str>,
    extension: Option<&str>,
    search_type: SearchType,
    max_depth: Option<usize>,
) -> Vec<SearchResult> {
    let mut results = Vec::new();
    let start_path = Path::new(start_dir);

    if let Ok(entry) = fs::metadata(start_path) {
        search_recursive(start_path, name, extension, search_type, max_depth, 0, &mut results, entry.is_dir());
    }

    results
}

/// Internal recursive search function
#[allow(dead_code)]
fn search_recursive(
    current_dir: &Path,
    name: Option<&str>,
    extension: Option<&str>,
    search_type: SearchType,
    max_depth: Option<usize>,
    current_depth: usize,
    results: &mut Vec<SearchResult>,
    _is_dir: bool,
) {
    // Check if we've exceeded max depth
    if let Some(max) = max_depth {
        if current_depth > max {
            return;
        }
    }

    // Read current directory entries
    let entries = match fs::read_dir(current_dir) {
        Ok(e) => e,
        Err(_) => return,
    };

    for entry in entries.flatten() {
        let path = entry.path();
        let metadata = match fs::metadata(&path) {
            Ok(m) => m,
            Err(_) => continue,
        };

        let is_file = metadata.is_file();
        let is_directory = metadata.is_dir();

        // Check if this entry matches our criteria
        let matches_search_type = match search_type {
            SearchType::File => is_file,
            SearchType::Directory => is_directory,
            SearchType::Both => is_file || is_directory,
        };

        if matches_search_type {
            let matches_name = if let Some(name_pattern) = name {
                // Check if name contains the pattern (case-insensitive)
                path.file_name()
                    .and_then(|n| n.to_str())
                    .map(|n| n.to_lowercase().contains(&name_pattern.to_lowercase()))
                    .unwrap_or(false)
            } else {
                true
            };

            let matches_extension = if let Some(ext_pattern) = extension {
                // Check extension for files
                if is_file {
                    path.extension()
                        .and_then(|e| e.to_str())
                        .map(|e| e.to_lowercase() == ext_pattern.to_lowercase())
                        .unwrap_or(false)
                } else {
                    false
                }
            } else {
                true
            };

            // For directories, check if name contains extension pattern
            let final_extension_match = if is_directory {
                if let Some(ext_pattern) = extension {
                    // For directories, check if name contains the pattern
                    path.file_name()
                        .and_then(|n| n.to_str())
                        .map(|n| n.to_lowercase().contains(&ext_pattern.to_lowercase()))
                        .unwrap_or(false)
                } else {
                    true
                }
            } else {
                matches_extension
            };

            if matches_name && final_extension_match {
                results.push(SearchResult {
                    path: path.clone(),
                    search_type: if is_file { SearchType::File } else { SearchType::Directory },
                    depth: current_depth,
                });
            }
        }

        // Recurse into subdirectories
        if is_directory && current_depth < max_depth.unwrap_or(usize::MAX) {
            search_recursive(
                &path,
                name,
                extension,
                search_type,
                max_depth,
                current_depth + 1,
                results,
                true,
            );
        }
    }
}

/// Convenience function to find first match only
#[allow(dead_code)]
pub fn find_first(
    start_dir: &str,
    name: Option<&str>,
    extension: Option<&str>,
    search_type: SearchType,
    max_depth: Option<usize>,
) -> Option<SearchResult> {
    find_subtree(start_dir, name, extension, search_type, max_depth)
        .into_iter()
        .next()
}

/// Convenience function to check if any item exists matching criteria
#[allow(dead_code)]
pub fn exists(
    start_dir: &str,
    name: Option<&str>,
    extension: Option<&str>,
    search_type: SearchType,
    max_depth: Option<usize>,
) -> bool {
    find_first(start_dir, name, extension, search_type, max_depth).is_some()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_find_by_extension() {
        let temp_dir = TempDir::new().unwrap();
        let base_path = temp_dir.path();

        // Create test files
        fs::write(base_path.join("test.swift"), "test").unwrap();
        fs::write(base_path.join("other.txt"), "test").unwrap();

        // Find Swift files
        let results = find_subtree(
            base_path.to_str().unwrap(),
            None,
            Some("swift"),
            SearchType::File,
            None
        );

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path.file_name().unwrap().to_str().unwrap(), "test.swift");
    }

    #[test]
    fn test_find_by_name() {
        let temp_dir = TempDir::new().unwrap();
        let base_path = temp_dir.path();

        // Create test files
        fs::write(base_path.join("config.json"), "{}").unwrap();
        fs::write(base_path.join("other.json"), "{}").unwrap();

        // Find config files
        let results = find_subtree(
            base_path.to_str().unwrap(),
            Some("config"),
            None,
            SearchType::File,
            None
        );

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].path.file_name().unwrap().to_str().unwrap(), "config.json");
    }

    #[test]
    fn test_find_directories() {
        let temp_dir = TempDir::new().unwrap();
        let base_path = temp_dir.path();

        // Create test directories
        fs::create_dir(base_path.join("Sources")).unwrap();
        fs::create_dir(base_path.join("Resources")).unwrap();
        fs::write(base_path.join("test.txt"), "test").unwrap();

        // Find directories only
        let results = find_subtree(
            base_path.to_str().unwrap(),
            None,
            None,
            SearchType::Directory,
            None
        );

        assert_eq!(results.len(), 2);
        let names: Vec<&str> = results.iter()
            .map(|r| r.path.file_name().unwrap().to_str().unwrap())
            .collect();
        assert!(names.contains(&"Sources"));
        assert!(names.contains(&"Resources"));
    }
}