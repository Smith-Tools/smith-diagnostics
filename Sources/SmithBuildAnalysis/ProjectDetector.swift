import Foundation

// MARK: - Project Detector

public struct ProjectDetector {

    // MARK: - Project Type Detection

    public static func detectProjectType(at path: String) -> ProjectType {
        let url = URL(fileURLWithPath: path)

        // Check for SPM package first
        if isSPMPackage(at: url) {
            return .spm
        }

        // Check for Xcode workspace
        if let workspace = findWorkspace(at: url) {
            return .xcodeWorkspace(workspace: workspace)
        }

        // Check for Xcode project
        if let project = findProject(at: url) {
            return .xcodeProject(project: project)
        }

        return .unknown
    }

    // MARK: - File Discovery

    public static func findWorkspaceFiles(in path: String) -> [String] {
        let url = URL(fileURLWithPath: path)
        return findDirectories(withExtension: "xcworkspace", in: url)
    }

    public static func findProjectFiles(in path: String) -> [String] {
        let url = URL(fileURLWithPath: path)
        return findDirectories(withExtension: "xcodeproj", in: url)
    }

    public static func findPackageFiles(in path: String) -> [String] {
        let url = URL(fileURLWithPath: path)
        return findFiles(withName: "Package.swift", in: url)
    }

    // MARK: - Directory Search

    private static func findDirectories(withExtension fileExtension: String, in url: URL) -> [String] {
        var result: [String] = []

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for itemURL in contents {
            guard let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDirectory = resourceValues.isDirectory,
                  isDirectory else {
                continue
            }

            if itemURL.pathExtension == fileExtension {
                result.append(itemURL.path)
            }
        }

        return result.sorted()
    }

    // MARK: - Project Analysis

    public static func analyzeProjectComplexity(at path: String) -> BuildDependencySummary? {
        let projectType = detectProjectType(at: path)

        switch projectType {
        case .spm:
            return analyzeSPMComplexity(at: path)
        case .xcodeWorkspace, .xcodeProject:
            return analyzeXcodeComplexity(at: path)
        case .unknown:
            return nil
        }
    }

    // MARK: - Private Methods

    private static func isSPMPackage(at url: URL) -> Bool {
        let packageURL = url.appendingPathComponent("Package.swift")
        return FileManager.default.fileExists(atPath: packageURL.path)
    }

    private static func findWorkspace(at url: URL) -> String? {
        let workspaces = findDirectories(withExtension: "xcworkspace", in: url)
        if let fullPath = workspaces.first {
            // Extract just the workspace name from the full path
            let workspaceURL = URL(fileURLWithPath: fullPath)
            return workspaceURL.deletingPathExtension().lastPathComponent
        }
        return nil
    }

    private static func findProject(at url: URL) -> String? {
        let projects = findDirectories(withExtension: "xcodeproj", in: url)
        if let fullPath = projects.first {
            // Extract just the project name from the full path
            let projectURL = URL(fileURLWithPath: fullPath)
            return projectURL.deletingPathExtension().lastPathComponent
        }
        return nil
    }

    private static func findFiles(withExtension fileExtension: String, in url: URL) -> [String] {
        var result: [String] = []

        let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
        guard let directoryEnumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let isDirectory = resourceValues.isDirectory else {
                continue
            }

            if !isDirectory && fileURL.pathExtension == fileExtension {
                result.append(fileURL.path)
            }
        }

        return result.sorted()
    }

    private static func findFiles(withName name: String, in url: URL) -> [String] {
        var result: [String] = []

        let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
        guard let directoryEnumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for case let fileURL as URL in directoryEnumerator {
            guard fileURL.lastPathComponent == name else {
                continue
            }

            result.append(fileURL.path)
        }

        return result.sorted()
    }

    private static func analyzeSPMComplexity(at path: String) -> BuildDependencySummary {
        // Delegates to smith spm analyze for detailed analysis
        // For now, return basic analysis
        return BuildDependencySummary(
            targetCount: 0,
            maxDepth: 0,
            circularDeps: false,
            complexity: .low
        )
    }

    private static func analyzeXcodeComplexity(at path: String) -> BuildDependencySummary {
        // Delegates to smith xcode analyze for detailed analysis
        // For now, return basic analysis
        return BuildDependencySummary(
            targetCount: 0,
            maxDepth: 0,
            circularDeps: false,
            complexity: .medium // Assume medium for Xcode projects
        )
    }
}

// MARK: - Build System Detection

public struct BuildSystemDetector {

    public static func detectAvailableBuildSystems() -> [BuildSystem] {
        var systems: [BuildSystem] = []

        // Check for Xcode
        if isXcodeAvailable() {
            systems.append(.xcode)
        }

        // Check for Swift
        if isSwiftAvailable() {
            systems.append(.swift)
        }

        // Check for Sift tools
        if commandExists("spmsift") {
            systems.append(.spmsift)
        }

        if commandExists("sbsift") {
            systems.append(.sbsift)
        }

        if commandExists("xcsift") {
            systems.append(.xcsift)
        }

        return systems
    }

    private static func isXcodeAvailable() -> Bool {
        return commandExists("xcodebuild")
    }

    private static func isSwiftAvailable() -> Bool {
        return commandExists("swift")
    }

    private static func commandExists(_ command: String) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/which"
        task.arguments = [command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        task.launch()
        task.waitUntilExit()

        return task.terminationStatus == 0
    }
}

// MARK: - Supporting Types

public enum BuildSystem {
    case xcode
    case swift
    case spmsift
    case sbsift
    case xcsift

    public var name: String {
        switch self {
        case .xcode: return "Xcode"
        case .swift: return "Swift"
        case .spmsift: return "spmsift"
        case .sbsift: return "sbsift"
        case .xcsift: return "xcsift"
        }
    }
}