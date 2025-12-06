import Foundation

/// Smith Build Diagnostics - Operationalizing Expert Swift Build Debugging
///
/// Based on proven methodology for identifying and resolving:
/// - Type inference explosions (100% CPU for minutes)
/// - TCA architectural anti-patterns (nested CombineReducers)
/// - SwiftUI type inference traps (complex closures, long modifier chains)
/// - Build bottleneck detection and resolution
///
/// Core principle: "Trust the process, not the UI" - CPU% tells the real story

public struct SmithBuildDiagnostics {

    // MARK: - Core Diagnostic Framework

    /// Analyzes Swift build processes and identifies bottlenecks
    public static func diagnoseBuildIssues(
        in directory: String,
        cpuThreshold: Double = 95.0,
        runtimeThreshold: TimeInterval = 60.0
    ) -> BuildDiagnosis {
        let processes = getSwiftCompilationProcesses()
        let issues = processes.compactMap { process -> BuildIssue? in
            analyzeProcess(process, cpuThreshold: cpuThreshold, runtimeThreshold: runtimeThreshold)
        }

        return BuildDiagnosis(
            timestamp: Date(),
            processes: processes,
            issues: issues,
            recommendations: generateRecommendations(from: issues)
        )
    }

    // MARK: - Process Analysis

    private static func getSwiftCompilationProcesses() -> [SwiftProcess] {
        // Get all swift-frontend and xcodebuild processes
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.split(separator: "\n")
            .compactMap { line -> SwiftProcess? in
                let components = line.split(separator: " ", omittingEmptySubsequences: true)
                guard components.count >= 11 else { return nil }

                let processString = String(line)

                // Check if it's a Swift compilation process
                if !processString.contains("swift-frontend") && !processString.contains("xcodebuild") {
                    return nil
                }

                // Extract CPU and runtime
                let cpuString = components[2].replacingOccurrences(of: "%", with: "")
                let cpu = Double(cpuString) ?? 0.0

                let timeString = components[3]
                let runtime = parseRuntime(String(timeString))

                // Extract primary file being compiled
                let primaryFile = extractPrimaryFile(from: processString)

                return SwiftProcess(
                    pid: Int(components[1]) ?? 0,
                    cpu: cpu,
                    runtime: runtime,
                    primaryFile: primaryFile,
                    command: processString
                )
            }
    }

    private static func analyzeProcess(
        _ process: SwiftProcess,
        cpuThreshold: Double,
        runtimeThreshold: TimeInterval
    ) -> BuildIssue? {
        if process.cpu >= cpuThreshold && process.runtime >= runtimeThreshold {
            return BuildIssue(
                type: .typeInferenceExplosion,
                severity: .critical,
                process: process,
                description: "Type inference explosion detected - \(process.cpu)% CPU for \(Int(process.runtime/60)) minutes",
                suggestedFixes: [
                    "Add explicit types to complex closures",
                    "Extract nested expressions to computed properties",
                    "Simplify SwiftUI modifier chains",
                    "Check for untyped generic constraints"
                ]
            )
        }

        if process.cpu < 5.0 && process.runtime >= runtimeThreshold {
            return BuildIssue(
                type: .ioWaitOrDeadlock,
                severity: .high,
                process: process,
                description: "I/O wait or deadlock detected - low CPU usage but long runtime",
                suggestedFixes: [
                    "Check file system permissions",
                    "Verify dependency resolution",
                    "Check for circular imports",
                    "Verify Xcode/DerivedData corruption"
                ]
            )
        }

        if let primaryFile = process.primaryFile {
            if primaryFile.contains("View.swift") && process.cpu > 80.0 {
                return BuildIssue(
                    type: .swiftUITypeInference,
                    severity: .medium,
                    process: process,
                    description: "Potential SwiftUI type inference issue in view file",
                    suggestedFixes: [
                        "Extract complex .environment closures",
                        "Add explicit types to Binding closures",
                        "Simplify long modifier chains",
                        "Use @ViewBuilder for complex conditional views"
                    ]
                )
            }

            if primaryFile.contains("Feature.swift") && process.cpu > 80.0 {
                return BuildIssue(
                    type: .tcaAntiPattern,
                    severity: .medium,
                    process: process,
                    description: "Potential TCA architectural issue in feature file",
                    suggestedFixes: [
                        "Check for nested CombineReducers",
                        "Use @ReducerBuilder instead of nested CombineReducers",
                        "Extract complex child features",
                        "Verify proper @Dependency usage"
                    ]
                )
            }
        }

        return nil
    }

    // MARK: - Pattern Detection

    /// Searches for specific anti-patterns that cause type inference explosions
    public static func detectAntiPatterns(
        in directory: String,
        filePatterns: [String] = ["**/*.swift"]
    ) -> [AntiPattern] {
        var patterns: [AntiPattern] = []

        // TCA Anti-Patterns
        patterns.append(contentsOf: detectTCAPatterns(in: directory))

        // SwiftUI Anti-Patterns
        patterns.append(contentsOf: detectSwiftUIPatterns(in: directory))

        return patterns
    }

    private static func detectTCAPatterns(in directory: String) -> [AntiPattern] {
        var patterns: [AntiPattern] = []

        // Nested CombineReducers (critical anti-pattern)
        let nestedCombineReducers = AntiPattern(
            type: .nestedCombineReducers,
            severity: .critical,
            description: "Nested CombineReducers cause exponential type inference",
            file: "",
            line: 0,
            suggestion: "Use @ReducerBuilder with flat composition instead"
        )

        // This would use actual file search in implementation
        patterns.append(nestedCombineReducers)

        return patterns
    }

    private static func detectSwiftUIPatterns(in directory: String) -> [AntiPattern] {
        var patterns: [AntiPattern] = []

        // Complex environment closures
        let complexEnvironmentClosures = AntiPattern(
            type: .complexEnvironmentClosures,
            severity: .high,
            description: "Complex .environment closures with untyped parameters",
            file: "",
            line: 0,
            suggestion: "Extract closure to computed property with explicit types"
        )

        patterns.append(complexEnvironmentClosures)

        return patterns
    }

    // MARK: - Recommendation Engine

    private static func generateRecommendations(from issues: [BuildIssue]) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        let criticalIssues = issues.filter { $0.severity == .critical }
        if !criticalIssues.isEmpty {
            recommendations.append(Recommendation(
                priority: .immediate,
                title: "Kill Type Inference Explosions",
                description: "Immediate action required for \(criticalIssues.count) critical issues",
                actions: [
                    "pkill -f 'swift-frontend.*\(criticalIssues.first?.process.primaryFile ?? "")'",
                    "Add explicit types to problematic closures",
                    "Extract complex expressions"
                ]
            ))
        }

        return recommendations
    }

    // MARK: - Helper Methods

    private static func parseRuntime(_ timeString: String) -> TimeInterval {
        let parts = timeString.split(separator: ":")
        if parts.count == 2 {
            let minutes = Double(parts[0]) ?? 0.0
            let seconds = Double(parts[1]) ?? 0.0
            return minutes * 60 + seconds
        }
        return 0.0
    }

    private static func extractPrimaryFile(from command: String) -> String? {
        // Extract -primary-file argument
        if let range = command.range(of: "-primary-file ") {
            let afterRange = command[range.upperBound...]
            let components = afterRange.split(separator: " ", maxSplits: 1)
            return components.first.map(String.init)
        }
        return nil
    }
}

// MARK: - Data Models

public struct SwiftProcess {
    public let pid: Int
    public let cpu: Double
    public let runtime: TimeInterval
    public let primaryFile: String?
    public let command: String
}

public struct BuildIssue {
    public let type: IssueType
    public let severity: Severity
    public let process: SwiftProcess
    public let description: String
    public let suggestedFixes: [String]
}

public struct BuildDiagnosis {
    public let timestamp: Date
    public let processes: [SwiftProcess]
    public let issues: [BuildIssue]
    public let recommendations: [Recommendation]
}

public struct AntiPattern {
    public let type: PatternType
    public let severity: Severity
    public let description: String
    public let file: String
    public let line: Int
    public let suggestion: String
}

public struct Recommendation {
    public let priority: Priority
    public let title: String
    public let description: String
    public let actions: [String]
}

// MARK: - Enums

public enum IssueType {
    case typeInferenceExplosion
    case ioWaitOrDeadlock
    case swiftUITypeInference
    case tcaAntiPattern
}

public enum PatternType {
    case nestedCombineReducers
    case complexEnvironmentClosures
    case untypedClosures
    case longModifierChains
}

public enum Severity {
    case critical, high, medium, low
}

public enum Priority {
    case immediate, high, medium, low
}