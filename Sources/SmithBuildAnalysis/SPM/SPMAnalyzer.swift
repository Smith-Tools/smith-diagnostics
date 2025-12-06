import Foundation

/// Unified SPM Dependency Analyzer - integrates parsing and analysis
public struct SPMAnalyzer {
    private let parser = ShowDependenciesParser()
    private let resolvedParser = PackageResolvedParser()
    private let conflictDetector = PackageConflictDetector()
    private let outdatedAnalyzer = OutdatedPackageAnalyzer()

    public init() {}

    /// Analyze SPM dependencies from Package.resolved file
    public func analyzeDependencies(at path: String) -> SPMPackageAnalysis {
        let packageResolvedPath = (path as NSString).appendingPathComponent("Package.resolved")

        guard FileManager.default.fileExists(atPath: packageResolvedPath) else {
            return SPMPackageAnalysis(
                command: .showDependencies,
                success: false,
                dependencies: SPMDependencyAnalysis(),
                issues: [
                    SPMPackageIssue(
                        type: .dependencyError,
                        severity: .error,
                        message: "Package.resolved not found. Run 'swift package resolve' first."
                    )
                ]
            )
        }

        do {
            let contentString = try String(contentsOfFile: packageResolvedPath, encoding: .utf8)
            guard let content = contentString.data(using: .utf8) else {
                return SPMPackageAnalysis(
                    command: .showDependencies,
                    success: false,
                    dependencies: SPMDependencyAnalysis(),
                    issues: [
                        SPMPackageIssue(
                            type: .dependencyError,
                            severity: .error,
                            message: "Failed to convert Package.resolved to data"
                        )
                    ]
                )
            }

            // Parse Package.resolved
            let (dependencies, analysis) = try resolvedParser.parse(content)

            // Run conflict detection on the dependencies
            let conflicts = conflictDetector.detectConflicts(
                dependencies: dependencies
            )

            // Combine issues
            var allIssues = analysis.versionConflicts.map { conflict in
                SPMPackageIssue(
                    type: .versionConflict,
                    severity: .warning,
                    message: "Conflicting versions for \(conflict.dependency): \(conflict.requiredVersions.joined(separator: ", "))"
                )
            }
            allIssues.append(contentsOf: conflicts.map { conflict in
                SPMPackageIssue(
                    type: .versionConflict,
                    severity: .warning,
                    message: "Potential conflict for \(conflict.dependency): \(conflict.requiredVersions.joined(separator: ", "))"
                )
            })

            // Return updated analysis
            return SPMPackageAnalysis(
                command: .showDependencies,
                success: allIssues.isEmpty,
                dependencies: analysis,
                issues: allIssues
            )
        } catch {
            return SPMPackageAnalysis(
                command: .showDependencies,
                success: false,
                dependencies: SPMDependencyAnalysis(),
                issues: [
                    SPMPackageIssue(
                        type: .dependencyError,
                        severity: .error,
                        message: "Failed to parse Package.resolved: \(error.localizedDescription)"
                    )
                ]
            )
        }
    }

    /// Analyze dependencies from swift package show-dependencies output
    public func analyzeFromShowDependencies(_ output: String) throws -> SPMPackageAnalysis {
        return try parser.parse(output)
    }

    /// Format analysis results for output
    public func formatAnalysis(_ analysis: SPMPackageAnalysis, format: String = "summary") -> String {
        switch format {
        case "json":
            return formatJSON(analysis)
        case "detailed":
            return formatDetailed(analysis)
        default:
            return formatSummary(analysis)
        }
    }

    private func formatJSON(_ analysis: SPMPackageAnalysis) -> String {
        if let jsonData = try? JSONEncoder().encode(analysis),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }

    private func formatSummary(_ analysis: SPMPackageAnalysis) -> String {
        var output = ""

        if let deps = analysis.dependencies {
            output += "📦 Dependencies: \(deps.count)\n"
            output += "  External: \(deps.external.count)\n"
            output += "  Local: \(deps.local.count)\n"
            if deps.circularImports {
                output += "  ⚠️  Circular dependencies detected\n"
            }
        }

        if !analysis.issues.isEmpty {
            output += "\n⚠️  Issues: \(analysis.issues.count)\n"
            for issue in analysis.issues.prefix(5) {
                output += "  • \(issue.type.rawValue): \(issue.message)\n"
            }
            if analysis.issues.count > 5 {
                output += "  ... and \(analysis.issues.count - 5) more\n"
            }
        }

        return output.isEmpty ? "✅ No issues found\n" : output
    }

    private func formatDetailed(_ analysis: SPMPackageAnalysis) -> String {
        var output = ""

        output += "═══════════════════════════════════════\n"
        output += "📦 SPM DEPENDENCY ANALYSIS\n"
        output += "═══════════════════════════════════════\n\n"

        if let deps = analysis.dependencies {
            output += "Dependencies: \(deps.count) total\n"
            output += "├─ External: \(deps.external.count)\n"

            for ext in deps.external.prefix(10) {
                output += "│  ├─ \(ext.name)@\(ext.version)\n"
            }
            if deps.external.count > 10 {
                output += "│  └─ ... and \(deps.external.count - 10) more\n"
            }

            output += "└─ Local: \(deps.local.count)\n"

            if deps.circularImports {
                output += "\n⚠️  CIRCULAR DEPENDENCIES DETECTED\n"
            }
        }

        if !analysis.issues.isEmpty {
            output += "\n⚠️  Issues Found: \(analysis.issues.count)\n"
            for (index, issue) in analysis.issues.enumerated() {
                output += "\n\(index + 1). [\(issue.severity.rawValue.uppercased())] \(issue.type.rawValue)\n"
                output += "   \(issue.message)\n"
            }
        } else {
            output += "\n✅ No issues found\n"
        }

        output += "\n═══════════════════════════════════════\n"
        return output
    }
}
