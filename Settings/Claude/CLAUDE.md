# Development Guidelines

## Prime Directive: Stop Before You Start

Before writing ANY code:
1. **Does this already exist?** Search first, write second
2. **Is this actually needed?** Solve the problem, not potential future problems
3. **Can I delete instead of add?** Less code = fewer bugs

## Core Rules

- **Incremental only** - Small changes that compile and pass tests
- **Learn from existing code** - Study patterns before implementing
- **Boring over clever** - If you need to explain it, it's too complex
- **One responsibility** - Functions/classes/files do ONE thing
- **Maximum 5 parameters** - Ever. Function args, React props, service constructors - if you need more, you're doing too much
- **Small files hide complexity** - Encapsulate logic behind clear interfaces, don't expose internals

## Hard Constraints

### Absolutely Forbidden
- ❌ Refactoring working code unless that's the explicit task
- ❌ "Improving" code that wasn't part of the request
- ❌ Adding features not explicitly requested
- ❌ Premature abstractions (copy-paste twice is fine)
- ❌ "While I'm here" changes to unrelated code

### Required Before Coding
- ✅ Verify it doesn't already exist in the codebase
- ✅ Find 2-3 similar implementations to match patterns
- ✅ Ask if requirements are unclear

### When Refactoring IS Explicitly Requested

**Only refactor when user explicitly asks** - then use these triggers:
- More than 5 parameters anywhere
- Files exceeding 200 lines with mixed concerns
- Functions with multiple "and" in their name
- Deep nesting (>3 levels)
- Duplicate code patterns across 3+ files

## Encapsulation Rules

**Small files with clear boundaries** - Hide complexity, don't expose it:

### The 5-Parameter Law
- **Maximum 5 parameters** for any function/component/constructor
- If you need more, group related params into a config object
- Config objects must have meaningful names, not generic "options" or "config"

**Examples:**
```typescript
// ❌ BAD - Too many parameters
function createUser(name: string, email: string, age: number,
                   address: string, phone: string, role: string) {}

// ✅ GOOD - Config object with clear purpose
interface UserProfile {
  name: string;
  email: string;
  age: number;
}

interface UserContact {
  address: string;
  phone: string;
}

function createUser(profile: UserProfile, contact: UserContact, role: string) {}
```

### File Size & Responsibility
- **One logical boundary per file** - User management, not "utilities"
- **Hide implementation details** - Export only what consumers need
- **Internal complexity is fine** - 200-line file is OK if it has one clear purpose
- **External simplicity required** - Consumers should use ≤5 things from your file

**Examples:**
```typescript
// ❌ BAD - Exposing too much
export const validateEmail = ...
export const validatePhone = ...
export const validateAddress = ...
export const formatEmail = ...
export const formatPhone = ...
export const parseEmail = ...

// ✅ GOOD - Single interface
export class ContactValidator {
  validate(contact: Contact): ValidationResult {}
  format(contact: Contact): FormattedContact {}
}
```

### When to Extract
Extract when you hit these limits:
- Function has >5 parameters
- File exports >5 public things
- Component/service has >5 props/dependencies
- You're scrolling to understand one function

### When NOT to Extract
Don't extract just because:
- File feels "long" but does one thing
- You want to "organize better"
- You think it "might be reused someday"
- You're following a pattern book

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

**Complex work only:** Document 3-5 stages in `IMPLEMENTATION_PLAN.md`:

```markdown
## Stage N: [Name]
**Goal**: [Specific deliverable]
**Tests**: [Specific test cases]
**Status**: [Not Started|In Progress|Complete]
```

**Implementation Flow:**

1. **Understand** - Study existing patterns (mandatory)
2. **Test** - Write failing test (red)
3. **Implement** - Minimal code to pass (green)
4. **Stop** - You're done. No refactoring unless tests require it
5. **Commit** - Clear message linking to plan

### 3. When Stuck (2-Attempt Rule)

**STOP after 2 failed attempts** and ask the user:

1. State what you tried and what failed
2. Present 2-3 alternative approaches
3. Ask which direction to take
4. **Do NOT** keep trying different things without user input

## Technical Standards

### Architecture

- **Composition over inheritance** - Dependency injection
- **Interfaces over singletons** - Enable testing
- **Explicit over implicit** - Clear data flow
- **Maximum 5 parameters** - Anywhere, ever, no exceptions
- **Maximum 5 exports** - Per file, if you need more you have poor boundaries

### Code Quality Requirements

**Every commit must**:

- Compile successfully
- Pass all existing tests
- Include tests for new functionality
- Follow project formatting/linting
- Have ≤5 parameters per function/component/constructor
- Have ≤5 public exports per file

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

**NEVER:**
- Disable tests instead of fixing them
- Make assumptions - verify with existing code
- Add "TODO" comments - either do it or don't
- Write code then ask "is this okay?" - ask BEFORE writing

**ALWAYS:**
- Verify builds pass: `yarn tsc` (not `yarn build`)
- Stop after 2 failed attempts and ask
- Update TODO.md before ending session
- State what you're about to do BEFORE doing it

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

## Response Format

### Before making changes
State clearly:
```
I will change [file:line_number] to [specific action].
This adds/removes X lines.
```

### After making changes
```
Changed [file:line_number]. Build passes.
```

No explanations unless asked. No "I also improved..." - that means you broke the rules.

---

_Do less. When in doubt, do the minimum that works._