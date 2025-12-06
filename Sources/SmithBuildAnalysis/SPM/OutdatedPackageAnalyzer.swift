import Foundation

public struct OutdatedPackageAnalyzer {

    public init() {}

    /// Analyzes dependencies for outdated versions
    public func analyzeOutdatedPackages(_ dependencies: [SPMExternalDependency]) async -> OutdatedPackageAnalysis {
        var outdatedPackages: [PackageUpdate] = []

        for dependency in dependencies {
            if let update = await checkForUpdate(dependency) {
                outdatedPackages.append(update)
            }
        }

        return OutdatedPackageAnalysis(
            outdatedPackages: outdatedPackages,
            scanDate: Date(),
            totalUpdates: outdatedPackages.count
        )
    }

    /// Checks a single dependency for available updates
    private func checkForUpdate(_ dependency: SPMExternalDependency) async -> PackageUpdate? {
        // Try GitHub API first for GitHub-hosted packages
        if let githubURL = dependency.url, githubURL.contains("github.com") {
            if let update = await checkGitHubUpdate(dependency) {
                return update
            }
        }

        // Fall back to Swift Package Index
        if let update = await checkSwiftPackageIndex(dependency) {
            return update
        }

        return nil
    }

    /// Checks GitHub API for package updates
    private func checkGitHubUpdate(_ dependency: SPMExternalDependency) async -> PackageUpdate? {
        guard let githubURL = dependency.url else { return nil }

        // Extract owner and repo from GitHub URL
        let urlComponents = githubURL.split(separator: "/")
        guard urlComponents.count >= 2 else { return nil }

        let owner = String(urlComponents[urlComponents.count - 2])
        let repo = String(urlComponents[urlComponents.count - 1])
            .replacingOccurrences(of: ".git", with: "")

        // Check GitHub releases
        let releasesURL = "https://api.github.com/repos/\(owner)/\(repo)/releases"

        guard let url = URL(string: releasesURL) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let releases = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return analyzeReleases(releases, currentVersion: dependency.version, package: dependency.name)
            }
        } catch {
            // Log error but don't fail
            print("Failed to fetch releases for \(dependency.name): \(error)")
        }

        return nil
    }

    /// Checks Swift Package Index for package updates
    private func checkSwiftPackageIndex(_ dependency: SPMExternalDependency) async -> PackageUpdate? {
        let url = "https://swiftpackageindex.com/api/packages/\(dependency.name.lowercased())"

        guard let packageURL = URL(string: url) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: packageURL)

            if let packageInfo = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let versions = packageInfo["versions"] as? [[String: Any]] {
                return analyzeSwiftPackageVersions(versions, currentVersion: dependency.version, package: dependency.name)
            }
        } catch {
            print("Failed to fetch Swift Package Index data for \(dependency.name): \(error)")
        }

        return nil
    }

    /// Analyzes GitHub releases to determine the latest version
    private func analyzeReleases(_ releases: [[String: Any]], currentVersion: String, package: String) -> PackageUpdate? {
        guard let latestRelease = releases.first(where: { !($0["prerelease"] as? Bool ?? false) }) else {
            return nil
        }

        guard let tagName = latestRelease["tag_name"] as? String else { return nil }

        // Clean version tag (remove 'v' prefix if present)
        let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        // Compare versions
        guard isVersionNewer(latestVersion, than: currentVersion) else { return nil }

        let updateType = determineUpdateType(from: currentVersion, to: latestVersion)
        let breakingChanges = determineBreakingChanges(from: currentVersion, to: latestVersion)
        let releaseDate = parseDate(latestRelease["published_at"] as? String)

        // Generate recommendation
        let recommendation = generateRecommendation(
            package: package,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateType: updateType,
            breakingChanges: breakingChanges
        )

        return PackageUpdate(
            package: package,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateType: updateType,
            releaseDate: releaseDate,
            changelog: latestRelease["body"] as? String,
            breakingChanges: breakingChanges,
            recommendation: recommendation
        )
    }

    /// Analyzes Swift Package Index versions
    private func analyzeSwiftPackageVersions(_ versions: [[String: Any]], currentVersion: String, package: String) -> PackageUpdate? {
        guard let latestVersionInfo = versions.first,
              let latestVersion = latestVersionInfo["version"] as? String else {
            return nil
        }

        guard isVersionNewer(latestVersion, than: currentVersion) else { return nil }

        let updateType = determineUpdateType(from: currentVersion, to: latestVersion)
        let breakingChanges = determineBreakingChanges(from: currentVersion, to: latestVersion)

        let recommendation = generateRecommendation(
            package: package,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateType: updateType,
            breakingChanges: breakingChanges
        )

        return PackageUpdate(
            package: package,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateType: updateType,
            releaseDate: nil,
            changelog: nil,
            breakingChanges: breakingChanges,
            recommendation: recommendation
        )
    }

    // MARK: - Version Comparison

    private func isVersionNewer(_ newVersion: String, than oldVersion: String) -> Bool {
        guard let new = parseSemanticVersion(newVersion),
              let old = parseSemanticVersion(oldVersion) else {
            // Fallback to string comparison
            return newVersion.compare(oldVersion, options: .numeric) == .orderedDescending
        }

        if new.major != old.major { return new.major > old.major }
        if new.minor != old.minor { return new.minor > old.minor }
        return new.patch > old.patch
    }

    private func parseSemanticVersion(_ version: String) -> (major: Int, minor: Int, patch: Int)? {
        // Remove any pre-release identifiers and build metadata
        let versionSplit = version.split(separator: "-")
        let baseVersion: String.SubSequence
        if let first = versionSplit.first {
            baseVersion = first
        } else {
            baseVersion = version[...].prefix(0)
        }
        let cleanVersion = baseVersion.split(separator: "+").first ?? baseVersion

        let components = cleanVersion.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 3 else { return nil }
        return (major: components[0], minor: components[1], patch: components[2])
    }

    // MARK: - Update Analysis

    private func determineUpdateType(from currentVersion: String, to latestVersion: String) -> UpdateType {
        guard let current = parseSemanticVersion(currentVersion),
              let latest = parseSemanticVersion(latestVersion) else {
            return .patch
        }

        if latest.major > current.major {
            return .major
        } else if latest.minor > current.minor {
            return .minor
        } else {
            return .patch
        }
    }

    private func determineBreakingChanges(from currentVersion: String, to latestVersion: String) -> Bool {
        guard let current = parseSemanticVersion(currentVersion),
              let latest = parseSemanticVersion(latestVersion) else {
            return false
        }

        // Major version changes indicate potential breaking changes
        return latest.major > current.major
    }

    // MARK: - Recommendation Generation

    private func generateRecommendation(
        package: String,
        currentVersion: String,
        latestVersion: String,
        updateType: UpdateType,
        breakingChanges: Bool
    ) -> String {
        switch updateType {
        case .major:
            return breakingChanges ?
                "⚠️ Major update available. Review migration guide and test thoroughly before updating from \(currentVersion) to \(latestVersion)." :
                "Major update available with improvements. Consider updating after testing your application."

        case .minor:
            return "✅ Minor update available with new features. Generally safe to update from \(currentVersion) to \(latestVersion)."

        case .patch:
            return "✅ Patch update available with bug fixes. Recommended to update from \(currentVersion) to \(latestVersion)."

        case .prerelease:
            return "🧪 Pre-release available for testing. Use with caution in production environments."
        }
    }

    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    // MARK: - Additional Analysis Features

    /// Provides upgrade priority based on update type and security implications
    public func calculateUpgradePriority(for update: PackageUpdate) -> UpgradePriority {
        switch update.updateType {
        case .patch:
            return .high // Bug fixes are usually important
        case .minor:
            return .medium
        case .major:
            return update.breakingChanges ? .low : .medium
        case .prerelease:
            return .low
        }
    }

    /// Estimates update effort based on breaking changes and version jump
    public func estimateUpdateEffort(for update: PackageUpdate) -> UpdateEffort {
        if update.breakingChanges {
            return .significant
        }

        guard let current = parseSemanticVersion(update.currentVersion),
              let latest = parseSemanticVersion(update.latestVersion) else {
            return .unknown
        }

        let versionJump = (latest.major - current.major) * 100 +
                         (latest.minor - current.minor) * 10 +
                         (latest.patch - current.patch)

        switch versionJump {
        case 0...1:
            return .minimal
        case 2...10:
            return .low
        case 11...50:
            return .moderate
        default:
            return .significant
        }
    }
}

// MARK: - Supporting Enums

public enum UpgradePriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

public enum UpdateEffort: String, Codable, CaseIterable {
    case minimal = "minimal"
    case low = "low"
    case moderate = "moderate"
    case significant = "significant"
    case unknown = "unknown"
}