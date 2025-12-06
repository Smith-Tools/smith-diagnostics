import Foundation

public struct PackageConflictDetector {

    public init() {}

    /// Detects version conflicts in package dependencies
    public func detectConflicts(dependencies: [SPMExternalDependency]) -> [SPMVersionConflict] {
        var conflicts: [SPMVersionConflict] = []
        var dependencyVersions: [String: [String]] = [:]
        var dependencySources: [String: [String]] = [:]

        // Group dependencies by name and collect their versions
        for dependency in dependencies {
            if dependencyVersions[dependency.name] == nil {
                dependencyVersions[dependency.name] = []
                dependencySources[dependency.name] = []
            }
            dependencyVersions[dependency.name]?.append(dependency.version)
            dependencySources[dependency.name]?.append("direct")
        }

        // Check for version conflicts
        for (packageName, versions) in dependencyVersions {
            let uniqueVersions = Array(Set(versions))

            if uniqueVersions.count > 1 {
                // Check if versions are compatible
                if !areVersionsCompatible(uniqueVersions) {
                    let conflict = SPMVersionConflict(
                        dependency: packageName,
                        requiredVersions: uniqueVersions,
                        conflictingPackages: dependencySources[packageName]
                    )
                    conflicts.append(conflict)
                }
            }
        }

        return conflicts
    }

    /// Analyzes Package.swift content for potential version constraints
    public func analyzePackageSwift(content: String) -> [SPMVersionConflict] {
        var conflicts: [SPMVersionConflict] = []

        // Extract package dependencies using regex
        let packageRegex = try? NSRegularExpression(
            pattern: #"\.package\(.*?url:\s*["']([^"']+)["'].*?from:\s*["']([^"']+)["']"#,
            options: [.dotMatchesLineSeparators]
        )

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = packageRegex?.matches(in: content, options: [], range: range) ?? []

        var packages: [String: [String]] = [:]

        for match in matches {
            if let urlRange = Range(match.range(at: 1), in: content),
               let versionRange = Range(match.range(at: 2), in: content) {
                let url = String(content[urlRange])
                let version = String(content[versionRange])

                let packageName = extractPackageName(from: url)
                if packages[packageName] == nil {
                    packages[packageName] = []
                }
                packages[packageName]?.append(version)
            }
        }

        // Check for conflicts
        for (packageName, versions) in packages {
            let uniqueVersions = Array(Set(versions))
            if uniqueVersions.count > 1 && !areVersionRequirementsCompatible(uniqueVersions) {
                let conflict = SPMVersionConflict(
                    dependency: packageName,
                    requiredVersions: uniqueVersions,
                    conflictingPackages: nil
                )
                conflicts.append(conflict)
            }
        }

        return conflicts
    }

    /// Analyzes Package.resolved for pinned versions that might conflict
    public func analyzePackageResolved(content: Data) -> [SPMVersionConflict] {
        guard let json = try? JSONSerialization.jsonObject(with: content) as? [String: Any],
              let pins = json["pins"] as? [[String: Any]] else {
            return []
        }

        var pinnedPackages: [String: String] = [:]

        for pin in pins {
            if let name = pin["package"] as? String,
               let state = pin["state"] as? [String: Any],
               let version = state["version"] as? String {
                pinnedPackages[name] = version
            }
        }

        // For Package.resolved, conflicts are less common since versions are pinned,
        // but we can still identify potential issues with the resolved state
        var conflicts: [SPMVersionConflict] = []

        // Check for duplicate packages with different versions (shouldn't happen in valid .resolved)
        let packageNames = Array(pinnedPackages.keys)
        let uniqueNames = Set(packageNames)

        if packageNames.count != uniqueNames.count {
            // Find duplicates
            var nameCounts: [String: Int] = [:]
            for name in packageNames {
                nameCounts[name, default: 0] += 1
            }

            for (name, count) in nameCounts where count > 1 {
                let versions = packageNames.compactMap { pinnedPackages[$0] }
                let conflict = SPMVersionConflict(
                    dependency: name,
                    requiredVersions: versions,
                    conflictingPackages: ["Package.resolved"]
                )
                conflicts.append(conflict)
            }
        }

        return conflicts
    }

    // MARK: - Private Helper Methods

    private func areVersionsCompatible(_ versions: [String]) -> Bool {
        // Simple compatibility check - can be enhanced with semantic version parsing
        guard versions.count == 2 else { return false }

        let sortedVersions = versions.sorted()
        return sortedVersions[0] == sortedVersions[1]
    }

    private func areVersionRequirementsCompatible(_ requirements: [String]) -> Bool {
        // Check if version requirements can be satisfied simultaneously
        // This is a simplified check - a real implementation would use semantic versioning
        guard requirements.count == 2 else { return false }

        // Check for direct version pins
        let versionRegex = try? NSRegularExpression(pattern: #"^\d+\.\d+\.\d+$"#)

        for requirement in requirements {
            let range = NSRange(requirement.startIndex..<requirement.endIndex, in: requirement)
            let matches = versionRegex?.matches(in: requirement, options: [], range: range)
            if let matches = matches, !matches.isEmpty {
                // Direct version pin
                return requirements.allSatisfy { $0 == requirement }
            }
        }

        // For now, assume compatibility for range requirements
        return true
    }

    private func extractPackageName(from url: String) -> String {
        if url.contains("github.com") {
            let components = url.split(separator: "/")
            if components.count >= 2 {
                return String(components[components.count - 1])
                    .replacingOccurrences(of: ".git", with: "")
            }
        }
        return URL(string: url)?.lastPathComponent ?? url
    }
}

// MARK: - Semantic Version Helper

extension PackageConflictDetector {

    /// Parses a semantic version string
    private func parseSemanticVersion(_ version: String) -> (major: Int, minor: Int, patch: Int)? {
        let components = version.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 3 else { return nil }
        return (major: components[0], minor: components[1], patch: components[2])
    }

    /// Checks if two version ranges overlap
    private func versionRangesOverlap(_ range1: String, _ range2: String) -> Bool {
        // This is a simplified implementation
        // A full implementation would parse range requirements like ">=1.2.3,<2.0.0"

        if range1.contains(">=") && range2.contains("<=") {
            return true // Conservative approach
        }
        if range2.contains(">=") && range1.contains("<=") {
            return true
        }

        return false
    }
}