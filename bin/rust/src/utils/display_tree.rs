use crate::utils::display::ItemType;
use console::{style, Color};

#[derive(Debug, Clone)]
pub struct TreeNode {
    pub text: String,
    pub size: u64,
    pub item_type: ItemType,
    pub children: Vec<TreeNode>,
}

impl TreeNode {
    pub fn new(text: String, size: u64, item_type: ItemType) -> Self {
        Self {
            text,
            size,
            item_type,
            children: Vec::new(),
        }
    }

    pub fn add_child(&mut self, child: TreeNode) {
        self.children.push(child);
    }
}

pub struct TreeDisplay {
    show_colors: bool,
}

impl TreeDisplay {
    pub fn new(show_colors: bool) -> Self {
        Self { show_colors }
    }

    pub fn print_tree(&self, nodes: &[TreeNode]) {
        if nodes.is_empty() {
            return;
        }

        for (i, node) in nodes.iter().enumerate() {
            let is_last = i == nodes.len() - 1;
            self.print_node(node, "", is_last);
        }
    }

    fn print_node(&self, node: &TreeNode, prefix: &str, is_last: bool) {
        let connector = if is_last { "└── " } else { "├── " };

        let display_name = if self.show_colors {
            match node.item_type {
                ItemType::File => style(&node.text).fg(Color::Cyan).to_string(),
                ItemType::Directory => style(&node.text).fg(Color::Blue).to_string(),
            }
        } else {
            node.text.clone()
        };

        if node.size > 0 {
            let size_str = self.format_size(node.size);
            println!("{}{} {} ({})", prefix, connector, display_name, size_str);
        } else {
            println!("{}{}{}", prefix, connector, display_name);
        }

        if !node.children.is_empty() {
            let child_prefix = if is_last {
                format!("{}    ", prefix)
            } else {
                format!("{}│   ", prefix)
            };

            for (i, child) in node.children.iter().enumerate() {
                let child_is_last = i == node.children.len() - 1;
                self.print_node(child, &child_prefix, child_is_last);
            }
        }
    }

    fn format_size(&self, bytes: u64) -> String {
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
            format!("{:.3}{}", size, UNITS[unit_index])
        };

        if self.show_colors {
            match unit_index {
                3 | 4 => style(formatted).fg(Color::Red).to_string(), // GB, TB
                2 => style(formatted).fg(Color::Yellow).to_string(),  // MB
                1 => style(formatted).fg(Color::Green).to_string(),   // KB
                _ => formatted,
            }
        } else {
            formatted
        }
    }
}
