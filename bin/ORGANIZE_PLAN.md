# ZSH Scripts Organization Plan

**Status:** In Progress (73% Complete)
**Started:** 2025-11-16
**Branch:** `claude/organize-zshrc-017tJYfw2RwJsT5xf4gQbbz7`

---

## Executive Summary

Implementing a **metadata-based organization system** for 158 scripts across Ruby, Python, Shell, and Rust. Instead of moving files, we're adding standardized headers that enable:

- **Category-based discovery** - Find scripts by what they do (git, media, system, etc.)
- **Auto-generated documentation** - categories.yml generated from script headers
- **Enhanced tooling** - Improved `list-scripts` command with filtering
- **ZSH completion** - Tab completion by category and tags
- **Language flexibility** - Easy to rewrite scripts without moving files

---

## Organizational Approach

### Metadata Header Standard

All scripts get standardized headers:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
# @category: git
# @description: Split large commits into smaller logical commits
# @tags: automation, interactive, refactor
```

### Standard Categories

1. **git** - Git operations and automation
2. **media** - Image/video/audio processing
3. **system** - System utilities and management
4. **setup** - Installation and configuration
5. **backup** - Backup and restore tools
6. **dev** - Development tools and utilities
7. **files** - File operations and manipulation
8. **data** - Data processing and analysis
9. **communication** - Email, messaging, etc.

### Key Benefits

✅ **No file moves** - Keep existing directory structure
✅ **Language agnostic** - Easy to rewrite Python → Rust
✅ **Discoverable** - Find by purpose, not language
✅ **Self-documenting** - Headers make purpose clear
✅ **Auto-generated** - categories.yml stays in sync
✅ **Gradual adoption** - Add headers incrementally

---

## What's Been Completed ✅

### 1. Documentation Framework (4 Files)

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| `SCRIPT_METADATA.md` | 207 | Metadata header standard | ✅ Complete |
| `RULES.md` | 1,043 | Script-specific patterns (Ruby/Python/Shell) | ✅ Complete |
| `PRINCIPLES.md` | 730 | Universal engineering principles | ✅ Complete |
| `ORGANIZE_PLAN.md` | (this file) | Organization plan and tracking | 🔄 In Progress |

**Total:** 1,980+ lines of comprehensive documentation

### 2. Tooling Infrastructure (1 Script)

| Tool | Language | Purpose | Status |
|------|----------|---------|--------|
| `generate-categories.rb` | Ruby | Auto-generate categories.yml from headers | ✅ Complete |

**Features:**
- Scans all scripts for `@category:` headers
- Validates metadata
- Shows scripts missing headers
- Generates YAML with full metadata

### 3. Ruby Scripts with Headers (29/40 = 73%)

#### Git Operations (9/9) ✅

| Script | Description | Tags |
|--------|-------------|------|
| `git-commit-deletes.rb` | Commit only deleted files | automation, interactive, cleanup |
| `git-commit-dir.rb` | Commit directory changes | automation, interactive |
| `git-commit-renames.rb` | Commit pure renames (R100) | automation, interactive, refactor |
| `git-commit-splitter.rb` | Split large commits | automation, interactive, refactor |
| `git-smart-rebase.rb` | Intelligent rebase with auto-resolution | automation, interactive, rebase |
| `git-compress.rb` | Compress git history | cleanup, optimization |
| `git-history.rb` | Find files in git history | search, interactive, history |
| `git-common.rb` | Find common files between commits | analysis, comparison |
| `git-template.rb` | Create repos from templates | automation, interactive, template |

#### System Utilities (6 scripts) ✅

| Script | Category | Description | Tags |
|--------|----------|-------------|------|
| `battery-info.rb` | system | Battery and power info | macos, monitoring, hardware |
| `game-mode.rb` | system | Toggle gaming display mode | macos, gaming, display, optimization |
| `spotlight-manage.rb` | system | Spotlight indexing management | macos, privacy, spotlight, optimization |
| `stacked-monitor.rb` | system | 4-monitor display setup | macos, display, multi-monitor |
| `check-camera-mic.rb` | system | Monitor camera/mic usage | macos, privacy, monitoring |
| `uninstall-app.rb` | system | Comprehensive app uninstaller | macos, cleanup, uninstall |

#### Development Tools (9 scripts) ✅

| Script | Description | Tags |
|--------|-------------|------|
| `xcode-icon-generator.rb` | Generate app icons | xcode, ios, macos, image-processing |
| `xcode-add-file.rb` | Add files to Xcode project | xcode, project-management |
| `xcode-delete-file.rb` | Remove files from Xcode | xcode, project-management, cleanup |
| `xcode-view-files.rb` | View project files | xcode, project-management, inspection |
| `xcode-list-categories.rb` | List file categories | xcode, project-management |
| `auto-retry.rb` | LLM-powered command retry | automation, llm, debugging |
| `console-log-remover.rb` | Remove console.log | cleanup, javascript, automation |
| `electron-icon-generator.rb` | Generate Electron icons | electron, icon-generation, image-processing |

#### File Operations (5 scripts) ✅

| Script | Description | Tags |
|--------|-------------|------|
| `change-extension.rb` | Change file associations | macos, file-associations, automation |
| `comment-only-changes.rb` | Detect comment-only changes | analysis, git, code-review |
| `largest-files.rb` | Find largest files | analysis, search, optimization |
| `merge-markdown.rb` | Merge markdown files | markdown, merge, documentation |
| `merge-pdf.rb` | Merge PDF files | pdf, merge, documentation |

#### Media Processing (1 script) ✅

| Script | Description | Tags |
|--------|-------------|------|
| `clip-video.rb` | FFmpeg video clipper | video, ffmpeg, editing |

### 4. Git Commits (5 commits)

| Commit | Files Changed | Description |
|--------|---------------|-------------|
| `4ba26ce` | 4 | Add documentation and tooling |
| `8005de2` | 9 | Git scripts headers |
| `55cace0` | 9 | System/Dev scripts headers |
| `7f6b092` | 6 | File operation scripts headers |
| `456337d` | 5 | Additional Ruby scripts |

**All changes pushed to:** `origin/claude/organize-zshrc-017tJYfw2RwJsT5xf4gQbbz7`

---

## What Remains 🔄

### 1. Ruby Scripts Without Headers (11/40 = 27%)

#### Communication (2 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `gmail-inbox.rb` | communication | Gmail inbox management with archiving |
| `youtube-transcript-chat.rb` | media | YouTube transcript chat interface |

#### Data Processing (3 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `llm-generate.rb` | dev | LLM-powered command generator |
| `network-speed.rb` | system | Network speed test |
| `openrouter-usage.rb` | data | OpenRouter API usage tracking |

#### Media/Documents (2 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `safari-epub.rb` | files | Convert Safari pages to EPUB |
| `website-epub.rb` | files | Convert websites to EPUB |

#### Internal/Testing (4 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `internal-find-orphaned-targets.rb` | dev | Find orphaned Makefile targets |
| `investigate-naval-js.rb` | dev | Naval.js investigation tool |
| `setup-dev-tools.rb` | setup | Development tools setup |
| `test-click-naval.rb` | dev | Naval clicker test |

### 2. Python Scripts (7 scripts)

#### Image Processing (3 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `pytorch_inference.py` | media | PyTorch model inference CLI |
| `image_upscale_direct.py` | media | Direct image upscaling |
| `find-similar-images.py` | media | Image similarity detection |

#### Video Processing (3 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `video_upscale_direct.py` | media | Video upscaling |
| `video_upscale_demo.py` | media | Demo video upscaler |
| `rife_interpolation.py` | media | RIFE video interpolation |

#### System (1 script)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `enable_displays.py` | system | Display configuration |

### 3. Shell Scripts (13 scripts)

#### Setup Scripts (6 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `agent-setup.sh` | setup | Agent configuration |
| `claude-setup.sh` | setup | Claude Code CLI setup |
| `gemini-setup.sh` | setup | Gemini CLI setup |
| `iterm-setup.sh` | setup | iTerm2 configuration |
| `setup-hooks.sh` | setup | Git hooks setup |
| `macos-optimize.sh` | setup | macOS developer optimizations |

#### Backup Scripts (5 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `xcode-backup.sh` | backup | Backup Xcode settings |
| `vscode-backup.sh` | backup | Backup VS Code settings |
| `iterm-backup.sh` | backup | Backup iTerm2 configuration |
| `dropbox-backup.sh` | backup | Move to Dropbox with symlinks |
| `macos-oled-optimize.sh` | system | OLED screen optimization |

#### Utility Scripts (2 scripts)

| Script | Proposed Category | Description |
|--------|-------------------|-------------|
| `calibre-update.sh` | system | Update Calibre e-book manager |
| `detect-human` | media | Human detection (no extension) |

**Note:** These scripts also need consistent file extensions added.

### 4. Scripts Without Extensions (3 files)

| Script | Type | Fix Needed |
|--------|------|------------|
| `upscale-image` | Shell | Add `.sh` extension |
| `upscale-directory` | Shell | Add `.sh` extension |
| `upscale-video` | Shell | Add `.sh` extension |

### 5. Cleanup Tasks

| Task | File | Action |
|------|------|--------|
| Delete duplicate | `dropbox-backup copy.sh` | Remove |
| Add extensions | `upscale-*` files | Rename with `.sh` |
| Add extensions | `detect-human` | Identify type, add extension |

---

## Implementation Phases

### Phase 1: Complete Headers ✅ (In Progress - 73%)

**Status:** 29/71 scripts with headers (41% of all non-Rust scripts)

**Remaining:**
- [ ] 11 Ruby scripts
- [ ] 7 Python scripts
- [ ] 13 Shell scripts

**Estimated time:** 1-2 hours

### Phase 2: Generate & Validate

- [ ] Run `generate-categories.rb` to create categories.yml
- [ ] Validate all headers are correct
- [ ] Review category distribution
- [ ] Commit categories.yml

**Estimated time:** 15 minutes

### Phase 3: Tooling Integration

#### 3a. Wrapper Function

Create `generate-categories` wrapper in `bin/ruby-cli/scripts.zsh`:

```bash
generate-categories() {
    BUNDLE_GEMFILE="$ZSH_CONFIG/bin/ruby-cli/Gemfile" \
    bundle exec ruby "$ZSH_CONFIG/bin/ruby-cli/bin/generate-categories.rb" "$@"
}
```

#### 3b. Enhanced list-scripts

Update `list-scripts` in `bin/ruby-cli/scripts.zsh`:

```bash
list-scripts() {
    local category=""
    local format="grouped"  # grouped, flat, category-only

    case "$1" in
        --category|-c)
            category="$2"
            ;;
        --flat)
            format="flat"
            ;;
        --help|-h)
            echo "Usage: list-scripts [OPTIONS] [category]"
            echo ""
            echo "Options:"
            echo "  -c, --category CATEGORY  Show scripts in category"
            echo "  --flat                   Flat list (no grouping)"
            echo "  --help                   Show this help"
            return 0
            ;;
    esac

    # Implementation using categories.yml
    # Parse YAML and display scripts by category
}
```

**Estimated time:** 1 hour

### Phase 4: ZSH Completion

Create `_list-scripts` completion function:

```bash
#compdef list-scripts

_list-scripts() {
    local -a categories
    categories=(
        'git:Git operations'
        'media:Media processing'
        'system:System utilities'
        'setup:Setup scripts'
        'backup:Backup tools'
        'dev:Development tools'
        'files:File operations'
        'data:Data processing'
        'communication:Communication tools'
    )

    _describe 'category' categories
}
```

**Estimated time:** 30 minutes

### Phase 5: Documentation Updates

- [ ] Update `SCRIPTS.md` with new organization
- [ ] Update `CLAUDE.md` with category system
- [ ] Document `list-scripts` usage
- [ ] Document `generate-categories` usage

**Estimated time:** 1 hour

### Phase 6: Cleanup & Final Commit

- [ ] Delete `dropbox-backup copy.sh`
- [ ] Rename files without extensions
- [ ] Final validation
- [ ] Create pull request

**Estimated time:** 30 minutes

---

## Testing Plan

### Test 1: Generate categories.yml

```bash
# Should work now (29 scripts have headers)
cd ~/zshrc
generate-categories

# Validate output
cat bin/categories.yml

# Should show 11 Ruby + 7 Python + 13 Shell = 31 scripts missing
generate-categories --missing
```

### Test 2: Category Distribution

Expected distribution after all headers added:

| Category | Count | Scripts |
|----------|-------|---------|
| git | 9 | Git automation tools |
| media | 12 | Image/video processing |
| system | 11 | System utilities |
| dev | 13 | Development tools |
| files | 7 | File operations |
| setup | 7 | Setup/configuration |
| backup | 5 | Backup scripts |
| data | 2 | Data processing |
| communication | 2 | Email, messaging |

**Total:** ~68 scripts (excluding Rust source files)

### Test 3: Enhanced list-scripts

```bash
# List all scripts grouped by category
list-scripts

# List only git scripts
list-scripts git
list-scripts --category git

# Flat list
list-scripts --flat

# Search by tag
list-scripts --tag ml
list-scripts --tag interactive
```

### Test 4: ZSH Completion

```bash
# Tab completion should show categories
list-scripts <TAB>
# Shows: git, media, system, setup, backup, dev, files, data, communication

# Complete category names
list-scripts g<TAB>
# Shows: git

# Complete options
list-scripts --<TAB>
# Shows: --category, --flat, --help
```

---

## Success Metrics

✅ **All scripts have metadata headers** (71/71 = 100%)
✅ **categories.yml auto-generated** (from all headers)
✅ **Enhanced list-scripts** (category filtering)
✅ **ZSH completion** (tab completion works)
✅ **Documentation updated** (SCRIPTS.md, CLAUDE.md)
✅ **Cleanup complete** (no duplicates, consistent extensions)
✅ **Tests pass** (all 4 test scenarios)

---

## Progress Tracking

### Overall Progress

| Category | Total | Complete | Remaining | % Complete |
|----------|-------|----------|-----------|------------|
| Documentation | 4 | 3 | 1 | 75% |
| Ruby Scripts | 40 | 29 | 11 | 73% |
| Python Scripts | 7 | 0 | 7 | 0% |
| Shell Scripts | 13 | 0 | 13 | 0% |
| Tooling | 4 | 1 | 3 | 25% |
| **TOTAL** | **68** | **33** | **35** | **49%** |

### Session Progress

**Session Start:** 0 scripts with headers
**Current:** 29 scripts with headers
**Scripts Tagged:** 29
**Documentation Created:** 1,980+ lines
**Git Commits:** 5 commits
**Time Invested:** ~2 hours

### Velocity

- **Phase 1 (Documentation):** 1 hour → 4 files, 1,980 lines
- **Phase 1 (Ruby Headers):** 1 hour → 29 scripts
- **Average:** ~15 scripts/hour when in flow

**Estimated remaining time:**
- 11 Ruby + 7 Python + 13 Shell = 31 scripts
- At 15 scripts/hour = ~2 hours
- Tooling + docs = ~2.5 hours
- **Total:** ~4.5 hours to complete

---

## Next Session TODO

### Immediate (Do First)

1. ✅ Create `ORGANIZE_PLAN.md` (this file)
2. [ ] Add headers to remaining 11 Ruby scripts (30 min)
3. [ ] Add headers to 7 Python scripts (15 min)
4. [ ] Add headers to 13 Shell scripts (30 min)
5. [ ] Generate categories.yml (5 min)

### High Priority

6. [ ] Create wrapper function (15 min)
7. [ ] Enhance list-scripts (45 min)
8. [ ] Add ZSH completion (30 min)
9. [ ] Test all functionality (30 min)

### Medium Priority

10. [ ] Update SCRIPTS.md (30 min)
11. [ ] Update CLAUDE.md (15 min)
12. [ ] Cleanup duplicates/extensions (15 min)
13. [ ] Final validation (15 min)

### Low Priority

14. [ ] Create pull request
15. [ ] Write migration guide
16. [ ] Update README if needed

---

## Decisions Made

### ✅ Approved Decisions

1. **Metadata-based organization** - No file moves, headers only
2. **Category-first** - Organize by purpose, not language
3. **Auto-generation** - categories.yml generated from headers
4. **Gradual adoption** - Can add headers incrementally
5. **Keep language structure** - bin/ruby-cli/, bin/python-cli/, etc.

### 🤔 Open Questions

1. **Should we add @dependencies field?** - Track external tool requirements
2. **Should scripts without extensions get them?** - Consistency vs. backwards compat
3. **Should we version categories.yml?** - Or regenerate on each use
4. **Should completion be auto-loaded?** - Or manual opt-in

---

## Risk Mitigation

### Low Risk

- **File moves:** None - headers only, no structural changes
- **Breaking changes:** None - wrapper functions unchanged
- **Backwards compatibility:** Full - all existing commands work

### Monitored

- **Ruby gem dependencies:** Using Bundler, isolated environment
- **Git conflicts:** Working on feature branch
- **Performance:** categories.yml generation is fast (< 1s)

---

## References

- **SCRIPT_METADATA.md** - Header format specification
- **RULES.md** - Language-specific patterns
- **PRINCIPLES.md** - Universal engineering principles
- **SCRIPTS.md** - Existing comprehensive documentation
- **generate-categories.rb** - Auto-generation tool

---

**Last Updated:** 2025-11-16
**Next Review:** After Phase 1 completion (all headers added)
**Owner:** Claude Code Session
**Branch:** `claude/organize-zshrc-017tJYfw2RwJsT5xf4gQbbz7`
