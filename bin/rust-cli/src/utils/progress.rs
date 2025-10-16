use indicatif::{ProgressBar, ProgressStyle};
use std::time::Duration;

pub struct ProgressReporter {
    bar: ProgressBar,
}

impl ProgressReporter {
    pub fn new(total: u64, message: &str) -> Self {
        let bar = ProgressBar::new(total);
        bar.set_style(
            ProgressStyle::default_bar()
                .template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} {msg}")
                .unwrap()
                .progress_chars("#>-"),
        );
        bar.set_message(message.to_string());
        bar.enable_steady_tick(Duration::from_millis(100));

        Self { bar }
    }

    pub fn inc(&self, delta: u64) {
        self.bar.inc(delta);
    }

    pub fn set_position(&self, pos: u64) {
        self.bar.set_position(pos);
    }

    pub fn finish_with_message(&self, message: &str) {
        self.bar.finish_with_message(message.to_string());
    }
}

impl Drop for ProgressReporter {
    fn drop(&mut self) {
        if !self.bar.is_finished() {
            self.bar.finish();
        }
    }
}