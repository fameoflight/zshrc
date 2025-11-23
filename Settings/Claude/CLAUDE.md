# SOFTWARE ENGINEERING RULES

Language-agnostic principles for maintainable, readable code

## THE 10 COMMANDMENTS

1. Maximum 5 parameters - EVER (functions, constructors, methods)
2. Options object for 3+ parameters (explicit, extensible, self-documenting)
3. One responsibility per unit (function/class/file does ONE thing)
4. DRY - Don't Repeat Yourself (single source of truth)
5. Simple over clever (boring code is good code)
6. Encapsulation (hide complexity, expose clean interfaces)
7. Helper methods remove friction (small, focused, reusable)
8. Base classes for shared behavior (when inheritance makes sense)
9. Delete code > Add code (less code = fewer bugs)
10. Stop after 2 failed attempts (ask for direction)

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

ENCAPSULATION

- Hide implementation (private/protected internals)
- Clean public API (minimal surface area)
- No leaky abstractions (don't expose internals)
- Maximum 5 exports per file/module

## WORKFLOW RULES

BEFORE WRITING CODE

1. Check if it exists (search first, write second)
2. Find 2-3 similar examples (match patterns)
3. Ask if unclear (don't assume)
4. Can you delete instead? (less is more)

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

## LANGUAGE-SPECIFIC APPLICATIONS

OBJECT-ORIENTED LANGUAGES (Java, C#, TypeScript)

- Interfaces for contracts
- Constructor: (options: OptionsType)
- Base classes for shared behavior
- Private/protected for encapsulation

FUNCTIONAL LANGUAGES (Haskell, F#, Scala)

- Small, pure functions
- Options as records/tuples
- Composition over inheritance
- Module boundaries for encapsulation

DYNAMIC LANGUAGES (Python, Ruby, JavaScript)

- Type hints/documentation
- Options dict/hash pattern
- Duck typing with clear contracts
- Convention-based privacy

SYSTEMS LANGUAGES (Rust, Go, C)

- Struct for options
- Error handling explicit
- Resource cleanup guaranteed
- Clear memory ownership

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

Before committing, verify:

[ ] Parameters: No function has > 5 parameters
[ ] Size: Functions < 50 lines, files < 200 lines
[ ] Responsibility: Each unit does ONE thing
[ ] DRY: No copy-paste duplication
[ ] Encapsulation: Implementation hidden
[ ] Tests: New code has tests
[ ] Errors: All errors handled explicitly
[ ] Patterns: Follows project conventions
[ ] Documentation: Intent is clear
[ ] Simplicity: No clever tricks

## ANTI-PATTERNS TO AVOID

❌ FORBIDDEN

- God objects (doing everything)
- Deep nesting (> 3 levels)
- Magic numbers (unexplained values)
- Copy-paste code (violates DRY)
- Leaky abstractions (exposing internals)
- Clever one-liners (unreadable)
- "While I'm here" changes (scope creep)
- Assumptions (verify everything)
- Silent failures (always handle errors)
- 6+ parameters (no exceptions)

✅ REQUIRED

- Options objects (for extensibility)
- Helper methods (for clarity)
- Error messages (descriptive)
- Tests (for new functionality)
- Consistent patterns (match codebase)
- Clear boundaries (encapsulation)
- Simple solutions (boring is good)
- Incremental changes (small commits)
- Explicit intent (self-documenting)
- 5-parameter limit (everywhere)

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

## THE PRIME DIRECTIVE

"Can I delete code instead of adding it?"

Before writing any code:

1. Does this already exist?
2. Is this actually needed?
3. What's the simplest solution?
4. Will this make sense in 6 months?

## THE FINAL WORD

Write code for humans, not computers. The computer doesn't care if your
code is clever - but the person maintaining it at 3 AM definitely will.

Remember:

- Boring code is debuggable code
- Simple code is maintainable code
- Less code is better code
- Consistent code is predictable code

When in doubt: Do less. Do the minimum that works. Keep it simple.

**The Golden Rules:**

- "Can I delete code instead of adding it?"
- "If I need more than 5 parameters, I'm doing too much"
- "Helper methods should remove friction, not add complexity"
- "One responsibility per unit - no exceptions"
- "Every script needs metadata headers - no exceptions"

---

"Any fool can write code that a computer can understand. Good programmers
write code that humans can understand." - Martin Fowler

"The best code is no code at all." - Jeff Atwood
