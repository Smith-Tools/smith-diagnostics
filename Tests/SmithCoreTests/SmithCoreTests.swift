import XCTest
@testable import SBDiagnostics

final class SmithCoreTests: XCTestCase {

    func testProjectTypeDetection() {
        // Test with known project types
        let tempDir = FileManager.default.temporaryDirectory

        // Test SPM detection
        let spmAnalysis = SmithCore.quickAnalyze(at: tempDir.path)
        // Should not be SPM since no Package.swift exists

        XCTAssertEqual(spmAnalysis.projectType, .unknown)
    }

    func testDependencyGraphComplexity() {
        // Test complexity calculation
        let lowComplexity = BuildDependencySummary.calculateComplexity(targetCount: 5, maxDepth: 2)
        XCTAssertEqual(lowComplexity, .low)

        let mediumComplexity = BuildDependencySummary.calculateComplexity(targetCount: 25, maxDepth: 4)
        XCTAssertEqual(mediumComplexity, .medium)

        let highComplexity = BuildDependencySummary.calculateComplexity(targetCount: 75, maxDepth: 7)
        XCTAssertEqual(highComplexity, .high)

        let extremeComplexity = BuildDependencySummary.calculateComplexity(targetCount: 150, maxDepth: 10)
        XCTAssertEqual(extremeComplexity, .extreme)
    }

    func testBuildAnalysisCreation() {
        let projectType = ProjectType.xcodeWorkspace(workspace: "Test.xcworkspace")
        let dependencyGraph = BuildDependencySummary(
            targetCount: 10,
            maxDepth: 3,
            circularDeps: false,
            complexity: .low
        )

        let analysis = BuildAnalysis(
            projectType: projectType,
            status: .success,
            dependencyGraph: dependencyGraph
        )

        XCTAssertEqual(analysis.projectType, .xcodeWorkspace(workspace: "Test.xcworkspace"))
        XCTAssertEqual(analysis.status, .success)
        XCTAssertEqual(analysis.dependencyGraph.targetCount, 10)
        XCTAssertEqual(analysis.dependencyGraph.complexity, .low)
    }

    func testDiagnosticCreation() {
        let diagnostic = Diagnostic(
            severity: .warning,
            category: .dependency,
            message: "Test warning",
            location: "Test.swift",
            suggestion: "Fix the issue"
        )

        XCTAssertEqual(diagnostic.severity, .warning)
        XCTAssertEqual(diagnostic.category, .dependency)
        XCTAssertEqual(diagnostic.message, "Test warning")
        XCTAssertEqual(diagnostic.location, "Test.swift")
        XCTAssertEqual(diagnostic.suggestion, "Fix the issue")
    }

    func testJSONSerialization() {
        let analysis = BuildAnalysis(
            projectType: .spm,
            status: .success,
            dependencyGraph: BuildDependencySummary(
                targetCount: 5,
                maxDepth: 2,
                circularDeps: false,
                complexity: .low
            )
        )

        let jsonData = SmithOutputFormatter.formatAnalysis(analysis)
        XCTAssertNotNil(jsonData)

        // Test that we can decode it back
        if let data = jsonData {
            do {
                let decoded = try JSONDecoder().decode(SmithResult.self, from: data)
                XCTAssertEqual(decoded.tool, "smith-core")
                XCTAssertEqual(decoded.version, "1.0.0")
                XCTAssertNotNil(decoded.analysis)
                XCTAssertEqual(decoded.analysis?.projectType, .spm)
            } catch {
                XCTFail("Failed to decode JSON: \(error)")
            }
        }
    }

    func testHumanReadableOutput() {
        let analysis = BuildAnalysis(
            projectType: .xcodeProject(project: "Test.xcodeproj"),
            status: .failed,
            dependencyGraph: BuildDependencySummary(
                targetCount: 25,
                maxDepth: 5,
                circularDeps: true,
                bottleneckTargets: ["TargetA", "TargetB"],
                complexity: .high
            ),
            diagnostics: [
                Diagnostic(
                    severity: .error,
                    category: .dependency,
                    message: "Circular dependency detected",
                    suggestion: "Break the circular import"
                )
            ]
        )

        let output = SmithOutputFormatter.formatHumanReadable(analysis)

        XCTAssertTrue(output.contains("SMITH BUILD ANALYSIS"))
        XCTAssertTrue(output.contains("Xcode Project"))
        XCTAssertTrue(output.contains("Test.xcodeproj"))
        XCTAssertTrue(output.contains("Targets: 25"))
        XCTAssertTrue(output.contains("Circular Dependencies: Yes"))
        XCTAssertTrue(output.contains("Complexity: high"))
        XCTAssertTrue(output.contains("Circular dependency detected"))
    }

    func testRiskAssessment() {
        let lowRisk = BuildAnalysis(
            projectType: .spm,
            status: .success,
            dependencyGraph: BuildDependencySummary(
                targetCount: 5,
                maxDepth: 2,
                circularDeps: false,
                complexity: .low
            )
        )

        XCTAssertEqual(lowRisk.riskLevel, "Low")
        XCTAssertTrue(lowRisk.isLikelyFast)

        let highRisk = BuildAnalysis(
            projectType: .xcodeWorkspace(workspace: "Complex.xcworkspace"),
            status: .failed,
            dependencyGraph: BuildDependencySummary(
                targetCount: 150,
                maxDepth: 10,
                circularDeps: true,
                complexity: .extreme
            )
        )

        XCTAssertEqual(highRisk.riskLevel, "High")
        XCTAssertFalse(highRisk.isLikelyFast)
    }

    func testDependencyGraphRecommendations() {
        let complexGraph = BuildDependencySummary(
            targetCount: 120,
            maxDepth: 8,
            circularDeps: true,
            complexity: .extreme
        )

        let recs = complexGraph.recommendations
        XCTAssertTrue(recs.contains("Consider breaking into smaller modules"))
        XCTAssertTrue(recs.contains("Reduce dependency depth"))
        XCTAssertTrue(recs.contains("Eliminate circular dependencies"))
        XCTAssertTrue(recs.contains("Use incremental builds"))
        XCTAssertTrue(recs.contains("Monitor build cache health"))
    }
}

// Helper struct for JSON decoding tests
private struct SmithResult: Codable {
    let tool: String
    let version: String
    let timestamp: String
    let analysis: BuildAnalysis?
    let result: BuildResult?
}