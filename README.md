# SBDiagnostics

Comprehensive build diagnostics engine for Swift projects with advanced hang detection, performance profiling, and intelligent optimization recommendations.

## Overview

SBDiagnostics is a sophisticated diagnostics engine that goes far beyond basic build analysis. It detects hidden performance issues, validates architectural patterns, suggests fixes with confidence scoring, and identifies optimization opportunities with impact ratings. Built as the shared foundation for all Smith analysis tools.

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

## Architecture

```
┌──────────────────────────────────────────┐
│   Orchestration Layer                    │
│   (Smith CLI, Domain Commands)           │
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│   Specialist Analysis Tools              │
│   (sbparser, smith-xcsift, smith-spmsift)│
└────────────────┬─────────────────────────┘
                 │
┌────────────────▼─────────────────────────┐
│   SBDiagnostics (Diagnostics Engine)     │
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
    .package(path: "../sbdiagnostics"),
]

targets: [
    .target(
        name: "MyAnalyzer",
        dependencies: [
            .product(name: "SBDiagnostics", package: "sbdiagnostics"),
        ]
    ),
]
```

### In Code

```swift
import SBDiagnostics

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

SBDiagnostics depends on the Smith Foundation libraries:
- **SmithOutputFormatter**: For formatted output
- **SmithErrorHandling**: For error management
- **SmithProgress**: For progress tracking
- **ArgumentParser**: For CLI utilities

## Requirements

- Swift 6.0+
- macOS 13.0+

## Integration Status

**Core dependency for:**
- **sbparser**: Used for structured build output parsing
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

## Related Projects

- [sbparser](../sbparser) - Unified build output parser
- [smith-xcsift](../smith-xcsift) - Xcode-specific analysis tool
- [smith-spmsift](../smith-spmsift) - SPM-specific analysis tool
- [smith-validation](../smith-validation) - TCA validation
- [smith-tca-trace](../smith-tca-trace) - TCA performance tracing
- [Smith CLI](../Smith/cli) - Unified command-line interface
- [smith-foundation](../smith-foundation) - Foundation libraries