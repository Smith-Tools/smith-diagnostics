# Smith Core

Smith Core provides shared data models and utilities for Smith build analysis tools. It serves as the foundation library for the smith-tools ecosystem, offering consistent data structures, output formatting, and project detection capabilities.

## Features

- **Project Type Detection**: Automatically detect SPM packages, Xcode projects, and workspaces
- **Build System Detection**: Identify available build tools (Xcode, Swift, spmsift, sbsift, xcsift)
- **Shared Data Models**: Common types for build analysis, diagnostics, and results
- **Output Formatting**: Consistent JSON and human-readable output across all Smith tools
- **Risk Assessment**: Built-in analysis for potential build issues

## Installation

Add smith-core as a dependency in your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/smith-tools/smith-core.git", from: "1.0.0")
]
```

## Quick Start

```swift
import SmithCore

// Detect project type
let projectType = ProjectDetector.detectProjectType(at: ".")
print("Project type: \(projectType)")

// Quick analysis
let analysis = SmithCore.quickAnalyze(at: ".")
print("Complexity: \(analysis.dependencyGraph.complexity)")

// Format output
let output = SmithCore.formatHumanReadable(analysis)
print(output)
```

## Core Components

### Project Detection

```swift
// Find different project types
let workspaces = ProjectDetector.findWorkspaceFiles(in: ".")
let projects = ProjectDetector.findProjectFiles(in: ".")
let packages = ProjectDetector.findPackageFiles(in: ".")

// Detect available build systems
let systems = BuildSystemDetector.detectAvailableBuildSystems()
```

### Data Models

- **ProjectType**: SPM, Xcode workspace, Xcode project, unknown
- **BuildAnalysis**: Complete analysis with phases, metrics, and diagnostics
- **DependencyGraph**: Target count, depth, circular dependencies, complexity
- **Diagnostic**: Severity levels, categories, and actionable suggestions
- **BuildResult**: Comprehensive build result with warnings and errors

### Output Formatting

```swift
// Human-readable format
let readable = SmithOutputFormatter.formatHumanReadable(analysis)

// JSON format
let jsonData = SmithOutputFormatter.formatAnalysis(analysis)

// Summary format
let summary = SmithOutputFormatter.formatSummary(buildResult)
```

## Usage Examples

### Basic Project Analysis

```swift
let analysis = SmithCore.quickAnalyze(at: projectPath)

switch analysis.projectType {
case .spm:
    print("Swift Package Manager project")
case .xcodeWorkspace(let workspace):
    print("Xcode workspace: \(workspace)")
case .xcodeProject(let project):
    print("Xcode project: \(project)")
case .unknown:
    print("Unknown project type")
}

// Assess build risks
let risks = SmithCore.assessBuildRisk(analysis)
for risk in risks {
    print("[\(risk.severity)] \(risk.message)")
}
```

### Build System Detection

```swift
let availableSystems = BuildSystemDetector.detectAvailableBuildSystems()
for system in availableSystems {
    print("Available: \(system.name)")
}

// Check if specific tool is available
if SmithCore.isToolAvailable(.xcode) {
    print("Xcode is available")
}
```

## Smith Tools Ecosystem

Smith Core is part of the smith-tools family:

- **smith-core**: Shared data models and utilities (this library)
- **smith-spmsift**: Swift Package Manager analysis and optimization
- **smith-sbsift**: Swift build system analysis and debugging
- **smith-xcsift**: Xcode project build analysis and optimization
- **smith-cli**: Unified command-line interface for all Smith tools

## Data Model Overview

### ProjectType
```swift
public enum ProjectType: Codable, Equatable {
    case spm
    case xcodeWorkspace(workspace: String)
    case xcodeProject(project: String)
    case unknown
}
```

### BuildAnalysis
```swift
public struct BuildAnalysis: Codable {
    public let projectType: ProjectType
    public let status: BuildStatus
    public let phases: [BuildPhase]
    public let dependencyGraph: DependencyGraph
    public let metrics: BuildMetrics
    public let diagnostics: [Diagnostic]
}
```

### Diagnostic
```swift
public struct Diagnostic: Codable {
    public let severity: Severity
    public let category: Category
    public let message: String
    public let location: String?
    public let suggestion: String?
}
```

## Risk Assessment

Smith Core provides built-in risk assessment for build issues:

```swift
let analysis = SmithCore.quickAnalyze(at: ".")
let risks = SmithCore.assessBuildRisk(analysis)

// Risks include:
// - High target count warnings
// - Circular dependency detection
// - Complexity level analysis
```

## Testing

Run the test suite:

```bash
swift test
```

Smith Core includes comprehensive tests for:
- Project type detection
- Data model serialization
- Output formatting
- Risk assessment algorithms

## Contributing

Smith Core follows the Smith Framework patterns and conventions:

1. **Context Efficiency**: Minimal, focused output for AI agents
2. **Progressive Analysis**: Fast validation, deep analysis when needed
3. **Actionable Diagnostics**: Clear suggestions for build issues
4. **Consistent Data Models**: Shared types across all Smith tools

## License

MIT License - see LICENSE file for details.

## Version History

- **1.0.0**: Initial release with core data models, project detection, and output formatting