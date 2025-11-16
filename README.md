# Smith Core 🔧

**Core framework and shared data models for Smith Tools ecosystem**

[![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-mOS%20%7C%20iOS%20%7C%20visionOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Smith Core provides the foundational framework that powers all Smith Tools with consistent data models, utilities, and build analysis capabilities.

## 🎯 **Overview**

Smith Core is the **dependency backbone** of the Smith Tools ecosystem, providing:

- **📊 Shared Data Models** - BuildAnalysis, Diagnostic, BuildMetrics, DependencyGraph
- **🔧 Analysis Utilities** - Error parsing, timing extraction, project detection
- **📝 Output Formatters** - JSON, compact, and TOON format generators
- **🏗️ Framework Integration** - Smith Framework patterns and validation

## 📦 **Features**

### **Core Data Models**
```swift
// Build analysis structure
public struct BuildAnalysis {
    public let projectType: ProjectType
    public let status: BuildStatus
    public let phases: [BuildPhase]
    public let dependencyGraph: DependencyGraph
    public let metrics: BuildMetrics
    public let diagnostics: [Diagnostic]
}

// Diagnostic information
public struct Diagnostic {
    public let severity: DiagnosticSeverity
    public let category: DiagnosticCategory
    public let message: String
    public let location: String?
}
```

### **Analysis Capabilities**
- **Project Detection** - Automatic identification of SPM vs Xcode projects
- **Error Parsing** - Structured extraction from compiler output
- **Performance Metrics** - Timing, file counts, memory usage
- **Dependency Analysis** - Graph complexity and bottleneck detection

### **Output Formats**
- **JSON** - Complete structured analysis
- **Compact** - Token-efficient summary format
- **TOON** - Pipe-delimited format for CI/CD integration

## 🚀 **Usage**

Smith Core is typically used as a dependency in other Smith Tools:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/Smith-Tools/smith-core", from: "1.0.0")
]
```

```swift
import SmithCore

// Create build analysis
let analysis = BuildAnalysis(
    projectType: .xcodeWorkspace(workspace: "."),
    status: .success,
    phases: phases,
    dependencyGraph: dependencyGraph,
    metrics: metrics,
    diagnostics: diagnostics
)

// Format for output
let formatter = JSONFormatter()
let output = formatter.format(analysis)
```

## 🔧 **Installation**

### **Swift Package Manager**
```swift
dependencies: [
    .package(url: "https://github.com/Smith-Tools/smith-core", from: "1.0.0")
]
```

### **Manual**
```bash
git clone https://github.com/Smith-Tools/smith-core
cd smith-core
swift build
```

## 📚 **API Reference**

### **ProjectType**
```swift
public enum ProjectType {
    case spm
    case xcodeProject(project: String)
    case xcodeWorkspace(workspace: String)
}
```

### **DiagnosticSeverity**
```swift
public enum DiagnosticSeverity: String, Codable {
    case error, warning, info, note
}
```

### **DiagnosticCategory**
```swift
public enum DiagnosticCategory: String, Codable {
    case compilation, linking, dependency, configuration, performance
}
```

### **BuildMetrics**
```swift
public struct BuildMetrics {
    public let totalDuration: TimeInterval?
    public let compilationDuration: TimeInterval?
    public let linkingDuration: TimeInterval?
    public let dependencyResolutionDuration: TimeInterval?
    public let memoryUsage: UInt64?
    public let fileCount: Int?
}
```

## 🏗️ **Architecture**

```
SmithCore/
├── Sources/
│   └── SmithCore/
│       ├── Models/           # Core data structures
│       ├── Analysis/        # Build analysis logic
│       ├── Formatting/      # Output formatters
│       └── Utilities/       # Helper functions
└── Tests/
    └── SmithCoreTests/
        ├── ModelTests/
        ├── AnalysisTests/
        └── FormattingTests/
```

## 🧪 **Testing**

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ModelTests

# Test with coverage
swift test --enable-code-coverage
```

## 📋 **Dependencies**

- **Swift 6.0+** - Modern language features
- **Foundation** - Core system frameworks
- **ArgumentParser** - CLI interfaces (dependency)

## 🤝 **Contributing**

Smith Core follows the [Smith Framework](https://github.com/Smith-Tools/smith-framework) development discipline.

**Development Setup:**
```bash
git clone https://github.com/Smith-Tools/smith-core
cd smith-core
swift build
swift test
```

**Code Style:**
- Follow Smith Framework patterns
- Use modern Swift 6.0 features
- Comprehensive test coverage
- Documentation for all public APIs

## 📄 **License**

Smith Core is available under the [MIT License](LICENSE).

## 🔗 **Related Projects**

- **[Smith CLI](https://github.com/Smith-Tools/smith-cli)** - Unified interface
- **[Smith SPSift](https://github.com/Smith-Tools/smith-spmsift)** - SPM analysis
- **[Smith SBSift](https://github.com/Smith-Tools/smith-sbsift)** - Swift build analysis
- **[XCSift](https://github.com/Smith-Tools/xcsift)** - Xcode build analysis
- **[Smith Framework](https://github.com/Smith-Tools/smith-framework)** - Development patterns

---

**Core foundation for context-efficient Swift build analysis**