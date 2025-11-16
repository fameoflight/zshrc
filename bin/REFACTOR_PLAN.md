# Ruby Scripts Refactoring Plan

**Date**: 2025-11-16
**Status**: Proposed
**Strategic Question**: Ruby + Sorbet or TypeScript migration?

## Executive Summary

**Current State**: 41 Ruby scripts with ~650 lines of duplicated code, inconsistent patterns, poor use of OOP/metaprogramming.

**Goal**: Create clean, maintainable architecture that either:
- Makes Ruby scripts excellent with type support (Sorbet/RBS)
- Provides clean patterns to port to TypeScript

## Strategic Decision: Ruby vs TypeScript

### Option A: Modern Ruby with Sorbet

**Pros:**
- Keep existing 41 scripts
- Add gradual typing with Sorbet
- Excellent for shell scripting
- Less boilerplate than TypeScript
- Ruby 3.x pattern matching, fiber, etc.

**Cons:**
- Type support less mature than TypeScript
- Weaker IDE integration
- Smaller ecosystem for some use cases

**Estimated Effort:**
- Refactoring: 1-2 weeks
- Sorbet integration: 1 week
- Total: 2-3 weeks

### Option B: Migrate to TypeScript

**Pros:**
- Strong static typing (compile-time errors)
- Best-in-class IDE support (VSCode)
- Modern tooling ecosystem
- Consistency with other TypeScript projects
- Better refactoring tools

**Cons:**
- Rewrite 41 scripts (~3000 lines)
- More verbose for simple scripts
- Need compilation/bundling
- Less native shell integration

**Estimated Effort:**
- Architecture design: 1 week
- Port scripts: 4-6 weeks (can be incremental)
- Total: 5-7 weeks

### Recommendation: **Refactor Ruby First, Then Decide**

**Phase 1** (1-2 weeks): Fix Ruby architecture
- Immediate value regardless of future direction
- Patterns transfer to TypeScript if needed
- Proves architecture concepts

**Phase 2** (week 3): Evaluate
- Try Sorbet on refactored code
- Prototype 2-3 scripts in TypeScript
- Make informed decision based on real experience

**Phase 3**: Execute chosen path

## Phase 1: Ruby Refactoring (This Plan)

### Priority 1: GitService Class (HIGH IMPACT)

**Problem**: 8+ scripts duplicate git operations, each with subtle differences.

**Current Code** (repeated in 8 files, ~200 lines total):
```ruby
# git-commit-dir.rb:46
unless system('git rev-parse --git-dir >/dev/null 2>&1')
  log_error('Not in a git repository')
  exit 1
end

# git-commit-splitter.rb:134
commit_info = `git log -1 --format='%h - %s' #{commit}`.strip

# git-compress.rb:136
files = `git ls-tree -r --name-only #{commit}`.strip.split("\n")

# Multiple scripts
Dir.chdir(original_working_dir) do
  system("git commit -m '#{message}'")
end
```

**Proposed Solution** (`bin/.common/services/git_service.rb`):
```ruby
# frozen_string_literal: true

module Services
  class GitService
    class GitError < StandardError; end
    class NotInRepositoryError < GitError; end
    class CommitNotFoundError < GitError; end

    def initialize(working_dir = Dir.pwd)
      @working_dir = working_dir
    end

    # Validation
    def in_repository?
      execute('rev-parse --git-dir', silent: true)
      true
    rescue GitError
      false
    end

    def validate_repository!
      raise NotInRepositoryError, 'Not in a git repository' unless in_repository?
    end

    def commit_exists?(ref)
      execute("rev-parse --verify #{ref}", silent: true)
      true
    rescue GitError
      false
    end

    # Information retrieval
    def commit_info(ref, format: '%h - %s')
      execute("log -1 --format='#{format}' #{ref}").strip
    end

    def commit_files(ref)
      execute("ls-tree -r --name-only #{ref}").strip.split("\n")
    end

    def current_branch
      execute('rev-parse --abbrev-ref HEAD').strip
    end

    def unpushed_commits(base_branch)
      current = current_branch
      execute("log #{base_branch}..#{current} --oneline").strip.split("\n")
    end

    # Operations
    def create_commit(message:, files: nil, no_verify: false)
      cmd = ['commit', "-m '#{escape_message(message)}'"]
      cmd << '--no-verify' if no_verify
      cmd << files.join(' ') if files
      execute(cmd.join(' '))
    end

    def create_backup_branch(name = nil)
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      branch_name = name || "backup/#{current_branch}_#{timestamp}"
      execute("branch #{branch_name}")
      branch_name
    end

    def cherry_pick(commit, options = {})
      cmd = ['cherry-pick']
      cmd << '--no-commit' if options[:no_commit]
      cmd << '-x' if options[:record_origin]
      cmd << commit
      execute(cmd.join(' '))
    end

    private

    def execute(command, silent: false)
      full_command = "git #{command}"
      result = nil

      Dir.chdir(@working_dir) do
        result = `#{full_command} 2>&1`.strip
        unless $?.success?
          raise GitError, "Git command failed: #{full_command}\n#{result}" unless silent
          raise GitError
        end
      end

      result
    end

    def escape_message(message)
      message.gsub("'", "'\\\\''")
    end
  end
end
```

**Usage** (before vs after):

**Before** (`git-commit-dir.rb` - 112 lines):
```ruby
class GitCommitDir < ScriptBase
  def validate!
    unless system('git rev-parse --git-dir >/dev/null 2>&1')
      log_error('Not in a git repository')
      exit 1
    end
    super
  end

  def run
    directory = ARGV[0]
    # ... validation ...

    files = Dir.glob("#{directory}/**/*").select { |f| File.file?(f) }
    message = options[:message] || default_message(directory)

    Dir.chdir(original_working_dir) do
      system("git add #{files.join(' ')}")
      commit_command = "git commit -m '#{message}'"
      commit_command += ' --no-verify' if options[:force]
      system(commit_command)
    end
  end
end
```

**After** (52 lines, 54% reduction):
```ruby
class GitCommitDir < GitScriptBase
  validates :git_repository
  validates :directory_exists, arg: 0

  def run
    directory = ARGV[0]
    files = Dir.glob("#{directory}/**/*").select { |f| File.file?(f) }
    message = options[:message] || default_message(directory)

    git_service.create_commit(
      message: message,
      files: files,
      no_verify: options[:force]
    )
  end

  private

  def default_message(directory)
    "Update files in #{File.basename(directory)}"
  end
end
```

**Lines saved**: 60 lines per script × 8 git scripts = **480 lines eliminated**

---

### Priority 2: Validation DSL (HIGH IMPACT)

**Problem**: Every script has 20-40 lines of repetitive validation boilerplate.

**Current Pattern** (repeated in 35+ scripts):
```ruby
def validate!
  if ARGV.empty?
    log_error('File path required')
    show_usage
    exit 1
  end

  unless File.exist?(ARGV[0])
    log_error("File not found: #{ARGV[0]}")
    exit 1
  end

  unless system('git rev-parse --git-dir >/dev/null 2>&1')
    log_error('Not in a git repository')
    exit 1
  end

  super
end
```

**Proposed Solution** (add to `ScriptBase`):
```ruby
class ScriptBase
  class << self
    def validators
      @validators ||= []
    end

    def validates(type, **options)
      validators << { type: type, options: options }
    end
  end

  def validate!
    self.class.validators.each do |validator|
      run_validator(validator[:type], validator[:options])
    end
    super if defined?(super)
  end

  private

  def run_validator(type, options)
    case type
    when :git_repository
      validate_git_repository!
    when :file_exists
      validate_file_exists!(options)
    when :directory_exists
      validate_directory_exists!(options)
    when :not_empty
      validate_not_empty!(options)
    when :custom
      send(options[:method])
    else
      raise ArgumentError, "Unknown validator: #{type}"
    end
  end

  def validate_git_repository!
    return if git_service.in_repository?
    log_error('Not in a git repository')
    show_usage
    exit 1
  end

  def validate_file_exists!(options)
    arg_index = options[:arg] || 0
    optional = options[:optional] || false

    file_path = ARGV[arg_index]
    return if optional && file_path.nil?

    if file_path.nil?
      log_error("File path required at argument #{arg_index}")
      show_usage
      exit 1
    end

    return if File.exist?(file_path)
    log_error("File not found: #{file_path}")
    exit 1
  end

  def validate_directory_exists!(options)
    arg_index = options[:arg] || 0
    dir_path = ARGV[arg_index]

    if dir_path.nil?
      log_error("Directory path required at argument #{arg_index}")
      show_usage
      exit 1
    end

    return if Dir.exist?(dir_path)
    log_error("Directory not found: #{dir_path}")
    exit 1
  end

  def validate_not_empty!(options)
    arg_index = options[:arg]
    field_name = options[:name] || "argument #{arg_index}"

    value = arg_index.nil? ? ARGV : ARGV[arg_index]
    return unless value.nil? || (value.respond_to?(:empty?) && value.empty?)

    log_error("#{field_name.capitalize} cannot be empty")
    show_usage
    exit 1
  end
end
```

**Usage Examples**:

```ruby
class MergePDF < ScriptBase
  validates :file_exists, arg: 0
  validates :file_exists, arg: 1
  validates :not_empty, arg: 0, name: 'output filename'

  def run
    # Validation already done automatically
  end
end

class GitCommitSplitter < GitScriptBase
  validates :git_repository
  validates :custom, method: :validate_current_branch_clean

  private

  def validate_current_branch_clean
    return if git_service.status_clean?
    log_error('Working directory has uncommitted changes')
    exit 1
  end
end
```

**Lines saved**: 20 lines per script × 35 scripts = **700 lines eliminated**

---

### Priority 3: InteractiveSelection Mixin (MEDIUM IMPACT)

**Problem**: 3 different implementations of interactive selection, 150+ duplicate lines.

**Current Code** (`git-history.rb:259-372` - 113 lines):
```ruby
def interactive_select_commit
  commits = get_commits

  # Try fzf first
  if command_available?('fzf')
    selection = IO.popen('fzf --ansi --no-sort --tac', 'r+') do |io|
      commits.each { |c| io.puts c }
      io.close_write
      io.read.strip
    end
    return parse_commit_hash(selection) unless selection.empty?
  end

  # Try peco
  if command_available?('peco')
    # ... 30 lines ...
  end

  # Fallback to simple prompt
  # ... 50 lines ...
end
```

**Proposed Solution** (`bin/.common/concerns/interactive_selection.rb`):
```ruby
module Concerns
  module InteractiveSelection
    SELECTION_TOOLS = %w[fzf peco selecta].freeze

    def interactive_select(items, **options)
      prompt = options[:prompt] || 'Select an item'
      multi = options[:multi] || false
      formatter = options[:formatter] || ->(item) { item.to_s }

      tool = find_available_tool
      return fallback_select(items, prompt, multi, formatter) unless tool

      send("select_with_#{tool}", items, prompt, multi, formatter)
    end

    def fuzzy_search(items, query, **options)
      key_extractor = options[:key] || ->(item) { item.to_s }
      threshold = options[:threshold] || 0.3

      items.map do |item|
        key = key_extractor.call(item)
        score = similarity_score(query.downcase, key.downcase)
        { item: item, score: score }
      end.select { |r| r[:score] >= threshold }
        .sort_by { |r| -r[:score] }
        .map { |r| r[:item] }
    end

    private

    def find_available_tool
      SELECTION_TOOLS.find { |tool| command_available?(tool) }
    end

    def select_with_fzf(items, prompt, multi, formatter)
      args = ['fzf', '--ansi', '--no-sort', '--tac']
      args << '--multi' if multi
      args << "--prompt='#{prompt}: '"

      formatted_items = items.map.with_index do |item, idx|
        "#{formatter.call(item)}|#{idx}"
      end

      selection = IO.popen(args.join(' '), 'r+') do |io|
        formatted_items.each { |line| io.puts line }
        io.close_write
        io.read.strip.split("\n")
      end

      return [] if selection.empty?
      selection.map { |line| items[line.split('|').last.to_i] }
    end

    def select_with_peco(items, prompt, multi, formatter)
      # Similar implementation
    end

    def fallback_select(items, prompt, multi, formatter)
      puts "\n#{prompt}:"
      items.each_with_index do |item, idx|
        puts "  #{idx + 1}. #{formatter.call(item)}"
      end

      print "\nEnter number(s): "
      input = $stdin.gets.strip

      indices = input.split(/[,\s]+/).map { |n| n.to_i - 1 }
      indices.map { |i| items[i] }.compact
    end

    def similarity_score(str1, str2)
      # Levenshtein distance implementation
      # Returns 0.0 to 1.0
    end

    def command_available?(cmd)
      system("which #{cmd} > /dev/null 2>&1")
    end
  end
end
```

**Usage**:
```ruby
class GitHistory < ScriptBase
  include Concerns::InteractiveSelection

  def select_commit
    commits = git_service.log(format: '%h - %s')

    selected = interactive_select(
      commits,
      prompt: 'Select a commit',
      formatter: ->(c) { c }
    )

    selected.first.split(' ').first # Extract hash
  end
end
```

**Lines saved**: 150 lines across 3 scripts = **150 lines eliminated**

---

### Priority 4: Enhanced Base Classes

**Create GitScriptBase** (`bin/.common/git_script_base.rb`):
```ruby
class GitScriptBase < ScriptBase
  include Concerns::InteractiveSelection

  # Automatic git service access
  def git_service
    @git_service ||= Services::GitService.new(original_working_dir)
  end

  # Automatic repository validation
  def validate!
    git_service.validate_repository!
    super
  end

  # Common git operations available to all scripts
  delegate :current_branch, :commit_exists?, :commit_info, :commit_files,
           :create_backup_branch, :create_commit, :cherry_pick,
           to: :git_service

  # Commit message handling
  def get_commit_message(default: nil, required: true)
    message = options[:message] || default

    if message.nil? && required
      print 'Enter commit message: '
      message = $stdin.gets.strip
    end

    validate_commit_message!(message) if required
    message
  end

  private

  def validate_commit_message!(message)
    if message.nil? || message.empty?
      log_error('Commit message cannot be empty')
      exit 1
    end

    if message.length > 72
      log_warning('Commit message is longer than 72 characters')
    end
  end
end
```

---

## Implementation Plan

### Week 1: Core Infrastructure

**Day 1-2: Services Layer**
- [ ] Create `Services::GitService` class
- [ ] Create `Services::XcodeService` class
- [ ] Add tests for core functionality

**Day 3-4: Concerns/Mixins**
- [ ] Create `Concerns::InteractiveSelection` mixin
- [ ] Create `Concerns::FileOperations` mixin
- [ ] Create `Concerns::Validatable` with DSL

**Day 5: Base Classes**
- [ ] Enhance `ScriptBase` with validation DSL
- [ ] Create `GitScriptBase` with git service
- [ ] Create `XcodeScriptBase` with xcode service

### Week 2: Script Refactoring

**Day 1-2: Git Scripts (High Priority)**
- [ ] Refactor `git-commit-dir.rb`
- [ ] Refactor `git-commit-deletes.rb`
- [ ] Refactor `git-commit-renames.rb`
- [ ] Refactor `git-commit-splitter.rb`

**Day 3: Git Scripts (Continued)**
- [ ] Refactor `git-compress.rb`
- [ ] Refactor `git-smart-rebase.rb`
- [ ] Refactor `git-history.rb` (largest, most complex)

**Day 4-5: Other High-Value Scripts**
- [ ] Refactor Xcode scripts
- [ ] Refactor file merge scripts
- [ ] Refactor remaining scripts

### Week 3: Quality & Documentation

**Day 1-2: Testing**
- [ ] Add RSpec or Minitest
- [ ] Write tests for services
- [ ] Write tests for concerns

**Day 3: Type Safety (if staying with Ruby)**
- [ ] Add Sorbet gem
- [ ] Add type signatures to services
- [ ] Add type signatures to base classes

**Day 4-5: Documentation**
- [ ] Update SCRIPTS.md with new patterns
- [ ] Document services API
- [ ] Create migration guide for remaining scripts

---

## Success Metrics

### Code Quality
- **Line count reduction**: 650+ lines eliminated
- **Duplication**: Near-zero duplication in git operations
- **Consistency**: All scripts follow same patterns

### Maintainability
- **New script creation**: 50% less boilerplate
- **Type safety**: 80%+ coverage (with Sorbet)
- **Test coverage**: 70%+ for services/concerns

### Developer Experience
- **IDE support**: Full autocomplete with Sorbet LSP
- **Documentation**: All services documented with YARD
- **Examples**: Every pattern has example usage

---

## TypeScript Migration Path (If Chosen)

After refactoring, if you choose TypeScript, the migration is straightforward:

### Architecture Transfer

**Ruby Service → TypeScript Class**:
```typescript
// services/GitService.ts
export class GitService {
  constructor(private workingDir: string = process.cwd()) {}

  inRepository(): boolean {
    try {
      execSync('git rev-parse --git-dir', {
        cwd: this.workingDir,
        stdio: 'ignore'
      });
      return true;
    } catch {
      return false;
    }
  }

  commitInfo(ref: string, format: string = '%h - %s'): string {
    return execSync(
      `git log -1 --format='${format}' ${ref}`,
      { cwd: this.workingDir, encoding: 'utf8' }
    ).trim();
  }

  // ... rest of methods with full type safety
}
```

**Ruby Validation DSL → TypeScript Decorators**:
```typescript
// decorators/validates.ts
export function ValidatesGitRepository() {
  return function(target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    const original = descriptor.value;
    descriptor.value = async function(...args: any[]) {
      const gitService = new GitService();
      if (!gitService.inRepository()) {
        throw new Error('Not in a git repository');
      }
      return original.apply(this, args);
    };
  };
}

// Usage
class GitCommitDir extends ScriptBase {
  @ValidatesGitRepository()
  async run() {
    // ... implementation
  }
}
```

### Incremental Migration Strategy

**Phase 1**: Core infrastructure (1 week)
- Port GitService
- Port base classes
- Port validators

**Phase 2**: High-value scripts (2-3 weeks)
- Git scripts (highest usage)
- Xcode scripts
- File utilities

**Phase 3**: Remaining scripts (2-3 weeks)
- Lower-priority scripts
- Deprecate Ruby versions gradually

**Total**: 5-7 weeks for complete migration

---

## Recommendation

**Do the Ruby refactoring regardless of future direction:**

1. **Immediate value** - Better code NOW
2. **Learning** - Validates architectural patterns
3. **Easier migration** - Clean architecture transfers to TypeScript
4. **Flexibility** - Can try Sorbet first, then decide

**After refactoring, evaluate:**
- Ruby + Sorbet type coverage
- IDE experience with Sorbet LSP
- Developer satisfaction
- Prototype 2-3 scripts in TypeScript for comparison

**Decision criteria:**
- If Sorbet gives 80%+ type coverage and good IDE support → Stay with Ruby
- If type safety gaps remain critical → Migrate to TypeScript
- Evaluate in Week 3 with real data

---

## Next Steps

1. **Review this plan** - Does this align with your goals?
2. **Choose initial focus** - Start with GitService or validation DSL?
3. **Set timeline** - How urgent is this refactoring?
4. **Decide on TypeScript** - Do after Week 2 refactoring?

Let me know your preferences and I'll begin implementation.
