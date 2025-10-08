use crate::commands::command_trait::CommandTrait;
use crate::utils::{DisplayFormatter, DisplayItem, ItemType, TreeDisplay, TreeNode};
use clap::{Arg, ArgMatches};
use std::fs::File;
use std::io::{BufRead, BufReader};

/// Disk Usage Command - analyzes du output to show largest files and directory structure
pub struct DiskUsageCommand;

impl CommandTrait for DiskUsageCommand {
    fn name() -> &'static str {
        "disk-usage"
    }

    fn help() -> &'static str {
        "Fast disk usage analyzer"
    }

    fn execute(matches: &ArgMatches) -> anyhow::Result<()> {
        run_disk_usage(matches)
    }

    fn build_command() -> clap::Command {
        clap::Command::new(Self::name())
            .about(Self::help())
            .arg(
                Arg::new("depth")
                    .short('d')
                    .long("depth")
                    .value_name("DEPTH")
                    .help("Directory tree depth to analyze (default: 3)")
                    .default_value("3"),
            )
            .arg(
                Arg::new("files")
                    .short('f')
                    .long("files")
                    .value_name("COUNT")
                    .help("Number of largest files to show (default: 5)")
                    .default_value("5"),
            )
            .arg(
                Arg::new("input")
                    .help("Input du output file to analyze")
                    .required(true),
            )
    }
}

pub fn run_disk_usage(matches: &ArgMatches) -> anyhow::Result<()> {
    let depth: usize = matches.get_one::<String>("depth").unwrap().parse()?;
    let file_count: usize = matches.get_one::<String>("files").unwrap().parse()?;
    let file_path = matches.get_one::<String>("input").unwrap();

    // Parse the du output
    let file = File::open(&file_path)?;
    let reader = BufReader::new(file);

    let mut all_entries = Vec::new();

    println!("📊 Processing du output from: {}", file_path);

    // Parse du output and collect all entries
    for line in reader.lines() {
        let line = line?;
        let mut parts = line.split_whitespace();
        let size_str = parts.next().unwrap_or("0");
        let path = parts.collect::<Vec<_>>().join(" ");

        if path.is_empty() {
            continue;
        }

        let size: u64 = size_str.parse().unwrap_or(0) * 1024; // du reports in KB, convert to bytes

        // Better heuristic: directories in du output are usually paths that contain subdirectories
        // Files tend to be leaf nodes with extensions or specific patterns
        let is_file = path.contains('.')
            && (path.ends_with(".txt")
                || path.ends_with(".log")
                || path.ends_with(".pdf")
                || path.ends_with(".mp4")
                || path.ends_with(".mov")
                || path.ends_with(".dmg")
                || path.ends_with(".jpg")
                || path.ends_with(".png")
                || path.ends_with(".zip")
                || path.ends_with(".tar")
                || path.ends_with(".gz")
                || path.ends_with(".app")
                || !path.contains('/')); // Single file in root

        let item_type = if is_file {
            ItemType::File
        } else {
            ItemType::Directory
        };

        all_entries.push(DisplayItem {
            size,
            path,
            item_type,
        });
    }

    // Sort by size (largest first)
    all_entries.sort_by(|a, b| b.size.cmp(&a.size));

    // Initialize display formatter
    let formatter = DisplayFormatter::new(true); // Enable colors

    // Show largest files
    formatter.print_header(&format!("📁 Top {} largest files:", file_count));

    let mut file_count_shown = 0;
    for entry in all_entries.iter() {
        if matches!(entry.item_type, ItemType::File) && file_count_shown < file_count {
            println!("{}", formatter.format_item(entry));
            file_count_shown += 1;
        }
    }

    // Build tree structure for display
    let tree_nodes = build_tree_structure(&all_entries, depth, file_count);

    // Show directory tree structure
    println!("\n🌳 Directory tree structure:");
    let tree_display = TreeDisplay::new(true);
    tree_display.print_tree(&tree_nodes);

    Ok(())
}

fn build_tree_structure(
    items: &[DisplayItem],
    max_depth: usize,
    max_files: usize,
) -> Vec<TreeNode> {
    if items.is_empty() {
        return Vec::new();
    }

    // Find common root to strip
    let common_root = find_common_prefix(items);

    // Group items by parent path
    let mut children_map: std::collections::HashMap<String, Vec<&DisplayItem>> =
        std::collections::HashMap::new();
    let mut root_items = Vec::new();

    for item in items {
        let relative_path = if !common_root.is_empty() {
            item.path
                .strip_prefix(&common_root)
                .unwrap_or(&item.path)
                .trim_start_matches('/')
        } else {
            item.path.trim_start_matches('/')
        };

        if relative_path.is_empty() {
            continue;
        }

        if let Some(parent_path) = relative_path.rfind('/') {
            let parent = relative_path[..parent_path].to_string();
            children_map
                .entry(parent)
                .or_insert_with(Vec::new)
                .push(item);
        } else {
            root_items.push(item);
        }
    }

    // Sort root items by size
    root_items.sort_by(|a, b| b.size.cmp(&a.size));

    // Build tree nodes recursively
    let mut tree_nodes = Vec::new();
    for item in root_items {
        let node = build_tree_node(item, &children_map, 0, max_depth, max_files, &common_root);
        tree_nodes.push(node);
    }

    tree_nodes
}

fn build_tree_node(
    item: &DisplayItem,
    children_map: &std::collections::HashMap<String, Vec<&DisplayItem>>,
    current_depth: usize,
    max_depth: usize,
    max_files: usize,
    common_root: &str,
) -> TreeNode {
    let relative_path = if !common_root.is_empty() {
        item.path
            .strip_prefix(common_root)
            .unwrap_or(&item.path)
            .trim_start_matches('/')
    } else {
        item.path.trim_start_matches('/')
    };

    let name = relative_path
        .split('/')
        .last()
        .unwrap_or(&relative_path)
        .to_string();

    let mut node = TreeNode::new(name, item.size, item.item_type.clone());

    // Add children if within depth limit
    if current_depth < max_depth {
        if let Some(children) = children_map.get(relative_path) {
            let mut sorted_children: Vec<&DisplayItem> = children.to_vec();
            sorted_children.sort_by(|a, b| b.size.cmp(&a.size));

            // Limit to max_files per directory
            for child in sorted_children.iter().take(max_files) {
                let child_node = build_tree_node(
                    child,
                    children_map,
                    current_depth + 1,
                    max_depth,
                    max_files,
                    common_root,
                );
                node.add_child(child_node);
            }
        }
    }

    node
}

fn find_common_prefix(items: &[DisplayItem]) -> String {
    if items.is_empty() {
        return String::new();
    }

    let first_path = &items[0].path;
    let mut common_chars = 0;

    'outer: for (i, c) in first_path.chars().enumerate() {
        for item in &items[1..] {
            if let Some(char_at_i) = item.path.chars().nth(i) {
                if char_at_i != c {
                    break 'outer;
                }
            } else {
                break 'outer;
            }
        }
        common_chars += 1;
    }

    // Find the last slash before the divergence point
    if let Some(last_slash) = first_path[..common_chars].rfind('/') {
        first_path[..last_slash].to_string()
    } else {
        String::new()
    }
}
