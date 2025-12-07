import Foundation
import ArgumentParser

// MARK: - Core Output Models
public struct SPMPackageAnalysis: Codable {
    public let command: SwiftPackageCommand
    public let success: Bool
    public let targets: SPMTargetAnalysis?
    public internal(set) var dependencies: SPMDependencyAnalysis?
    public internal(set) var issues: [SPMPackageIssue]
    public internal(set) var metrics: PackageMetrics
    public internal(set) var rawOutput: String?
    public let security: SecurityAnalysis?
    public let outdatedPackages: OutdatedPackageAnalysis?

    public init(
        command: SwiftPackageCommand,
        success: Bool,
        targets: SPMTargetAnalysis? = nil,
        dependencies: SPMDependencyAnalysis? = nil,
        issues: [SPMPackageIssue] = [],
        metrics: PackageMetrics = PackageMetrics(),
        rawOutput: String? = nil,
        security: SecurityAnalysis? = nil,
        outdatedPackages: OutdatedPackageAnalysis? = nil
    ) {
        self.command = command
        self.success = success
        self.targets = targets
        self.dependencies = dependencies
        self.issues = issues
        self.metrics = metrics
        self.rawOutput = rawOutput
        self.security = security
        self.outdatedPackages = outdatedPackages
    }
}

public struct SPMTargetAnalysis: Codable {
    public let count: Int
    public let hasTestTargets: Bool
    public let platforms: [String]
    public let executables: [String]
    public let libraries: [String]
    public let filteredTarget: String?
    public let targets: [SPMTargetDetail]?

    public init(count: Int, hasTestTargets: Bool = false, platforms: [String] = [], executables: [String] = [], libraries: [String] = [], filteredTarget: String? = nil, targets: [SPMTargetDetail]? = nil) {
        self.count = count
        self.hasTestTargets = hasTestTargets
        self.platforms = platforms
        self.executables = executables
        self.libraries = libraries
        self.filteredTarget = filteredTarget
        self.targets = targets
    }
}

public struct SPMTargetDetail: Codable {
    public let name: String
    public let type: String
    public let platforms: [String]
    public let dependencies: [String]

    public init(name: String, type: String, platforms: [String] = [], dependencies: [String] = []) {
        self.name = name
        self.type = type
        self.platforms = platforms
        self.dependencies = dependencies
    }
}

public struct SPMDependencyAnalysis: Codable {
    public let count: Int
    public let external: [SPMExternalDependency]
    public let local: [SPMLocalDependency]
    public let circularImports: Bool
    public let versionConflicts: [SPMVersionConflict]

    public init(
        count: Int = 0,
        external: [SPMExternalDependency] = [],
        local: [SPMLocalDependency] = [],
        circularImports: Bool = false,
        versionConflicts: [SPMVersionConflict] = []
    ) {
        self.count = count
        self.external = external
        self.local = local
        self.circularImports = circularImports
        self.versionConflicts = versionConflicts
    }
}

public struct SPMExternalDependency: Codable {
    public let name: String
    public let version: String
    public let type: SPMDependencySource
    public let url: String?
    public internal(set) var importCount: Int?
    public internal(set) var relevanceScore: Double?

    public init(name: String, version: String, type: SPMDependencySource, url: String? = nil) {
        self.name = name
        self.version = version
        self.type = type
        self.url = url
    }
}

public struct SPMLocalDependency: Codable {
    public let name: String
    public let path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public struct SPMVersionConflict: Codable {
    public let dependency: String
    public let requiredVersions: [String]
    public let conflictingPackages: [String]?

    public init(dependency: String, requiredVersions: [String], conflictingPackages: [String]? = nil) {
        self.dependency = dependency
        self.requiredVersions = requiredVersions
        self.conflictingPackages = conflictingPackages
    }
}

public struct SPMSecurityVulnerability: Codable {
    public let id: String
    public let package: String
    public let affectedVersions: [String]
    public let patchedVersions: [String]
    public let severity: VulnerabilitySeverity
    public let title: String
    public let description: String
    public let references: [String]?
    public let discoveredAt: Date?

    public init(
        id: String,
        package: String,
        affectedVersions: [String],
        patchedVersions: [String],
        severity: VulnerabilitySeverity,
        title: String,
        description: String,
        references: [String]? = nil,
        discoveredAt: Date? = nil
    ) {
        self.id = id
        self.package = package
        self.affectedVersions = affectedVersions
        self.patchedVersions = patchedVersions
        self.severity = severity
        self.title = title
        self.description = description
        self.references = references
        self.discoveredAt = discoveredAt
    }
}

public struct PackageUpdate: Codable {
    public let package: String
    public let currentVersion: String
    public let latestVersion: String
    public let updateType: UpdateType
    public let releaseDate: Date?
    public let changelog: String?
    public let breakingChanges: Bool
    public let recommendation: String

    public init(
        package: String,
        currentVersion: String,
        latestVersion: String,
        updateType: UpdateType,
        releaseDate: Date? = nil,
        changelog: String? = nil,
        breakingChanges: Bool = false,
        recommendation: String = ""
    ) {
        self.package = package
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.updateType = updateType
        self.releaseDate = releaseDate
        self.changelog = changelog
        self.breakingChanges = breakingChanges
        self.recommendation = recommendation
    }
}

public struct SecurityAnalysis: Codable {
    public let vulnerabilities: [SPMSecurityVulnerability]
    public let scanDate: Date
    public let advisoriesChecked: Int

    public init(vulnerabilities: [SPMSecurityVulnerability], scanDate: Date = Date(), advisoriesChecked: Int = 0) {
        self.vulnerabilities = vulnerabilities
        self.scanDate = scanDate
        self.advisoriesChecked = advisoriesChecked
    }
}

public struct OutdatedPackageAnalysis: Codable {
    public let outdatedPackages: [PackageUpdate]
    public let scanDate: Date
    public let totalUpdates: Int

    public init(outdatedPackages: [PackageUpdate], scanDate: Date = Date(), totalUpdates: Int = 0) {
        self.outdatedPackages = outdatedPackages
        self.scanDate = scanDate
        self.totalUpdates = totalUpdates
    }
}

public struct SPMPackageIssue: Codable {
    public let type: SPMIssueType
    public let severity: SPMSeverity
    public let target: String?
    public let message: String
    public let line: Int?

    public init(type: SPMIssueType, severity: SPMSeverity, target: String? = nil, message: String, line: Int? = nil) {
        self.type = type
        self.severity = severity
        self.target = target
        self.message = message
        self.line = line
    }
}

public struct PackageMetrics: Codable {
    public let parseTime: TimeInterval
    public let complexity: SPMComplexityLevel
    public let estimatedIndexTime: String?

    public init(parseTime: TimeInterval = 0.0, complexity: SPMComplexityLevel = .unknown, estimatedIndexTime: String? = nil) {
        self.parseTime = parseTime
        self.complexity = complexity
        self.estimatedIndexTime = estimatedIndexTime
    }
}

// MARK: - Enums
public enum SwiftPackageCommand: String, Codable, CaseIterable {
    case dumpPackage = "dump-package"
    case showDependencies = "show-dependencies"
    case resolve = "resolve"
    case describe = "describe"
    case update = "update"
    case unknown = "unknown"
}

public enum SPMDependencySource: String, Codable {
    case sourceControl = "source-control"
    case binary = "binary"
    case registry = "registry"
}

public enum SPMIssueType: String, Codable {
    case circularImport = "circular_import"
    case missingTarget = "missing_target"
    case versionConflict = "version_conflict"
    case platformMismatch = "platform_mismatch"
    case syntaxError = "syntax_error"
    case dependencyError = "dependency_error"
    case networkError = "network_error"
    case securityVulnerability = "security_vulnerability"
    case outdatedPackage = "outdated_package"
    case unknown = "unknown"
}

public enum SPMSeverity: String, Codable, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

public enum SPMComplexityLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case unknown = "unknown"
}

public enum VulnerabilitySeverity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

public enum UpdateType: String, Codable, CaseIterable {
    case patch = "patch"
    case minor = "minor"
    case major = "major"
    case prerelease = "prerelease"
}

// MARK: - Output Format
public enum SPMOutputFormat: String, CaseIterable {
    case json = "json"
    case summary = "summary"
    case detailed = "detailed"
}

extension SPMOutputFormat: ExpressibleByArgument {}