import XCTest
import Foundation
@testable import SBDiagnostics

/// Comprehensive tests for ProjectDetector to catch real-world detection bugs
final class ProjectDetectorTests: XCTestCase {

    // MARK: - Setup & Teardown

    var testDir: URL!

    override func setUp() {
        super.setUp()
        // Create a temporary test directory for each test
        testDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ProjectDetectorTests-\(UUID().uuidString)"
        )
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        super.tearDown()
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDir)
    }

    // MARK: - Tests for Xcode Workspace Detection

    func testDetectsXcodeWorkspaceDirectory() {
        // Create a mock .xcworkspace directory
        let workspaceURL = testDir.appendingPathComponent("Test.xcworkspace")
        try? FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Should detect as Xcode workspace
        switch projectType {
        case .xcodeWorkspace(let workspace):
            XCTAssertEqual(workspace, "Test")
        default:
            XCTFail("Expected .xcodeWorkspace but got \(projectType)")
        }
    }

    func testDetectsMultipleWorkspacesReturnsFirst() {
        // Create multiple workspaces - should return the first one
        let workspace1URL = testDir.appendingPathComponent("First.xcworkspace")
        let workspace2URL = testDir.appendingPathComponent("Second.xcworkspace")

        try? FileManager.default.createDirectory(at: workspace1URL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: workspace2URL, withIntermediateDirectories: true)

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Should detect workspace (either one is acceptable, but should be workspace not project)
        switch projectType {
        case .xcodeWorkspace:
            // Success - detected as workspace
            break
        default:
            XCTFail("Expected .xcodeWorkspace but got \(projectType)")
        }
    }

    // MARK: - Tests for Xcode Project Detection

    func testDetectsXcodeProjectDirectory() {
        // Create a mock .xcodeproj directory
        let projectURL = testDir.appendingPathComponent("Test.xcodeproj")
        try? FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Should detect as Xcode project
        switch projectType {
        case .xcodeProject(let project):
            XCTAssertEqual(project, "Test")
        default:
            XCTFail("Expected .xcodeProject but got \(projectType)")
        }
    }

    func testWorkspaceTakesPrecedenceOverProject() {
        // Create both workspace and project - workspace should win
        let workspaceURL = testDir.appendingPathComponent("App.xcworkspace")
        let projectURL = testDir.appendingPathComponent("App.xcodeproj")

        try? FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Workspace should be detected, not project
        switch projectType {
        case .xcodeWorkspace(let workspace):
            XCTAssertEqual(workspace, "App")
        default:
            XCTFail("Expected .xcodeWorkspace (takes precedence) but got \(projectType)")
        }
    }

    // MARK: - Tests for SPM Detection

    func testDetectsSPMPackage() {
        // Create a Package.swift file
        let packageURL = testDir.appendingPathComponent("Package.swift")
        try? "".write(to: packageURL, atomically: true, encoding: .utf8)

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Should detect as SPM
        switch projectType {
        case .spm:
            // Success
            break
        default:
            XCTFail("Expected .spm but got \(projectType)")
        }
    }

    func testSPMTakesPrecedenceOverXcode() {
        // Create SPM, workspace, and project - SPM should win
        let packageURL = testDir.appendingPathComponent("Package.swift")
        let workspaceURL = testDir.appendingPathComponent("App.xcworkspace")
        let projectURL = testDir.appendingPathComponent("App.xcodeproj")

        try? "".write(to: packageURL, atomically: true, encoding: .utf8)
        try? FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // SPM should be detected first (based on detection order)
        switch projectType {
        case .spm:
            // Success - SPM takes precedence
            break
        default:
            XCTFail("Expected .spm (has precedence) but got \(projectType)")
        }
    }

    // MARK: - Tests for Unknown Project

    func testUnknownProjectTypeForEmptyDirectory() {
        // Empty directory should return unknown
        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Should detect as unknown
        switch projectType {
        case .unknown:
            // Success
            break
        default:
            XCTFail("Expected .unknown for empty directory but got \(projectType)")
        }
    }

    // MARK: - Integration Tests with Real Structures

    func testDetectsRealWorkspaceStructure() {
        // Create a more realistic workspace structure
        let workspaceURL = testDir.appendingPathComponent("MyApp.xcworkspace")
        let contentsURL = workspaceURL.appendingPathComponent("contents.xcworkspacedata")

        try? FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try? "<?xml version=\"1.0\"?><Workspace></Workspace>".write(
            to: contentsURL,
            atomically: true,
            encoding: .utf8
        )

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Should still detect as workspace
        switch projectType {
        case .xcodeWorkspace(let workspace):
            XCTAssertEqual(workspace, "MyApp")
        default:
            XCTFail("Expected .xcodeWorkspace but got \(projectType)")
        }
    }

    func testDetectsRealProjectStructure() {
        // Create a more realistic project structure
        let projectURL = testDir.appendingPathComponent("MyApp.xcodeproj")
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")

        try? FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try? "archive: true".write(to: pbxprojURL, atomically: true, encoding: .utf8)

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Should detect as project
        switch projectType {
        case .xcodeProject(let project):
            XCTAssertEqual(project, "MyApp")
        default:
            XCTFail("Expected .xcodeProject but got \(projectType)")
        }
    }

    // MARK: - Tests for File Finding Methods

    func testFindWorkspaceFiles() {
        // Create multiple workspaces
        try? FileManager.default.createDirectory(
            at: testDir.appendingPathComponent("App1.xcworkspace"),
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: testDir.appendingPathComponent("App2.xcworkspace"),
            withIntermediateDirectories: true
        )

        let workspaces = ProjectDetector.findWorkspaceFiles(in: testDir.path)

        // Should find 2 workspaces
        XCTAssertEqual(workspaces.count, 2)
        XCTAssertTrue(workspaces.allSatisfy { $0.contains(".xcworkspace") })
    }

    func testFindProjectFiles() {
        // Create multiple projects
        try? FileManager.default.createDirectory(
            at: testDir.appendingPathComponent("App1.xcodeproj"),
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: testDir.appendingPathComponent("App2.xcodeproj"),
            withIntermediateDirectories: true
        )

        let projects = ProjectDetector.findProjectFiles(in: testDir.path)

        // Should find 2 projects
        XCTAssertEqual(projects.count, 2)
        XCTAssertTrue(projects.allSatisfy { $0.contains(".xcodeproj") })
    }

    func testFindPackageFiles() {
        // Create multiple Package.swift files
        let pkg1URL = testDir.appendingPathComponent("Package.swift")
        let subDir = testDir.appendingPathComponent("SubPackage")
        let pkg2URL = subDir.appendingPathComponent("Package.swift")

        try? "".write(to: pkg1URL, atomically: true, encoding: .utf8)
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try? "".write(to: pkg2URL, atomically: true, encoding: .utf8)

        let packages = ProjectDetector.findPackageFiles(in: testDir.path)

        // Should find at least the root Package.swift
        XCTAssertGreaterThanOrEqual(packages.count, 1)
        XCTAssertTrue(packages.allSatisfy { $0.contains("Package.swift") })
    }

    // MARK: - Edge Cases

    func testHiddenDirectoriesAreSkipped() {
        // Create a hidden workspace - should not be detected
        let hiddenWorkspace = testDir.appendingPathComponent(".hidden.xcworkspace")
        try? FileManager.default.createDirectory(at: hiddenWorkspace, withIntermediateDirectories: true)

        let projectType = ProjectDetector.detectProjectType(at: testDir.path)

        // Should be unknown since hidden directories are skipped
        switch projectType {
        case .unknown:
            // Success
            break
        default:
            XCTFail("Expected .unknown (hidden dirs skipped) but got \(projectType)")
        }
    }

    func testNonExistentPathReturnsUnknown() {
        let nonExistentPath = testDir.appendingPathComponent("NonExistent").path
        let projectType = ProjectDetector.detectProjectType(at: nonExistentPath)

        // Should return unknown
        switch projectType {
        case .unknown:
            // Success
            break
        default:
            XCTFail("Expected .unknown for non-existent path but got \(projectType)")
        }
    }
}
