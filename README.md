# smith-core - Universal Swift Patterns Library

> **Production-ready Swift patterns for modern development—independent of architecture, applicable across any Swift project.**

Foundation library providing universal patterns, utilities, and best practices for Swift development. Part of the Smith Tools ecosystem but usable independently.

## 🎯 What is smith-core?

smith-core provides patterns and guidance applicable to **any Swift project**, not just TCA-based apps:

- **Dependency Injection** - @Dependency patterns and best practices
- **Swift Concurrency** - async/await, @MainActor, Task patterns
- **Modern Testing** - Swift Testing framework patterns
- **Access Control** - Public API boundaries and transitive dependencies
- **Type-Safe Error Handling** - Custom error types and recovery patterns
- **Shared State** - @Shared, @SharedReader patterns
- **Utilities** - Common helper functions and types

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/Smith-Tools/smith-core.git

# Copy patterns directory to your project (or reference locally)
cp -r smith-core/Patterns ~/YourProject/

# Or integrate as a documentation reference
ln -s $(pwd)/smith-core ~/Developer/smith-core
```

### Usage

**In your Swift code:**

Reference the patterns from smith-core documentation:

```swift
// Example: Dependency Injection pattern (from smith-core)
@DependencyClient
struct NetworkClient {
    var fetch: (String) -> AsyncThrowingStream<Data, Error> = { _ in
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: CancellationError())
        }
    }
}

// Example: Type-safe error handling
enum AppError: Error {
    case network(URLError)
    case decoding(DecodingError)
    case invalid(String)
}
```

## 📚 Pattern Documentation

| Pattern | Purpose | When to Use |
|---------|---------|------------|
| **Dependency Injection** | Inject dependencies for testability | All new dependencies |
| **Concurrency** | Safe async/await patterns | Network calls, long-running tasks |
| **Error Handling** | Type-safe error types | Any error condition |
| **Access Control** | Public API boundaries | When exposing library code |
| **Shared State** | @Shared state management | Cross-module state |
| **Testing** | Modern test patterns | All test code |

## 🔄 Integration with Other Smith Tools

smith-core works independently but integrates with the full Smith Tools ecosystem:

```
smith-core       ← Universal patterns (used by everything)
    ↓
smith-skill      ← TCA-specific guidance (uses smith-core patterns)
sosumi-skill     ← Apple documentation
smith-sbsift     ← Build analysis
smith-spmsift    ← SPM analysis
```

## 🛠️ Development

### Building

```bash
# No special build needed—smith-core is documentation + example code
# Just clone and reference the patterns

git clone https://github.com/Smith-Tools/smith-core.git
cd smith-core

# View pattern documentation
ls *.md
```

### Project Structure

```
smith-core/
├── README.md                 ← This file
├── DEPENDENCY-INJECTION.md   ← @Dependency patterns
├── CONCURRENCY.md            ← async/await patterns
├── TESTING.md                ← Swift Testing patterns
├── ERROR-HANDLING.md         ← Error type patterns
├── ACCESS-CONTROL.md         ← Public API patterns
├── SHARED-STATE.md           ← @Shared patterns
├── Examples/                 ← Code examples
└── Case Studies/             ← Real-world examples
```

## 📋 Requirements

- **Swift 5.10+** (for async/await, structured concurrency)
- **Xcode 15.0+** (for Swift Testing framework)
- **macOS 12.0+, iOS 16.0+, visionOS 1.0+**

## 🔗 Related Components

- **[smith-skill](../smith-skill/)** - TCA-specific patterns and validators
- **[sosumi-skill](../sosumi-skill/)** - Apple documentation + WWDC
- **[smith-sbsift](../smith-sbsift/)** - Swift build analysis
- **[smith-spmsift](../smith-spmsift/)** - Swift Package Manager analysis

## 🤝 Contributing

Contributions welcome! Please:

1. Read existing pattern documentation first
2. Test patterns on real projects before contributing
3. Provide case studies with new patterns
4. Follow the pattern template (see CONTRIBUTING.md)
5. Reference Apple's official documentation
6. Include before/after examples

## 📄 License

MIT - See [LICENSE](LICENSE) for details

---

**smith-core - Universal Swift patterns for production applications**

*Last updated: November 17, 2025*