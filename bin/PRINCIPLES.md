# Universal Software Engineering Principles

**Language-agnostic principles for writing maintainable, readable code**

Extracted from TypeScript/React patterns and Ruby/Python/Shell script patterns.

---

## The 10 Commandments

1. **Maximum 5 parameters - EVER**
2. **Prefer options objects over positional parameters**
3. **Small, focused functions (one responsibility)**
4. **DRY - Don't Repeat Yourself**
5. **Simple over clever - boring code is good code**
6. **Encapsulation - hide complexity behind clean interfaces**
7. **Inheritance is good when done right**
8. **Type safety and self-documenting code**
9. **Consistency over cleverness**
10. **Delete code > Add code**

---

## Principle 1: The 5-Parameter Limit

**Rule:** No function, method, constructor, or script should ever have more than 5 parameters.

### Why This Matters

```
0-2 parameters = Excellent (easy to understand)
3-4 parameters = Good (consider options object)
5 parameters = Maximum allowed (restructure if possible)
6+ parameters = FORBIDDEN (you're doing too much)
```

### Solutions When You Hit the Limit

**Option A: Options Object/Hash**

```typescript
// TypeScript
interface CreateUserOptions {
  email: string;
  name: string;
  age?: number;
  role?: string;
}

function createUser(profile: CreateUserOptions): User {
  // Single parameter, infinite extensibility
}

createUser({
  email: 'user@example.com',
  name: 'John',
  role: 'admin'
});
```

```ruby
# Ruby
def create_user(opts = {})
  email = opts.fetch(:email)
  name = opts.fetch(:name)
  age = opts[:age] || 18
  role = opts[:role] || 'user'
end

create_user(
  email: 'user@example.com',
  name: 'John',
  role: 'admin'
)
```

```python
# Python
def create_user(opts: Dict[str, Any]) -> User:
    email = opts['email']
    name = opts['name']
    age = opts.get('age', 18)
    role = opts.get('role', 'user')

create_user({
    'email': 'user@example.com',
    'name': 'John',
    'role': 'admin'
})
```

**Option B: Extract to Class**

```typescript
// TypeScript - Builder pattern
class UserBuilder {
  private data: Partial<User> = {};

  email(value: string): this {
    this.data.email = value;
    return this;
  }

  name(value: string): this {
    this.data.name = value;
    return this;
  }

  build(): User {
    return new User(this.data);
  }
}

const user = new UserBuilder()
  .email('user@example.com')
  .name('John')
  .build();
```

**Option C: Group Related Parameters**

```typescript
// Before: Too many parameters
function renderChart(
  data, xLabel, yLabel, title, width, height, showLegend, showGrid
) {}

// After: Grouped into logical objects
interface ChartData { data: any[]; }
interface ChartLabels { x: string; y: string; title: string; }
interface ChartOptions { width: number; height: number; showLegend: boolean; showGrid: boolean; }

function renderChart(
  data: ChartData,
  labels: ChartLabels,
  options: ChartOptions
) {}
```

---

## Principle 2: Options Object Pattern

**Rule:** For 3+ parameters or any parameters that might grow, use an options object.

### Benefits

1. **Self-documenting:** `{ email: 'x' }` is clearer than `'x'` as 3rd parameter
2. **Extensible:** Add new options without breaking existing code
3. **Optional parameters:** Clear defaults, no `undefined` passing
4. **Type-safe:** Interface/type documents all possibilities
5. **Order-independent:** No need to remember parameter positions

### Pattern Across Languages

```typescript
// TypeScript
interface ServiceOptions {
  timeout?: number;
  retries?: number;
  cache?: boolean;
}

class Service {
  constructor(private opts: ServiceOptions = {}) {
    this.timeout = opts.timeout ?? 5000;
    this.retries = opts.retries ?? 3;
    this.cache = opts.cache ?? true;
  }
}
```

```ruby
# Ruby
class Service
  def initialize(opts = {})
    @timeout = opts.fetch(:timeout, 5000)
    @retries = opts.fetch(:retries, 3)
    @cache = opts.fetch(:cache, true)
  end
end
```

```python
# Python
class Service:
    def __init__(self, opts: Optional[Dict] = None):
        opts = opts or {}
        self.timeout = opts.get('timeout', 5000)
        self.retries = opts.get('retries', 3)
        self.cache = opts.get('cache', True)
```

---

## Principle 3: Small, Focused Functions

**Rule:** Each function should do ONE thing and do it well. Aim for < 50 lines.

### Helper Function Pattern

**Purpose:** Remove friction, hide complexity, improve readability

```typescript
// TypeScript - Helper removes repetition
function scaleTemperatureForProvider(temp: number, provider: string): number {
  if (provider === 'anthropic') {
    return Math.min(temp / 2, 1);
  }
  return temp;
}

// Usage - clear what's happening
const config = {
  temperature: scaleTemperatureForProvider(this.temperature, this.provider)
};
```

```ruby
# Ruby - Helper encapsulates complexity
def get_staged_files
  System.safe_execute("git diff --cached --name-only")
    .split("\n")
    .reject(&:empty?)
end

# Usage - simple and readable
files = get_staged_files
```

```python
# Python - Helper makes code self-documenting
def calculate_optimal_tile_size(image_size: Tuple[int, int], device: str) -> int:
    """Calculate optimal tile size based on image dimensions and device"""
    width, height = image_size
    total_pixels = width * height

    if device == 'cuda':
        return min(1024, max(256, total_pixels // 1000))
    return min(350, max(75, total_pixels // 3000))

# Usage - clear intent
tile_size = calculate_optimal_tile_size((1920, 1080), 'cuda')
```

### When to Extract a Helper

- **Repeated logic** (appears 2+ times)
- **Complex calculation** (ternaries, nested conditions)
- **Magic numbers/strings** (hide implementation details)
- **Readability** (name makes code self-documenting)

---

## Principle 4: DRY (Don't Repeat Yourself)

**Rule:** Every piece of knowledge should have a single, authoritative representation.

### Violations

```typescript
// ❌ BAD - Same logic repeated
function getUserById(id: string): User {
  const user = await db.users.findOne({ where: { id } });
  if (!user) throw new Error('User not found');
  return user;
}

function getUserByEmail(email: string): User {
  const user = await db.users.findOne({ where: { email } });
  if (!user) throw new Error('User not found');  // ❌ Duplicate!
  return user;
}
```

### Fix: Extract Common Logic

```typescript
// ✅ GOOD - Single source of truth
async function findUserOrThrow(where: any): Promise<User> {
  const user = await db.users.findOne({ where });
  if (!user) throw new Error('User not found');
  return user;
}

function getUserById(id: string): User {
  return findUserOrThrow({ id });
}

function getUserByEmail(email: string): User {
  return findUserOrThrow({ email });
}
```

### Convenience Getters (Advanced DRY)

```typescript
// TypeScript - Getter eliminates repetition
class BaseService {
  protected getRepositories() {
    return {
      userRepo: this.dataSource.getRepository(User),
      chatRepo: this.dataSource.getRepository(Chat),
      messageRepo: this.dataSource.getRepository(Message),
    };
  }
}

// Usage - no repetitive calls
const { userRepo, chatRepo } = this.getRepositories();
```

```ruby
# Ruby - Method eliminates boilerplate
class BaseService
  def repositories
    {
      user_repo: User.repository,
      chat_repo: Chat.repository,
      message_repo: Message.repository
    }
  end
end

# Usage
repos = repositories
user = repos[:user_repo].find(id)
```

---

## Principle 5: Simple Over Clever

**Rule:** Code is read 10x more than it's written. Optimize for readability.

### Examples

```typescript
// ❌ CLEVER - Hard to understand
const active = users.filter(u => u.status === 'active' && u.age > 18 && !u.deleted);
const sorted = active.sort((a, b) => b.score - a.score);
const top = sorted.slice(0, 10).map(u => ({ id: u.id, name: u.name }));
```

```typescript
// ✅ SIMPLE - Self-explanatory
const activeAdultUsers = users.filter(user => {
  return user.status === 'active' && user.age > 18 && !user.deleted;
});

const sortedByScore = activeAdultUsers.sort((a, b) => b.score - a.score);

const top10Users = sortedByScore.slice(0, 10).map(user => ({
  id: user.id,
  name: user.name
}));
```

### Boring Code is Good Code

```python
# ❌ CLEVER - One-liner with walrus operator
if (result := expensive_call()) and result.valid and (data := result.data):
    process(data)
```

```python
# ✅ SIMPLE - Explicit steps
result = expensive_call()
if not result:
    return

if not result.valid:
    return

data = result.data
process(data)
```

---

## Principle 6: Encapsulation

**Rule:** Hide complexity behind clean interfaces. Implementation details should be private.

### Good Encapsulation

```typescript
// ✅ GOOD - Clean public API, hidden internals
class ChatService {
  private chat: Chat | null = null;
  private cache: Map<string, Message> = new Map();

  // Public API
  async getChat(): Promise<Chat> {
    if (this.chat) return this.chat;
    this.chat = await this.loadChat();
    return this.chat;
  }

  async getMessage(id: string): Promise<Message | null> {
    if (this.cache.has(id)) return this.cache.get(id)!;
    const msg = await this.loadMessage(id);
    this.cache.set(id, msg);
    return msg;
  }

  // Private implementation
  private async loadChat(): Promise<Chat> { /* ... */ }
  private async loadMessage(id: string): Promise<Message> { /* ... */ }
}
```

### Bad Encapsulation (Leaky Abstractions)

```typescript
// ❌ BAD - Exposing internals
class ChatService {
  // ❌ Exposing repository
  getRepository() {
    return this.chatRepository;
  }

  // ❌ Exposing cache
  getCache() {
    return this.cache;
  }
}

// Users can mess with internals:
service.getRepository().delete(allChats); // Oops!
service.getCache().clear(); // Breaks assumptions!
```

---

## Principle 7: Inheritance When Done Right

**Rule:** Use base classes for shared functionality, not just code reuse.

### Good Inheritance

```typescript
// ✅ GOOD - Base class provides common behavior
abstract class BaseService {
  protected dataSource: DataSource;

  constructor() {
    this.dataSource = DataSourceProvider.get();
  }

  // Common functionality
  protected getRepositories() {
    return {
      userRepo: this.dataSource.getRepository(User),
      chatRepo: this.dataSource.getRepository(Chat),
    };
  }

  // Abstract methods for subclasses
  abstract validate(): boolean;
}

class UserService extends BaseService {
  // Inherits getRepositories()
  // Must implement validate()
  validate(): boolean {
    // User-specific validation
  }
}
```

```ruby
# ✅ GOOD - Base class provides common interface
class ScriptBase
  def initialize
    @options = default_options
    parse_arguments
  end

  # Common methods
  def log_banner(title)
    Logger.log_section("#{script_emoji} #{title}")
  end

  # Abstract methods
  def run
    raise NotImplementedError
  end

  def script_title
    self.class.name
  end
end

class MyScript < ScriptBase
  def run
    log_banner(script_title)  # Uses base class method
    # Custom logic
  end
end
```

### When to Use Inheritance

✅ **Good reasons:**
- Shared behavior across related classes
- Common interface (abstract methods)
- Lifecycle hooks (initialize, cleanup)
- Template method pattern

❌ **Bad reasons:**
- Just to reuse code (use composition instead)
- No clear "is-a" relationship
- Deep inheritance trees (> 3 levels)

---

## Principle 8: Type Safety & Self-Documenting Code

**Rule:** Code should explain itself. Types and names matter.

### Good Names

```typescript
// ❌ BAD - Unclear names
function process(data: any): any {
  const tmp = data.filter(x => x.status === 1);
  return tmp.map(x => x.value);
}
```

```typescript
// ✅ GOOD - Self-documenting
function getActiveUserEmails(users: User[]): string[] {
  const activeUsers = users.filter(user => user.status === 'active');
  return activeUsers.map(user => user.email);
}
```

### Type Safety

```typescript
// TypeScript - Types make code self-documenting
interface UserProfile {
  email: string;
  name: string;
  age: number;
}

function createUser(profile: UserProfile): User {
  // Type system enforces contract
}
```

```python
# Python - Type hints improve clarity
def create_user(profile: Dict[str, Any]) -> User:
    # Type hints document expected structure
    pass
```

```ruby
# Ruby - Comments for type documentation
# @param opts [Hash] Options hash
# @option opts [String] :email User email
# @option opts [String] :name User name
# @return [User] Created user object
def create_user(opts = {})
end
```

---

## Principle 9: Consistency Over Cleverness

**Rule:** Follow established patterns in the codebase, even if you know a "better" way.

### Why Consistency Matters

**Consistent code:**
- Easier to navigate
- Faster to understand
- Less mental overhead
- Team members can predict structure

**Clever, inconsistent code:**
- Requires deep understanding
- Breaks expectations
- Slows down development
- Hard to maintain

### Examples

```typescript
// If codebase uses this pattern:
class ServiceA {
  constructor(private opts: Options) {}
}

class ServiceB {
  constructor(private opts: Options) {}
}

// ✅ DO THIS (consistent)
class ServiceC {
  constructor(private opts: Options) {}
}

// ❌ DON'T DO THIS (inconsistent, even if "better")
class ServiceC {
  private opts: Options;

  constructor(opts: Options) {
    this.opts = this.validateOptions(opts);
  }
}
```

### Consistency Checklist

- [ ] Constructor patterns match
- [ ] Error handling matches
- [ ] Logging format matches
- [ ] File organization matches
- [ ] Naming conventions match
- [ ] Comment style matches

---

## Principle 10: Delete Code > Add Code

**Rule:** The best code is no code. Always ask: "Can I delete instead of add?"

### Before Adding Code

Ask yourself:
1. **Does this already exist?** (Check for duplicates)
2. **Can I use an existing function?** (Reuse instead of rewrite)
3. **Is this really needed?** (YAGNI - You Aren't Gonna Need It)
4. **Can I simplify instead?** (Remove complexity, don't add)

### Examples

```typescript
// ❌ BAD - Adding new function when one exists
function getUserNames(users: User[]): string[] {
  return users.map(u => u.name);
}

function getUserEmails(users: User[]): string[] {
  return users.map(u => u.email);
}

function getUserIds(users: User[]): string[] {
  return users.map(u => u.id);
}
```

```typescript
// ✅ GOOD - Generic function instead of 3 functions
function pluckUserField<K extends keyof User>(
  users: User[],
  field: K
): User[K][] {
  return users.map(user => user[field]);
}

// Usage
const names = pluckUserField(users, 'name');
const emails = pluckUserField(users, 'email');
const ids = pluckUserField(users, 'id');
```

### Deletion Opportunities

- **Dead code** - Remove unused functions/variables
- **Duplicate code** - Consolidate into helpers
- **Over-engineered code** - Simplify abstractions
- **Commented code** - Delete it (use git history)
- **Feature flags for removed features** - Clean up

---

## Quick Decision Trees

### Should I Extract a Function?

```
Is logic repeated (2+ times)?
├─ YES → Extract to helper function
└─ NO
    Is logic complex (> 5 lines, nested conditions)?
    ├─ YES → Extract for readability
    └─ NO → Keep inline (for now)
```

### Should I Use a Class?

```
Does it need state/caching?
├─ YES → Instance class
│   └─ Constructor: (opts: OptsType)
└─ NO → Static methods or module functions
```

### Should I Use Inheritance?

```
Is there shared behavior (not just code)?
├─ YES
│   Is relationship clear "is-a"?
│   ├─ YES → Use inheritance
│   └─ NO → Use composition
└─ NO → Use composition
```

### How Many Parameters?

```
0-2 → Perfect
3-4 → Consider options object
5 → Maximum! Try to reduce
6+ → STOP! Refactor required
```

---

## Language-Specific Applications

### TypeScript/React

- Interfaces for component props (`IComponentProps`)
- Fragment composition over prop drilling
- Memoization for list items
- Options objects for 3+ props
- Base classes for services

### Ruby Scripts

- ScriptBase inheritance pattern
- Options hash with fetch/[]
- Helper methods in base classes
- Frozen string literal
- Metadata headers

### Python Scripts

- Type hints everywhere
- Options dict pattern
- Base classes for common functionality
- Dataclasses for structured data
- if __name__ == '__main__' guard

### Shell Scripts

- set -euo pipefail
- Source common functions
- Options via case statements
- Functions over long scripts
- Dry run support

---

## The Golden Rules (Summary)

1. **Maximum 5 parameters** - Anywhere, ever, no exceptions
2. **Options objects** - For 3+ parameters or extensibility
3. **Small functions** - One responsibility, < 50 lines
4. **DRY** - Single source of truth for everything
5. **Simple > Clever** - Optimize for reading, not writing
6. **Encapsulation** - Hide complexity, expose clean APIs
7. **Inheritance** - Use for shared behavior, not just code reuse
8. **Type safety** - Self-documenting code with types and names
9. **Consistency** - Follow project patterns over personal preference
10. **Delete > Add** - Best code is no code

---

## Before You Commit

Ask yourself:
- [ ] Does this follow the 5-parameter rule?
- [ ] Did I use options objects where appropriate?
- [ ] Are functions small and focused?
- [ ] Did I eliminate duplication?
- [ ] Is the code simple and readable?
- [ ] Are implementation details hidden?
- [ ] Am I following existing patterns?
- [ ] Could I delete code instead of adding it?
- [ ] Will this make sense to others in 6 months?

---

## Remember

> "Debugging is twice as hard as writing the code in the first place. Therefore, if you write the code as cleverly as possible, you are, by definition, not smart enough to debug it." - Brian Kernighan

> "Any fool can write code that a computer can understand. Good programmers write code that humans can understand." - Martin Fowler

> "The best code is no code at all." - Jeff Atwood

Now go write simple, boring, maintainable code! 🚀
