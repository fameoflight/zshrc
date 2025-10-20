# Development Guidelines

## Core Beliefs

- Incremental progress over big bangs - Small changes that compile and pass tests
- Learning from existing code - Study and plan before implementing
- Pragmatic over dogmatic - Adapt to project reality
- Clear intent over clever code - Be boring and obvious

## Simplicity Means

- Single responsibility per function/class/file
- Avoid premature abstractions
- No clever tricks - choose the boring solution
- If you need to explain it, it's too complex

## Workflow

### 1. Session Management with TODO.md

**ALWAYS start by checking/creating `TODO.md`** - enables faster session resumption.

```markdown
# TODO

## Current Focus

- [ ] [Stage/task currently working on]

## Immediate Next Steps

- [ ] [Next 1-3 specific actions]
- [ ] [Include test cases to write]

## Blocked/Investigating

- [ ] [Issues that need research/decision]

## Completed This Session

- [x] [What was accomplished]

## Notes

- [Key insights, patterns discovered, or decisions made]
```

Update TODO.md before ending each session - future you will thank you.

### 2. Planning & Implementation

**Break complex work into 3-5 stages** documented in `IMPLEMENTATION_PLAN.md`:

```markdown
## Stage N: [Name]

**Goal**: [Specific deliverable]  
**Tests**: [Specific test cases]  
**Status**: [Not Started|In Progress|Complete]
```

**Implementation Flow**:

1. **Understand** - Study existing patterns in codebase
2. **Test** - Write failing test (red)
3. **Implement** - Minimal code to pass (green)
4. **Refactor** - Clean up while tests pass
5. **Commit** - Clear message linking to plan

### 3. When Stuck (3-Attempt Rule)

**STOP after 3 failed attempts** and reassess:

1. **Document failures** - What tried, errors, hypotheses
2. **Research alternatives** - Find 2-3 different approaches
3. **Question fundamentals** - Wrong abstraction? Can split smaller?
4. **Try different angle** - Different library/pattern/simpler approach

## Technical Standards

### Architecture

- **Composition over inheritance** - Dependency injection
- **Interfaces over singletons** - Enable testing
- **Explicit over implicit** - Clear data flow
- **DRY principle** - Small, reusable functions

### Code Quality Requirements

**Every commit must**:

- Compile successfully
- Pass all existing tests
- Include tests for new functionality
- Follow project formatting/linting

### Error Handling

- Fail fast with descriptive messages
- Include debugging context
- Handle at appropriate level
- Never silently swallow exceptions

## Decision Framework

When multiple approaches exist, prioritize:

1. **Testability** - Easy to test?
2. **Readability** - Clear in 6 months?
3. **Consistency** - Matches project patterns?
4. **Simplicity** - Simplest working solution?
5. **Reversibility** - Easy to change later?

## Project Integration

### Learn Before Building

- Find 3 similar features/components
- Identify common patterns and conventions
- Use existing libraries/utilities
- Follow existing test patterns

### Quality Gates

**Definition of Done**:

- [ ] Tests written and passing
- [ ] Follows project conventions
- [ ] No linter/formatter warnings
- [ ] Clear commit messages
- [ ] Implementation matches plan
- [ ] TODO.md updated for next session

**Test Guidelines**:

- Test behavior, not implementation
- One assertion per test when possible
- Clear test names describing scenarios
- Use existing test utilities
- Deterministic tests only

## Critical Rules

**NEVER**:

- Disable tests instead of fixing them
- Make assumptions - verify with existing code

**ALWAYS**:

- Commit working code incrementally
- Update documentation as you progress
- Stop after 3 attempts and reassess
- Update TODO.md before ending session

## Large Codebase Analysis with Gemini CLI

For analyzing large codebases that exceed context limits, use Gemini CLI's massive context window.

### File Inclusion Syntax

Use `@` syntax with paths relative to current directory:

```bash
# Single file analysis
gg -p "@src/main.py Explain this file's purpose and structure"

# Multiple files
gg -p "@package.json @src/index.js Analyze the dependencies used"

# Entire directories
gg -p "@src/ Summarize the architecture of this codebase"

# Current directory and subdirectories
gg -p "@./ Give me an overview of this entire project"
# OR: gg --all_files -p "Analyze the project structure"
```

### Implementation Verification Examples

```bash
# Check if features exist
gg -p "@src/ @lib/ Has dark mode been implemented? Show relevant files"

# Verify authentication
gg -p "@src/ @middleware/ Is JWT authentication implemented?"

# Check patterns across codebase
gg -p "@src/ Are there React hooks handling WebSocket connections?"

# Verify security measures
gg -p "@src/ @api/ Are SQL injection protections implemented?"
```

### When to Use Gemini CLI

- Analyzing entire codebases or large directories
- Comparing multiple large files
- Understanding project-wide patterns or architecture
- Working with files totaling more than 100KB
- Verifying if specific features/patterns are implemented across the codebase

## Xcode Project Management

**When working in Xcode projects, also read:** `Settings/Claude/XCODE.md`

The XCODE.md file provides comprehensive documentation for:

- **File Management**: Adding, viewing, and deleting files with proper resource handling
- **Category System**: Automatic detection and organization of project files
- **Resource Handling**: Special treatment for assets, plists, storyboards, and Core ML models
- **Safety Features**: Dry-run mode, confirmations, and file type-specific protections
- **Modern Xcode Integration**: Works with file system synchronization and automatic project updates

### Available Xcode Commands

```bash
xcode-add-file <file> [category]     # Add file with auto-detection and resource handling
xcode-view-files [category]          # View project structure by category
xcode-delete-file <file>             # Safe deletion with type-specific handling
xcode-list-categories [--detailed]   # Show available organization categories
```

### Key Features for Xcode Development

- **Smart Detection**: Automatically identifies project structure and file categories
- **Resource Expertise**: Handles .xcassets, .plist, .storyboard, .mlmodel files appropriately
- **Safety First**: Protects critical files like Info.plist with extra confirmations
- **Modern Workflow**: Integrates with Xcode's automatic file system synchronization
- **Batch Operations**: Supports processing multiple files with consistent categorization

Refer to `XCODE.md` for complete usage examples, troubleshooting, and best practices.

---

_Code should be readable - not too long, not unnecessarily short. Break rules when it improves clarity._
- use yarn tsc to verify build don't use yarn build