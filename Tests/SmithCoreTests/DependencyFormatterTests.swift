import XCTest
@testable import SmithBuildAnalysis

final class DependencyFormatterTests: XCTestCase {

    func testTreeFormatter() {
        // Create test nodes
        let nodes = [
            DependencyNode(
                id: "main",
                name: "MainApp",
                version: "1.0.0",
                type: .target
            ),
            DependencyNode(
                id: "utils",
                name: "Utils",
                version: "2.1.0",
                type: .package
            )
        ]

        // Create test edges
        let edges = [
            DependencyEdge(
                from: "main",
                to: "utils",
                type: .direct
            )
        ]

        // Create graph and analysis
        let graph = DependencyGraph(nodes: nodes, edges: edges)
        let analysis = DependencyAnalysis(
            graph: graph,
            analyzer: "TestFormatter",
            version: "1.0.0"
        )

        // Test tree formatter
        let formatter = DependencyFormatter(format: .tree)
        let output = formatter.format(analysis)

        XCTAssertFalse(output.isEmpty)
        XCTAssertTrue(output.contains("Dependency Analysis"))
        XCTAssertTrue(output.contains("MainApp"))
        XCTAssertTrue(output.contains("Utils"))
    }

    func testJSONFormatter() {
        let nodes = [
            DependencyNode(id: "app", name: "App", type: .target)
        ]
        let edges = [
            DependencyEdge(from: "app", to: "lib", type: .direct)
        ]

        let graph = DependencyGraph(nodes: nodes, edges: edges)
        let analysis = DependencyAnalysis(graph: graph)

        let formatter = DependencyFormatter(format: .json, options: FormatOptions(prettyPrint: true))
        let output = formatter.format(analysis)

        XCTAssertTrue(output.contains("\"analyzer\""))
        XCTAssertTrue(output.contains("\"graph\""))
        XCTAssertTrue(output.contains("\"nodes\""))
        XCTAssertTrue(output.contains("\"edges\""))
    }

    func testSummaryFormatter() {
        let nodes = [
            DependencyNode(id: "a", name: "A", type: .package),
            DependencyNode(id: "b", name: "B", type: .target),
            DependencyNode(id: "c", name: "C", type: .module)
        ]

        let graph = DependencyGraph(nodes: nodes, edges: [])
        let analysis = DependencyAnalysis(graph: graph)

        let formatter = DependencyFormatter(format: .summary)
        let output = formatter.format(analysis)

        XCTAssertTrue(output.contains("Dependency Analysis Summary"))
        XCTAssertTrue(output.contains("Overview"))
        XCTAssertTrue(output.contains("Components"))
        XCTAssertTrue(output.contains("📦"))
        XCTAssertTrue(output.contains("🎯"))
        XCTAssertTrue(output.contains("📋"))
    }

    func testCompactFormatter() {
        let graph = DependencyGraph(nodes: [], edges: [])
        let analysis = DependencyAnalysis(graph: graph)

        let formatter = DependencyFormatter(format: .compact)
        let output = formatter.format(analysis)

        XCTAssertTrue(output.contains("deps:"))
        XCTAssertTrue(output.contains("EXIT_CODE="))
        XCTAssertTrue(output.contains("metrics_total_nodes=0"))
    }

    func testDOTFormatter() {
        let nodes = [DependencyNode(id: "a", name: "A", type: .target)]
        let edges = [DependencyEdge(from: "a", to: "b", type: .direct)]

        let graph = DependencyGraph(nodes: nodes, edges: edges)
        let analysis = DependencyAnalysis(graph: graph)

        let formatter = DependencyFormatter(format: .dot)
        let output = formatter.format(analysis)

        XCTAssertTrue(output.contains("digraph Dependencies"))
        XCTAssertTrue(output.contains("rankdir=TB"))
        XCTAssertTrue(output.contains("\"a\" -> \"b\""))
    }

    func testMermaidFormatter() {
        let nodes = [DependencyNode(id: "a", name: "A", type: .target)]
        let edges = [DependencyEdge(from: "a", to: "b", type: .direct)]

        let graph = DependencyGraph(nodes: nodes, edges: edges)
        let analysis = DependencyAnalysis(graph: graph)

        let formatter = DependencyFormatter(format: .mermaid)
        let output = formatter.format(analysis)

        XCTAssertTrue(output.contains("graph TD"))
        XCTAssertTrue(output.contains("a --> b"))
        XCTAssertTrue(output.contains("classDef"))
    }
}