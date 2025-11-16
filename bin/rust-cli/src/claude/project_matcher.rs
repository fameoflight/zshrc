// Fuzzy project name matching

use fuzzy_matcher::skim::SkimMatcherV2;
use fuzzy_matcher::FuzzyMatcher;

pub struct ProjectMatcher {
    matcher: SkimMatcherV2,
}

impl ProjectMatcher {
    pub fn new() -> Self {
        Self {
            matcher: SkimMatcherV2::default(),
        }
    }

    /// Match a pattern against a list of project names
    /// Returns all matching projects sorted by match score
    pub fn match_projects(&self, pattern: &str, projects: &[String]) -> Vec<String> {
        // First, try exact match
        if projects.iter().any(|p| p == pattern) {
            return vec![pattern.to_string()];
        }

        // Then try fuzzy matching
        let mut scored_projects: Vec<(i64, String)> = projects
            .iter()
            .filter_map(|project| {
                self.matcher
                    .fuzzy_match(project, pattern)
                    .map(|score| (score, project.clone()))
            })
            .collect();

        // Sort by score (descending)
        scored_projects.sort_by(|a, b| b.0.cmp(&a.0));

        // Return just the project names
        scored_projects.into_iter().map(|(_, name)| name).collect()
    }

    /// Check if pattern matches project name
    pub fn matches(&self, pattern: &str, project: &str) -> bool {
        project == pattern || self.matcher.fuzzy_match(project, pattern).is_some()
    }

    /// Normalize project directory name to friendly name
    /// "-Users-hemantv-zshrc" -> "zshrc"
    pub fn normalize_project_name(dir_name: &str) -> String {
        if let Some(last_part) = dir_name.split('-').last() {
            last_part.to_string()
        } else {
            dir_name.to_string()
        }
    }

    /// Get user-friendly project name from directory name
    /// Handles Claude's project directory naming convention
    pub fn friendly_name(dir_name: &str) -> String {
        // Claude project dirs are like: -Users-hemantv-workspace-myproject
        // Extract the meaningful part (everything after the last -)
        let parts: Vec<&str> = dir_name.split('-').collect();

        // If it looks like a path, take the last few components
        if parts.len() > 3 && dir_name.starts_with('-') {
            // Take last 2-3 parts for context
            let meaningful_parts: Vec<&str> = parts.iter().rev().take(2).rev().copied().collect();
            meaningful_parts.join("-")
        } else {
            dir_name.to_string()
        }
    }
}

impl Default for ProjectMatcher {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_exact_match() {
        let matcher = ProjectMatcher::new();
        let projects = vec![
            "zshrc".to_string(),
            "electron-template".to_string(),
            "my-app".to_string(),
        ];

        let result = matcher.match_projects("zshrc", &projects);
        assert_eq!(result, vec!["zshrc".to_string()]);
    }

    #[test]
    fn test_fuzzy_match() {
        let matcher = ProjectMatcher::new();
        let projects = vec![
            "electron-codeblocks".to_string(),
            "electron-template".to_string(),
            "electron-docs".to_string(),
            "zshrc".to_string(),
        ];

        let result = matcher.match_projects("electron", &projects);
        assert_eq!(result.len(), 3);
        assert!(result.iter().all(|p| p.contains("electron")));
    }

    #[test]
    fn test_normalize_project_name() {
        assert_eq!(
            ProjectMatcher::normalize_project_name("-Users-hemantv-zshrc"),
            "zshrc"
        );
        assert_eq!(
            ProjectMatcher::normalize_project_name("simple-project"),
            "project"
        );
    }

    #[test]
    fn test_friendly_name() {
        assert_eq!(
            ProjectMatcher::friendly_name("-Users-hemantv-workspace-myapp"),
            "workspace-myapp"
        );
        assert_eq!(
            ProjectMatcher::friendly_name("-Users-hemantv-zshrc"),
            "hemantv-zshrc"
        );
        assert_eq!(
            ProjectMatcher::friendly_name("simple-name"),
            "simple-name"
        );
    }
}
