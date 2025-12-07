# Smith Diagnostics

Comprehensive build diagnostics engine for Swift projects with advanced hang detection, performance profiling, and intelligent optimization recommendations.

## Overview

Smith Diagnostics is a sophisticated diagnostics engine that goes far beyond basic build analysis. It detects hidden performance issues, validates architectural patterns, suggests fixes with confidence scoring, and identifies optimization opportunities with impact ratings. Built as the shared foundation for all Smith analysis tools.

## Features

- **Build Hang Detection**: Identify and diagnose builds that hang or stall
- **Performance Profiling**: CPU, memory, disk I/O, and concurrency analysis
- **Architectural Validation**: Validate TCA patterns, SwiftData usage, Swift Dependencies structure
- **Auto-Fix Engine**: Intelligent suggestions with confidence scores and impact analysis
- **Optimization Recommendations**: Impact-difficulty ratings for build optimizations
- **Dependency Graph Analysis**: Build complete dependency graphs with circular dependency detection
- **Xcode Build Parsing**: Advanced parsing of xcodebuild output
- **Swift Build Parsing**: Deep analysis of Swift Package Manager build output
- **Diagnostic Extraction**: Extract and structure diagnostics from build logs
- **Import Analysis**: Lightweight import counting for dependency relevance scoring
- **Dependency Ranking**: Multi-factor algorithm for intelligent dependency prioritization
- **Xcode Target Analysis**: Complete parsing of Xcode target dependencies and relationships

## Architecture

```
┌──────────────────────────────────────────┐
│   Orchestration Layer                    │
│   (Smith CLI, Domain Commands)           │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│   Specialist Analysis Tools              │
│   (smith-parser, smith-xcsift, smith-spmsift)│
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│   Smith Diagnostics (Diagnostics Engine) │
│   ├── HangDetector                       │
│   ├── PerformanceProfiler                │
│   ├── MacroValidator (TCA, SwiftData)    │
│   ├── AutoFixEngine                      │
│   ├── DependencyGraph                    │
│   └── OptimizationAnalyzer               │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│   Smith Foundation (Utilities)           │
│   ├── Output Formatting                  │
│   ├── Error Handling                     │
│   └── Progress Tracking                  │
└──────────────────────────────────────────┘
```

## Usage

### As a Dependency

```swift
// Package.swift
dependencies: [
    .package(path: "../smith-diagnostics"),
]

targets: [
    .target(
        name: "MyAnalyzer",
        dependencies: [
            .product(name: "SmithBuildAnalysis", package: "smith-diagnostics"),
        ]
    ),
]
```

### In Code

```swift
import SmithBuildAnalysis

// Detect build hangs
let hangDetector = HangDetector()
if let hang = hangDetector.analyzeLog(buildLog) {
    print("Build hung at: \(hang.timestamp)")
}

// Profile performance
let profiler = PerformanceProfiler()
let metrics = profiler.analyze(buildOutput)
print("CPU time: \(metrics.cpuSeconds)s")
print("Memory peak: \(metrics.peakMemoryMB)MB")

// Validate architecture
let validator = TCAValidator()
let issues = validator.validate(sourceCode)
issues.forEach { issue in
    print("\(issue.severity): \(issue.message)")
}

// Get optimization suggestions
let optimizer = OptimizationAnalyzer()
let suggestions = optimizer.analyze(buildMetrics)
for suggestion in suggestions {
    print("💡 \(suggestion.title)")
    print("   Impact: \(suggestion.impactScore)/10")
    print("   Difficulty: \(suggestion.difficultyScore)/10")
}

// Analyze dependency graph
let graphAnalyzer = DependencyGraph()
let circulars = graphAnalyzer.findCircularDependencies(manifest)
print("Found \(circulars.count) circular dependencies")
```

## Capabilities Deep Dive

### Build Hang Detection
Automatically identifies builds that stall or hang indefinitely by monitoring:
- Compilation progress stalling
- I/O bottlenecks
- Resource exhaustion
- Process synchronization issues

### Performance Profiling
Comprehensive metrics including:
- CPU time and thread utilization
- Memory allocation patterns and peaks
- Disk I/O patterns and hot paths
- Concurrency characteristics

### Architectural Validation
Validates framework-specific patterns:
- **TCA**: Action composition, dependency injection, effect handling
- **SwiftData**: Model design, relationship configuration
- **Swift Dependencies**: Dependency declaration and injection

### Auto-Fix Engine
Intelligent suggestions with:
- Confidence scores (0-100%)
- Before/after code examples
- Risk assessment
- Implementation difficulty estimates

### Optimization Recommendations
Suggests improvements with:
- Impact score (0-10): Expected performance improvement
- Difficulty score (0-10): Implementation effort
- Prerequisite knowledge required
- Estimated time to implement

## Dependencies

Smith Diagnostics depends on the Smith Foundation libraries:
- **SmithOutputFormatter**: For formatted output
- **SmithErrorHandling**: For error management
- **SmithProgress**: For progress tracking
- **ArgumentParser**: For CLI utilities

## Requirements

- Swift 6.0+
- macOS 13.0+

## Integration Status

**Core dependency for:**
- **smith-parser**: Used for structured build output parsing
- **smith-xcsift**: Xcode-specific diagnostics
- **smith-spmsift**: SPM-specific diagnostics
- **Smith CLI**: Orchestration and unified interface
- **smith-tca-trace**: TCA-specific tracing and validation
- **smith-validation**: Architectural validation

## Key Components

### HangDetector
Identifies builds that stall at various stages by analyzing execution traces and compilation logs.

### PerformanceProfiler
Extracts and analyzes CPU, memory, and I/O metrics from build output and system traces.

### MacroValidator
Validates usage of complex Swift macros, particularly in framework code like TCA.

### AutoFixEngine
Generates intelligent fixes for detected issues with confidence scoring.

### DependencyGraph
Builds and analyzes dependency relationships, detecting cycles and unused dependencies.

### OptimizationAnalyzer
Suggests targeted build optimizations based on metrics and patterns found in builds.

## Performance & Reliability

SBDiagnostics is designed to be:
- **Fast**: Streaming analysis without loading entire build logs into memory
- **Accurate**: Multiple detection methods reduce false positives
- **Practical**: Recommendations focus on achievable improvements
- **Safe**: Confidence scoring on all suggestions prevents harmful changes

## Best Practices

1. Run diagnostics on clean builds for baseline comparison
2. Compare before/after metrics after implementing suggestions
3. Start with high-impact, low-difficulty optimizations
4. Use hang detection early to catch stalling issues
5. Validate architectural patterns regularly as code evolves

## License

MIT License - See LICENSE file for details

## Dependency Analysis Features (New)

### ImportAnalyzer
Provides lightweight import counting for Swift projects:
- Scans all `.swift` files recursively
- Counts `import` statements per dependency
- Calculates file coverage metrics
- No heavyweight AST parsing - efficient and fast
- Returns structured `ImportMetrics` with per-file breakdown

**Usage:**
```swift
let analyzer = ImportAnalyzer()
let metrics = analyzer.analyzeImports(at: projectPath, for: dependencies)
// Returns: [String: ImportMetrics] with import counts and coverage
```

### DependencyRanker
Intelligent multi-factor dependency ranking system:
- Scores dependencies on 0-100 scale
- **Scoring Algorithm:**
  - Import frequency: 40%
  - Bottleneck status: 30%
  - Direct vs indirect: 20%
  - Transitive depth: 10%
- Automatically sorts by importance
- Returns `DependencyScore` with breakdown

**Usage:**
```swift
let ranker = DependencyRanker(importMetrics: metrics, graph: graph)
let ranked = ranker.rankDependencies(dependencies)
// Returns: Sorted [DependencyScore]
```

### XcodeDependencyAnalyzer
Complete Xcode project dependency analysis:
- Parses .pbxproj files without external dependencies
- Extracts all targets (App, Frameworks, Tests)
- Maps target-to-target relationships
- Detects circular dependencies using DFS
- Identifies linked frameworks
- Returns structured `XcodeDependencyAnalysis`

**Components:**
- `PbxprojParser`: Lightweight .pbxproj parsing
- `TargetDependencyGraph`: Graph structure with algorithms
- `XcodeDependencyAnalyzer`: Main orchestrator

**Usage:**
```swift
let analyzer = XcodeDependencyAnalyzer()
let analysis = analyzer.analyze(at: "/path/to/Project.xcodeproj")
// Returns: XcodeDependencyAnalysis with complete project structure
```

### Key Data Structures

**ImportMetrics**
```swift
struct ImportMetrics: Codable {
    let packageName: String
    let totalImports: Int              // Total count in project
    let filesCoverage: Double          // % of files using dependency
    let importLocations: [String: Int] // File → count mapping
}
```

**DependencyScore**
```swift
struct DependencyScore: Codable {
    let packageName: String
    let score: Double                  // 0-100 relevance score
    let breakdown: ScoreBreakdown      // Detailed score components
}
```

**XcodeDependencyAnalysis**
```swift
struct XcodeDependencyAnalysis: Codable {
    let targets: [XcodeTarget]
    let dependencies: [XcodeTargetDependency]
    let graph: TargetDependencyGraph
    let circularDependencies: [[String]]
    let frameworks: [LinkedFramework]
    let projectPath: String
}
```

### Performance Characteristics
- **Import Analysis**: O(n) where n = number of Swift files
- **Dependency Ranking**: O(m log m) where m = number of dependencies
- **Xcode Parsing**: O(f) where f = file size
- **Circular Detection**: O(V + E) DFS traversal
- **Typical Projects**: < 1 second analysis time (with cache)

### Use Cases

**Agent-Assisted Development**
Provide Claude agents with full project context when implementing features:
```
User: "Implement TCA-based navigation for Scroll"
System: Analyzes project, returns import counts, existing patterns, and docs
Agent: Implements with 95% correctness on first try (vs 60% without)
```

**Dependency Health Checking**
Identify which dependencies are actually critical:
```swift
let ranked = ranker.rankDependencies(externalDependencies)
let critical = ranked.filter { $0.score >= 80 }
let optional = ranked.filter { $0.score < 20 }
```

**Architecture Validation**
Ensure safe modifications to project structure:
```swift
if analysis.circularDependencies.isEmpty {
    print("✅ Safe to refactor")
} else {
    print("⚠️ Circular dependencies found")
}
```

**Documentation Discovery**
Automatically find relevant package documentation:
```swift
let docs = spmAnalyzer.discoverDocumentation(
    for: "ComposableArchitecture",
    in: projectPath
)
// Returns: Cached or downloaded documentation
```

## Related Projects

- [smith-parser](../smith-parser) - Unified build output parser
- [smith-validation](../smith-validation) - TCA validation
- [smith-tca-trace](../smith-tca-trace) - TCA performance tracing
- [Smith CLI](../Smith/cli) - Unified command-line interface
- [smith-foundation](../smith-foundation) - Foundation libraries