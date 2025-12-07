import Foundation

// MARK: - Smith Core

/// SmithCore provides shared data models and utilities for Smith build analysis tools
public struct SmithCore {

    // MARK: - Version Information

    public static let version = "1.0.0"
    public static let buildDate = "2025-11-16"

    // MARK: - Quick Analysis

    /// Perform a quick analysis of a project directory
    public static func quickAnalyze(at path: String) -> BuildAnalysis {
        let projectType = ProjectDetector.detectProjectType(at: path)
        let dependencyGraph = BuildDependencySummary(
            targetCount: 0,
            maxDepth: 0,
            circularDeps: false,
            complexity: .low
        )

        return BuildAnalysis(
            projectType: projectType,
            status: .unknown,
            dependencyGraph: dependencyGraph
        )
    }

    // MARK: - Utility Methods

    /// Get human-readable summary of analysis results
    public static func summarize(_ analysis: BuildAnalysis) -> String {
        return BuildOutputFormatter.formatSummary(
            BuildResult(
                analysis: analysis,
                summary: ""
            )
        )
    }

    /// Format analysis as human-readable text
    public static func formatHumanReadable(_ analysis: BuildAnalysis) -> String {
        return BuildOutputFormatter.formatHumanReadable(analysis)
    }

    /// Format analysis as JSON
    public static func formatJSON(_ analysis: BuildAnalysis) -> Data? {
        return BuildOutputFormatter.formatAnalysis(analysis)
    }

    /// Check if a project is likely to have build issues
    public static func assessBuildRisk(_ analysis: BuildAnalysis) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        // Check dependency complexity
        if analysis.dependencyGraph.targetCount > 50 {
            diagnostics.append(Diagnostic(
                severity: .warning,
                category: .dependency,
                message: "High target count (\(analysis.dependencyGraph.targetCount)) may cause slow builds",
                suggestion: "Consider simplifying dependency structure or building in phases"
            ))
        }

        if analysis.dependencyGraph.circularDeps {
            diagnostics.append(Diagnostic(
                severity: .error,
                category: .dependency,
                message: "Circular dependencies detected",
                suggestion: "Break circular dependencies by restructuring imports"
            ))
        }

        // Check complexity level
        switch analysis.dependencyGraph.complexity {
        case .high, .extreme:
            diagnostics.append(Diagnostic(
                severity: .warning,
                category: .performance,
                message: "Project complexity is \(analysis.dependencyGraph.complexity.rawValue)",
                suggestion: "Use incremental builds and consider dependency optimization"
            ))
        case .low, .medium:
            break
        }

        return diagnostics
    }

    // MARK: - Build System Integration

    /// Detect available build systems and tools
    public static func detectEnvironment() -> [BuildSystem] {
        return BuildSystemDetector.detectAvailableBuildSystems()
    }

    /// Check if a specific build tool is available
    public static func isToolAvailable(_ tool: BuildSystem) -> Bool {
        let available = detectEnvironment()
        return available.contains(tool)
    }

    /// Get recommended approach for the given project type
    public static func getRecommendedApproach(for projectType: ProjectType) -> String {
        switch projectType {
        case .spm:
            return "Use 'smith spm analyze' for package analysis and dependency management"
        case .xcodeWorkspace, .xcodeProject:
            return "Use 'smith xcode analyze' for comprehensive build analysis and optimization"
        case .unknown:
            return "Unable to determine project type, check if it's a valid Swift/iOS project"
        }
    }
}

// MARK: - Public API Extensions

extension BuildAnalysis {
    /// Get a quick assessment of build risk
    public var riskLevel: String {
        if dependencyGraph.complexity == .extreme || dependencyGraph.circularDeps {
            return "High"
        } else if dependencyGraph.complexity == .high {
            return "Medium"
        } else {
            return "Low"
        }
    }

    /// Check if the build is likely to succeed quickly
    public var isLikelyFast: Bool {
        return dependencyGraph.complexity == .low && !dependencyGraph.circularDeps
    }
}

extension BuildDependencySummary {
    /// Get human-readable complexity description
    public var complexityDescription: String {
        switch complexity {
        case .low:
            return "Simple project, should build quickly"
        case .medium:
            return "Moderate complexity, reasonable build times"
        case .high:
            return "Complex project, may have longer build times"
        case .extreme:
            return "Very complex project, likely to have build issues"
        }
    }

    /// Get recommendations based on complexity
    public var recommendations: [String] {
        var recs: [String] = []

        if targetCount > 100 {
            recs.append("Consider breaking into smaller modules")
        }

        if maxDepth > 6 {
            recs.append("Reduce dependency depth")
        }

        if circularDeps {
            recs.append("Eliminate circular dependencies")
        }

        switch complexity {
        case .high, .extreme:
            recs.append("Use incremental builds")
            recs.append("Monitor build cache health")
        case .medium:
            recs.append("Consider build optimization")
        case .low:
            break
        }

        return recs
    }
}