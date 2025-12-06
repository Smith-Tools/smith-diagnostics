import Foundation

// MARK: - Output Formatter

public struct SmithOutputFormatter {

    // MARK: - JSON Formatting

    public static func formatAnalysis(_ analysis: BuildAnalysis, prettyPrint: Bool = true) -> Data? {
        let result = SmithResult(
            tool: "smith-core",
            version: "1.0.0",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            analysis: analysis
        )

        return try? JSONEncoder().encode(result)
    }

    public static func formatResult(_ result: BuildResult, prettyPrint: Bool = true) -> Data? {
        let smithResult = SmithResult(
            tool: "smith-core",
            version: "1.0.0",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            result: result
        )

        let encoder = JSONEncoder()
        if prettyPrint {
            encoder.outputFormatting = .prettyPrinted
        }

        return try? encoder.encode(smithResult)
    }

    public static func formatHangDetection(_ hang: HangDetection) -> Data? {
        let result = SmithHangResult(
            tool: "smith-core",
            version: "1.0.0",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            hang: hang
        )

        return try? JSONEncoder().encode(result)
    }

    // MARK: - Human Readable Formatting

    public static func formatHumanReadable(_ analysis: BuildAnalysis) -> String {
        var output: [String] = []

        // Header
        output.append("🔍 SMITH BUILD ANALYSIS")
        output.append("=====================")

        // Project Info
        output.append("\n📊 Project Information:")
        switch analysis.projectType {
        case .spm:
            output.append("   Type: Swift Package Manager")
        case .xcodeWorkspace(let workspace):
            output.append("   Type: Xcode Workspace")
            output.append("   Workspace: \(workspace)")
        case .xcodeProject(let project):
            output.append("   Type: Xcode Project")
            output.append("   Project: \(project)")
        case .unknown:
            output.append("   Type: Unknown")
        }

        // Build Status
        output.append("\n🎯 Build Status:")
        output.append("   Status: \(analysis.status.rawValue)")

        // Dependency Graph
        output.append("\n🔗 Dependency Graph:")
        output.append("   Targets: \(analysis.dependencyGraph.targetCount)")
        output.append("   Max Depth: \(analysis.dependencyGraph.maxDepth)")
        output.append("   Circular Dependencies: \(analysis.dependencyGraph.circularDeps ? "Yes" : "No")")
        output.append("   Complexity: \(analysis.dependencyGraph.complexity.rawValue)")

        if !analysis.dependencyGraph.bottleneckTargets.isEmpty {
            output.append("   Bottleneck Targets: \(analysis.dependencyGraph.bottleneckTargets.joined(separator: ", "))")
        }

        // Build Phases
        if !analysis.phases.isEmpty {
            output.append("\n⏱️ Build Phases:")
            for phase in analysis.phases {
                let duration = phase.duration.map { String(format: "%.2fs", $0) } ?? "unknown"
                output.append("   \(phase.name): \(phase.status.rawValue) (\(duration))")
            }
        }

        // Metrics
        output.append("\n📈 Build Metrics:")
        if let total = analysis.metrics.totalDuration {
            output.append("   Total Duration: \(String(format: "%.2fs", total))")
        }
        if let compilation = analysis.metrics.compilationDuration {
            output.append("   Compilation: \(String(format: "%.2fs", compilation))")
        }
        if let linking = analysis.metrics.linkingDuration {
            output.append("   Linking: \(String(format: "%.2fs", linking))")
        }
        if let memory = analysis.metrics.memoryUsage {
            output.append("   Memory Usage: \(ByteCountFormatter.string(fromByteCount: memory, countStyle: .memory))")
        }
        if let files = analysis.metrics.fileCount {
            output.append("   Files: \(files)")
        }

        // Diagnostics
        if !analysis.diagnostics.isEmpty {
            output.append("\n🔍 Diagnostics:")
            for diagnostic in analysis.diagnostics {
                let emoji = emojiForSeverity(diagnostic.severity)
                output.append("   \(emoji) [\(diagnostic.category.rawValue)] \(diagnostic.message)")
                if let location = diagnostic.location {
                    output.append("      Location: \(location)")
                }
                if let suggestion = diagnostic.suggestion {
                    output.append("      Suggestion: \(suggestion)")
                }
            }
        }

        return output.joined(separator: "\n")
    }

    public static func formatError(_ error: Error, tool: String = "smith-core") -> String {
        return """
        ❌ SMITH ERROR
        ============
        Tool: \(tool)
        Error: \(error.localizedDescription)
        Time: \(ISO8601DateFormatter().string(from: Date()))

        💡 Suggestions:
        - Check if the project path is correct
        - Verify the project build configuration
        - Run with verbose output for more details
        """
    }

    // MARK: - Summary Formatting

    public static func formatSummary(_ result: BuildResult) -> String {
        var summary: [String] = []

        // Status summary
        let statusEmoji = result.analysis.status == .success ? "✅" : "❌"
        summary.append("\(statusEmoji) Build \(result.analysis.status.rawValue)")

        // Key metrics
        if let duration = result.analysis.metrics.totalDuration {
            summary.append("⏱️ Duration: \(String(format: "%.1fs", duration))")
        }

        // Complexity
        summary.append("🔗 Complexity: \(result.analysis.dependencyGraph.complexity.rawValue) (\(result.analysis.dependencyGraph.targetCount) targets)")

        // Issues count
        let errors = result.errors.count
        let warnings = result.warnings.count
        if errors > 0 {
            summary.append("🚨 Errors: \(errors)")
        }
        if warnings > 0 {
            summary.append("⚠️ Warnings: \(warnings)")
        }

        return summary.joined(separator: " | ")
    }

    // MARK: - Private Helpers

    private static func emojiForSeverity(_ severity: Diagnostic.Severity) -> String {
        switch severity {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - JSON Response Models

private struct SmithResult: Codable {
    let tool: String
    let version: String
    let timestamp: String
    let analysis: BuildAnalysis?
    let result: BuildResult?

    init(tool: String, version: String, timestamp: String, analysis: BuildAnalysis) {
        self.tool = tool
        self.version = version
        self.timestamp = timestamp
        self.analysis = analysis
        self.result = nil
    }

    init(tool: String, version: String, timestamp: String, result: BuildResult) {
        self.tool = tool
        self.version = version
        self.timestamp = timestamp
        self.analysis = nil
        self.result = result
    }
}

private struct SmithHangResult: Codable {
    let tool: String
    let version: String
    let timestamp: String
    let hang: HangDetection
}