pub mod display;
pub mod display_tree;
pub mod file_finder;
pub mod logger;

pub use display::{DisplayFormatter, DisplayItem, ItemType};
pub use display_tree::{TreeDisplay, TreeNode};
// Allow unused imports for future use
#[allow(unused_imports)]
pub use file_finder::{SearchResult, SearchType, find_subtree};
#[allow(unused_imports)]
pub use logger::{
    confirm_action, create_progress_bar, log_banner, log_completion, log_debug, log_error,
    log_error_with_context, log_file_created, log_git, log_info, log_install, log_progress,
    log_section, log_success, log_warning, prompt_with_default,
};
