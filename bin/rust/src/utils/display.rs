use console::{style, Color};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisplayItem {
    pub size: u64,
    pub path: String,
    pub item_type: ItemType,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ItemType {
    File,
    Directory,
}

pub struct DisplayFormatter {
    show_colors: bool,
}

impl DisplayFormatter {
    pub fn new(show_colors: bool) -> Self {
        Self { show_colors }
    }

    pub fn format_size(&self, bytes: u64) -> String {
        const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
        let mut size = bytes as f64;
        let mut unit_index = 0;

        while size >= 1024.0 && unit_index < UNITS.len() - 1 {
            size /= 1024.0;
            unit_index += 1;
        }

        let formatted = if unit_index == 0 {
            format!("{}{}", size as u64, UNITS[unit_index])
        } else {
            format!("{:.1}{}", size, UNITS[unit_index])
        };

        if self.show_colors {
            match unit_index {
                3 | 4 => style(formatted).fg(Color::Red).to_string(), // GB, TB
                2 => style(formatted).fg(Color::Yellow).to_string(),   // MB
                1 => style(formatted).fg(Color::Green).to_string(),   // KB
                _ => formatted,
            }
        } else {
            formatted
        }
    }

    pub fn format_item(&self, item: &DisplayItem) -> String {
        let size_formatted = self.format_size(item.size);
        let type_str = match item.item_type {
            ItemType::File => {
                if self.show_colors {
                    style("FILE").fg(Color::Cyan).to_string()
                } else {
                    "FILE".to_string()
                }
            }
            ItemType::Directory => {
                if self.show_colors {
                    style("DIR").fg(Color::Magenta).to_string()
                } else {
                    "DIR".to_string()
                }
            }
        };

        let path = if self.show_colors {
            match item.item_type {
                ItemType::File => style(&item.path).fg(Color::White).to_string(),
                ItemType::Directory => style(&item.path).fg(Color::Blue).to_string(),
            }
        } else {
            item.path.clone()
        };

        format!("{:<12} {:<8} {}", size_formatted, type_str, path)
    }

    pub fn print_header(&self, title: &str) {
        if self.show_colors {
            println!("{}", style(title).bold().fg(Color::Yellow));
        } else {
            println!("{}", title);
        }

        println!("{:<12} {:<8} {}", "Size", "Format", "Path");
        println!("{}", "-".repeat(60));
    }

    #[allow(dead_code)]
    pub fn print_separator(&self) {
        println!("{}", "-".repeat(60));
    }

    #[allow(dead_code)]
    pub fn print_summary(&self, items: &[DisplayItem]) {
        let total_size: u64 = items.iter().map(|item| item.size).sum();
        let file_count = items.iter().filter(|item| matches!(item.item_type, ItemType::File)).count();
        let dir_count = items.iter().filter(|item| matches!(item.item_type, ItemType::Directory)).count();

        if self.show_colors {
            println!("\n{}", style("Summary:").bold().fg(Color::Yellow));
            println!("  Total size: {}", style(self.format_size(total_size)).fg(Color::Green));
            println!("  Files: {}", style(file_count).fg(Color::Cyan));
            println!("  Directories: {}", style(dir_count).fg(Color::Magenta));
        } else {
            println!("\nSummary:");
            println!("  Total size: {}", self.format_size(total_size));
            println!("  Files: {}", file_count);
            println!("  Directories: {}", dir_count);
        }
    }
}