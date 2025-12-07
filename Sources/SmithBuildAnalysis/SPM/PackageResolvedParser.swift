import Foundation

public struct PackageResolvedParser {

    public init() {}

    /// Parses Package.resolved file content
    public func parse(_ content: Data) throws -> (dependencies: [SPMExternalDependency], analysis: SPMDependencyAnalysis) {
        guard let json = try JSONSerialization.jsonObject(with: content) as? [String: Any] else {
            throw ParseError.invalidFormat("Not valid JSON")
        }

        guard let pins = json["pins"] as? [[String: Any]] else {
            throw ParseError.missingPins("No pins found in Package.resolved")
        }

        var dependencies: [SPMExternalDependency] = []
        var localDependencies: [SPMLocalDependency] = []

        for pin in pins {
            if let dependency = parsePin(pin) {
                dependencies.append(dependency)
            }
            if let localDep = parseLocalPin(pin) {
                localDependencies.append(localDep)
            }
        }

        // Create dependency analysis
        let analysis = SPMDependencyAnalysis(
            count: dependencies.count + localDependencies.count,
            external: dependencies,
            local: localDependencies,
            circularImports: false,
            versionConflicts: []
        )

        return (dependencies, analysis)
    }

    /// Parses Package.swift to work with Package.resolved
    public func parsePackageSwift(_ content: String) throws -> [String: DependencyInfo] {
        var packages: [String: DependencyInfo] = [:]

        // Extract package dependencies using regex
        let packageRegex = try? NSRegularExpression(
            pattern: #"\.package\(.*?url:\s*["']([^"']+)["'](?:.*?from:\s*["']([^"']+)["'])?(?:.*?exact:\s*["']([^"']+)["'])?"#,
            options: [.dotMatchesLineSeparators]
        )

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = packageRegex?.matches(in: content, options: [], range: range) ?? []

        for match in matches {
            if let urlRange = Range(match.range(at: 1), in: content) {
                let url = String(content[urlRange])
                let packageName = extractPackageName(from: url)

                var version: String?
                if let versionRange = Range(match.range(at: 2), in: content) {
                    version = String(content[versionRange])
                } else if let exactRange = Range(match.range(at: 3), in: content) {
                    version = String(content[exactRange])
                }

                let info = DependencyInfo(
                    name: packageName,
                    url: url,
                    versionRequirement: version,
                    isLocal: url.hasPrefix(".") || url.hasPrefix("/")
                )

                packages[packageName] = info
            }
        }

        return packages
    }

    /// Compares Package.swift requirements with resolved versions
    public func compareRequirementsWithResolved(
        requirements: [String: DependencyInfo],
        resolved: [SPMExternalDependency]
    ) -> [RequirementIssue] {
        var issues: [RequirementIssue] = []

        for resolvedDep in resolved {
            if let requirement = requirements[resolvedDep.name] {
                if !isVersionSatisfied(resolvedDep.version, requirement: requirement.versionRequirement) {
                    let issue = RequirementIssue(
                        package: resolvedDep.name,
                        resolvedVersion: resolvedDep.version,
                        requirement: requirement.versionRequirement,
                        issueType: .versionNotSatisfied
                    )
                    issues.append(issue)
                }
            } else {
                // Resolved dependency not found in Package.swift
                let issue = RequirementIssue(
                    package: resolvedDep.name,
                    resolvedVersion: resolvedDep.version,
                    requirement: nil,
                    issueType: .notInManifest
                )
                issues.append(issue)
            }
        }

        return issues
    }

    // MARK: - Private Helper Methods

    private func parsePin(_ pin: [String: Any]) -> SPMExternalDependency? {
        // v1 format: package, state.location
        // v2/v3 format: identity, location (top-level), state.version/revision
        
        let name = (pin["package"] as? String) ?? (pin["identity"] as? String)
        
        guard let packageName = name else { return nil }
        
        let state = pin["state"] as? [String: Any] ?? [:]
        
        // Location can be top-level (v2/v3) or inside state (v1)
        let location = (pin["location"] as? String) ?? (state["location"] as? String)
        
        guard let packageURL = location else { return nil }

        // Determine dependency type
        let dependencyType: SPMDependencySource
        if packageURL.hasPrefix("http") {
            dependencyType = .sourceControl
        } else if packageURL.hasPrefix("binary") {
            dependencyType = .binary
        } else {
            dependencyType = .registry
        }

        // Get version or branch
        var version: String = ""
        if let v = state["version"] as? String {
            version = v
        } else if let b = state["branch"] as? String {
            version = "branch: \(b)"
        } else if let r = state["revision"] as? String {
            version = "revision: \(String(r.prefix(7)))"
        }

        return SPMExternalDependency(
            name: packageName,
            version: version,
            type: dependencyType,
            url: packageURL
        )
    }

    private func parseLocalPin(_ pin: [String: Any]) -> SPMLocalDependency? {
        guard let package = pin["package"] as? String,
              let state = pin["state"] as? [String: Any],
              let location = state["location"] as? String else {
            return nil
        }

        // Check if it's a local path
        if location.hasPrefix(".") || location.hasPrefix("/") {
            return SPMLocalDependency(name: package, path: location)
        }

        return nil
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

    private func isVersionSatisfied(_ version: String, requirement: String?) -> Bool {
        guard let requirement = requirement else { return true }

        // Handle exact version
        if requirement.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil {
            return version == requirement
        }

        // Handle "from:" requirement (minimum version)
        if requirement.hasPrefix(">=") {
            let minVersion = requirement.dropFirst(2).trimmingCharacters(in: .whitespaces)
            return isVersionGreaterOrEqual(version, than: minVersion)
        }

        // Handle range requirements
        if requirement.contains("...") {
            let parts = requirement.split(separator: "...")
            if parts.count == 2 {
                let minVersion = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let maxVersion = String(parts[1]).trimmingCharacters(in: .whitespaces)
                return isVersionGreaterOrEqual(version, than: minVersion) &&
                       isVersionLessOrEqual(version, than: maxVersion)
            }
        }

        // For now, assume satisfied
        return true
    }

    private func isVersionGreaterOrEqual(_ version1: String, than version2: String) -> Bool {
        guard let v1 = parseSemanticVersion(version1),
              let v2 = parseSemanticVersion(version2) else {
            return version1 >= version2
        }

        if v1.major != v2.major { return v1.major > v2.major }
        if v1.minor != v2.minor { return v1.minor > v2.minor }
        return v1.patch >= v2.patch
    }

    private func isVersionLessOrEqual(_ version1: String, than version2: String) -> Bool {
        guard let v1 = parseSemanticVersion(version1),
              let v2 = parseSemanticVersion(version2) else {
            return version1 <= version2
        }

        if v1.major != v2.major { return v1.major < v2.major }
        if v1.minor != v2.minor { return v1.minor < v2.minor }
        return v1.patch <= v2.patch
    }

    private func parseSemanticVersion(_ version: String) -> (major: Int, minor: Int, patch: Int)? {
        // Remove any prefixes like "v", "branch:", "revision:"
        let cleanVersionString = version
            .replacingOccurrences(of: "v", with: "")
            .replacingOccurrences(of: "branch: ", with: "")
            .replacingOccurrences(of: "revision: ", with: "")
        let versionSplit = cleanVersionString.split(separator: "-")
        let baseVersion: String.SubSequence
        if let first = versionSplit.first {
            baseVersion = first
        } else {
            baseVersion = cleanVersionString[...].prefix(0)
        }
        let cleanVersion = baseVersion.split(separator: "+").first ?? baseVersion

        let components = cleanVersion.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 3 else { return nil }
        return (major: components[0], minor: components[1], patch: components[2])
    }
}

// MARK: - Supporting Types

public struct DependencyInfo {
    public let name: String
    public let url: String
    public let versionRequirement: String?
    public let isLocal: Bool
}

public struct RequirementIssue {
    public let package: String
    public let resolvedVersion: String
    public let requirement: String?
    public let issueType: RequirementIssueType
}

public enum RequirementIssueType {
    case versionNotSatisfied
    case notInManifest
    case outdatedRequirement
}

public enum ParseError: Error {
    case invalidFormat(String)
    case missingPins(String)
    case corruptedData(String)
}