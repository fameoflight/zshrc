# Ruby CLI Tools

Collection of Ruby-based CLI utilities for system automation and development tasks.

## Installation

```bash
cd bin/ruby-cli
bundle install
```

## Usage

Scripts are located in the `bin/` directory. Common tools include:

- `xcode-*` - Xcode project management utilities
- `game-mode` - System optimization for gaming
- `youtube-transcript-chat` - YouTube transcript processing with AI
- `openrouter-usage` - API usage tracking
- And many more...

## Architecture

- `bin/` - Executable scripts
- `lib/` - Shared libraries and helpers
  - `script_helpers.rb` - Simplified framework for most scripts
  - `llm_services/` - LLM-related services (preserved for complex scripts)

## Development

Scripts use a simplified helper framework. For new scripts:

```ruby
#!/usr/bin/env ruby
require_relative '../lib/script_helpers'

class MyScript
  include ScriptHelpers

  def initialize
    super
  end

  def run
    log_banner("My Script")
    # Your logic here
    log_success("Done!")
  end
end

MyScript.new.run if __FILE__ == $0
```