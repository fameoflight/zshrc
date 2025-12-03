# SOFTWARE ENGINEERING RULES

Language-agnostic principles for maintainable, readable code

## CORE RULES

THE 5-PARAMETER LAW

NEVER exceed 5 parameters anywhere. If you need more, you're doing too much.

0-2 parameters = Excellent
3-4 parameters = Consider options object
5 parameters = Maximum allowed
6+ parameters = FORBIDDEN - Refactor immediately

Solutions when you hit the limit:

- Use options object/hash/dict
- Group related parameters
- Extract to class
- Split the function

OPTIONS OBJECT PATTERN

For 3+ parameters or extensibility, use an options object:

// Instead of: function(a, b, c, d, e)
// Use: function(required, options)

Examples:

- TypeScript: interface Options { ... }
- Python: opts: Dict[str, Any] = {}
- Ruby: opts = {} with fetch/[]
- Shell: Parse --flags

SMALL, FOCUSED FUNCTIONS

- < 50 lines per function
- One responsibility (no "and" in the name)
- Extract helpers for repeated logic (2+ times)
- Clear names that explain intent

DRY (DON'T REPEAT YOURSELF)

- Extract common logic to helpers
- Single source of truth for all knowledge
- Convenience getters for repeated access patterns
- Base classes for shared functionality

SIMPLE OVER CLEVER

- Boring code wins (optimize for reading, not writing)
- Explicit over implicit (clear data flow)
- No magic (if you need to explain it, it's too complex)
- Standard patterns over personal preference
- Convention over configuration: Establish sensible defaults to reduce parameters, props, and simplify APIs by making reasonable choices automatic rather than requiring explicit configuration

FUNCTIONALITY WITHOUT COMPLEXITY

We want maximum functionality with minimum complexity:

- **Functionality over complexity**: Choose the simplest solution that delivers required functionality
- **Smart conventions**: Apply conventions intelligently, not rigidly - allow flexibility when it serves the user
- **Enforced smartly**: Rules guide us, don't imprison us - break conventions when justified
- **Complex result, simple parts**: Build complex systems from simple, well-abstracted components
- **Progressive disclosure**: Simple use cases should be simple; complexity should be opt-in

ABSTRACTION THAT HIDES COMPLEXITY

Build abstractions that make complex things easy:

- **Powerful simplicity**: Abstractions should make complex operations feel simple
- **Leaky-free interfaces**: Don't expose implementation complexity to users
- **Opinionated defaults**: Make smart choices automatically, allow overrides when needed
- **Composable building blocks**: Small, focused abstractions that combine elegantly
- **Complexity containment**: Hide complexity behind clean, intuitive interfaces

ENCAPSULATION

- Hide implementation (private/protected internals)
- Clean public API (minimal surface area)
- No leaky abstractions (don't expose internals)
- Maximum 5 exports per file/module

## WORKFLOW RULES

BEFORE WRITING CODE

1. Can you delete instead? (less is more)
2. Does this already exist? (search first, write second)
3. Is this actually needed? (minimum solution)
4. Find 2-3 similar examples (match patterns)
5. Ask if unclear (don't assume)

WHEN STUCK (2-ATTEMPT RULE)

After 2 failed attempts:

1. State what you tried
2. Present 2-3 alternatives
3. Ask which direction to take
4. DO NOT keep trying without input

WHEN REFACTORING

Only refactor when explicitly requested, then check for:

- Functions with 6+ parameters
- Files > 200 lines with mixed concerns
- Duplicate code across 3+ places
- Deep nesting (> 3 levels)
- Functions doing multiple things

## TECHNICAL REQUIREMENTS

EVERY CODE UNIT MUST

- Compile/parse successfully (no broken commits)
- Pass all tests (write tests for new code)
- Follow project patterns (consistency > personal preference)
- Have clear intent (self-documenting)
- Handle errors explicitly (no silent failures)

INTERFACE DESIGN

- Required parameters first (1-2 max)
- Options object second (for optional/config)
- Callbacks last (if needed)
- Return single type (avoid union types when possible)

COMPONENT/CLASS DESIGN

Constructor/Init:
├─ Maximum 1-2 parameters
├─ Options object if needed
└─ Set defaults explicitly

Public API:
├─ Maximum 5 public methods/functions
├─ Clear, verb-based names
└─ Consistent return types

Private/Internal:
├─ Hide all implementation
├─ Prefix with \_ or use language features
└─ Can be complex if encapsulated

## LANGUAGE-SPECIFIC NOTES

**Options Pattern:**

- TypeScript: `interface Options { ... }`
- Python: `opts: Dict[str, Any] = {}`
- Ruby: `opts = {}` with fetch/[]
- Shell: Parse --flags
- Rust/Go: Struct for options

**Privacy:**

- OOP: private/protected keywords
- Functional: Module boundaries
- Dynamic: Convention-based (\_prefix)
- Systems: Explicit ownership

## DECISION FRAMEWORK

SHOULD I EXTRACT A FUNCTION?

Is logic repeated (2+ times)?
├─ YES → Extract helper
└─ NO → Is it complex (>5 lines)?
├─ YES → Extract for clarity
└─ NO → Keep inline

HOW TO STRUCTURE PARAMETERS?

How many parameters needed?
├─ 0-2 → Direct parameters
├─ 3-4 → Consider options object
├─ 5 → Restructure if possible
└─ 6+ → STOP - Refactor required

SHOULD I ADD THIS FEATURE?

Is it explicitly requested?
├─ NO → Don't add it
└─ YES → Does it already exist?
├─ YES → Reuse it
└─ NO → Is it the minimum solution?
├─ NO → Simplify
└─ YES → Implement

## QUALITY CHECKLIST

Before committing:
[ ] ≤5 parameters, <50 lines/function, <200 lines/file
[ ] One responsibility, no duplication (DRY)
[ ] Implementation hidden, tests added, errors handled
[ ] Follows project patterns, intent is clear
[ ] Simple solutions, smart abstractions, intelligent conventions

## ANTI-PATTERNS

❌ **Never:**

- 6+ parameters (no exceptions)
- God objects (doing everything)
- Deep nesting (> 3 levels)
- Magic numbers (unexplained values)
- "While I'm here" changes (scope creep)
- Silent failures (always handle errors)
- Rigid conventions without judgment

## SPECIAL CONSIDERATIONS

DESTRUCTIVE OPERATIONS

- Must support dry-run (show what would happen)
- Require confirmation (for critical operations)
- Log all actions (audit trail)
- Provide rollback (when possible)

CONFIGURATION

- Environment variables over hardcoding
- Defaults clearly defined
- Validation at boundaries
- Type-safe when possible

TESTING

Core Philosophy:

- Test behavior, not implementation
- Bug-first testing: reproduce bug in test, then fix (coverage grows organically)
- Real over mocked: prefer real dependencies, only mock system boundaries
- DRY matters MORE in tests: extract helpers after 2 uses (tests have more repetition)
- Progressive enhancement: each test should make next one easier to write

Test Organization:

- Separate test directories (test/, spec/) mirroring source structure
- Arrange-Act-Assert pattern (explicit sections)
- Self-documenting names: test_user_cannot_delete_others_posts (what/why not how)
- One logical assertion per test (when practical)

Test Data:

- Factories over fixtures (dynamic, flexible)
- High variability with sane defaults: build_user(name: "Alice") with other fields defaulted
- Factory helpers: 0-2 required params, options object for overrides
- Read-only fixtures okay for reference data (never mutate)
- Build minimum data needed for each test

HTTP & External Dependencies:

- HTTP capture/replay (VCR, Polly, nock) instead of mocking
- Record real responses once, replay in tests
- Mock sparingly and only at system boundaries (APIs, filesystem, clock)

Database Strategy:

- Truncation between tests
- Automatic cleanup (no manual teardown)
- Tests must not pollute state

Performance:

- Unit tests: < 100ms target
- Integration tests: depends on scope
- Fast enough to run frequently
- Parallelize when possible

Assertion Style:

- Use expect syntax: expect(result).to eq(expected)
- Clear failure messages when needed
- Deterministic (no flaky tests)

Anti-Patterns:

- Testing private methods/implementation details
- Mocking everything (defeats integration testing)
- Copy-paste test data (use factories)
- Shared mutable state
- Clever test helpers (simple and obvious only)
- Brittle tests that break on unrelated changes

## UNIMPLEMENTED FEATURES

When not implementing something due to complexity:

**For Code Comments:**

```typescript
// TODO: Implement feature X - requires Y consideration
```

**For Interface Implementation:**

```typescript
function complexFeature(params: any): any {
  throw new Error(
    "Not Implemented: Feature requires additional architecture planning"
  );
}
```

**Guidelines:**

- Use `// TODO:` for temporary placeholders with brief rationale
- Implement interfaces and throw descriptive errors for public APIs
- Always include the reason why it's not implemented
- Consider if a simpler partial implementation could work instead

## GOLDEN RULES

- Can I delete code instead of adding it?
- If I need more than 5 parameters, I'm doing too much
- Helper methods should remove friction, not add complexity
- One responsibility per unit - no exceptions
- Every script needs metadata headers - no exceptions
- Functionality without complexity - choose the simplest solution that works
- Abstractions should hide complexity, not expose it

When in doubt: Do less. Do the minimum that works. Keep it simple.

<system>
Do not worry about context, just focus on getting the job done as per the instructions.
</system>
