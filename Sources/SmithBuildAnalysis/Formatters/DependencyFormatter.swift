import Foundation

// MARK: - Helper Types

/// Type-erased wrapper for Encodable values
struct AnyEncodable: Encodable {
    private let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

// MARK: - Main Formatter

/// Unified formatter for dependency analysis results with multiple output formats
public struct DependencyFormatter {
    public let format: OutputFormat
    public let options: FormatOptions
    public let colorScheme: ColorScheme?

    public init(
        format: OutputFormat = .tree,
        options: FormatOptions = FormatOptions(),
        colorScheme: ColorScheme? = nil
    ) {
        self.format = format
        self.options = options
        self.colorScheme = colorScheme
    }

    /// Format a dependency analysis result
    public func format(_ analysis: DependencyAnalysis) -> String {
        switch format {
        case .tree:
            return TreeFormatter(options: options, colorScheme: colorScheme).format(analysis)
        case .json:
            return JSONFormatter(options: options).format(analysis)
        case .dot:
            return DOTFormatter(options: options).format(analysis)
        case .mermaid:
            return MermaidFormatter(options: options).format(analysis)
        case .summary:
            return SummaryFormatter(options: options, colorScheme: colorScheme).format(analysis)
        case .compact:
            return CompactFormatter(options: options, colorScheme: colorScheme).format(analysis)
        }
    }

    /// Format just the dependency graph
    public func format(_ graph: DependencyGraph) -> String {
        let analysis = DependencyAnalysis(graph: graph)
        return format(analysis)
    }
}

// MARK: - Output Formats

public enum OutputFormat: String, CaseIterable {
    case tree = "tree"
    case json = "json"
    case dot = "dot"
    case mermaid = "mermaid"
    case summary = "summary"
    case compact = "compact"

    public var description: String {
        switch self {
        case .tree: return "Hierarchical tree view"
        case .json: return "Structured JSON output"
        case .dot: return "Graphviz DOT format"
        case .mermaid: return "Mermaid diagram format"
        case .summary: return "Summary with key metrics"
        case .compact: return "Compact CI/CD friendly output"
        }
    }

    public var fileExtension: String {
        switch self {
        case .tree: return "txt"
        case .json: return "json"
        case .dot: return "dot"
        case .mermaid: return "mmd"
        case .summary: return "txt"
        case .compact: return "txt"
        }
    }
}

// MARK: - Format Options

public struct FormatOptions {
    public let includeMetadata: Bool
    public let includeRecommendations: Bool
    public let includeIssues: Bool
    public let includeMetrics: Bool
    public let maxDepth: Int?
    public let showVersions: Bool
    public let showPaths: Bool
    public let sortNodes: Bool
    public let groupByType: Bool
    public let prettyPrint: Bool
    public let filterTypes: Set<DependencyNode.NodeType>?
    public let filterSeverity: Set<DependencyIssue.Severity>?

    public init(
        includeMetadata: Bool = true,
        includeRecommendations: Bool = true,
        includeIssues: Bool = true,
        includeMetrics: Bool = true,
        maxDepth: Int? = nil,
        showVersions: Bool = true,
        showPaths: Bool = false,
        sortNodes: Bool = true,
        groupByType: Bool = false,
        prettyPrint: Bool = true,
        filterTypes: Set<DependencyNode.NodeType>? = nil,
        filterSeverity: Set<DependencyIssue.Severity>? = nil
    ) {
        self.includeMetadata = includeMetadata
        self.includeRecommendations = includeRecommendations
        self.includeIssues = includeIssues
        self.includeMetrics = includeMetrics
        self.maxDepth = maxDepth
        self.showVersions = showVersions
        self.showPaths = showPaths
        self.sortNodes = sortNodes
        self.groupByType = groupByType
        self.prettyPrint = prettyPrint
        self.filterTypes = filterTypes
        self.filterSeverity = filterSeverity
    }
}

// MARK: - Color Schemes

public struct ColorScheme: Sendable {
    public let reset: String
    public let nodeColors: [DependencyNode.NodeType: String]
    public let edgeColors: [DependencyType: String]
    public let severityColors: [DependencyIssue.Severity: String]
    public let priorityColors: [DependencyRecommendation.Priority: String]

    public static let `default` = ColorScheme(
        reset: "\u{001B}[0m",
        nodeColors: [
            .package: "\u{001B}[34m",     // Blue
            .target: "\u{001B}[32m",      // Green
            .module: "\u{001B}[33m",      // Yellow
            .framework: "\u{001B}[35m",   // Magenta
            .library: "\u{001B}[36m",     // Cyan
            .binary: "\u{001B}[31m",      // Red
            .product: "\u{001B}[37m",     // White
            .unknown: "\u{001B}[90m"      // Gray
        ],
        edgeColors: [
            .direct: "\u{001B}[37m",      // White
            .indirect: "\u{001B}[90m",    // Gray
            .weak: "\u{001B}[37;2m",      // Dimmed white
            .runtime: "\u{001B}[34m",     // Blue
            .build: "\u{001B}[32m",       // Green
            .test: "\u{001B}[33m",        // Yellow
            .dynamic: "\u{001B}[36m",     // Cyan
            .static: "\u{001B}[35m",      // Magenta
            .module: "\u{001B}[33m",      // Yellow
            .package: "\u{001B}[34m",     // Blue
            .target: "\u{001B}[32m",      // Green
            .unknown: "\u{001B}[90m"      // Gray
        ],
        severityColors: [
            .info: "\u{001B}[36m",        // Cyan
            .warning: "\u{001B}[33m",     // Yellow
            .error: "\u{001B}[31m",       // Red
            .critical: "\u{001B}[31;1m"   // Bold red
        ],
        priorityColors: [
            .low: "\u{001B}[36m",         // Cyan
            .medium: "\u{001B}[33m",      // Yellow
            .high: "\u{001B}[31m",        // Red
            .critical: "\u{001B}[31;1m"   // Bold red
        ]
    )

    public static let none = ColorScheme(
        reset: "",
        nodeColors: [:],
        edgeColors: [:],
        severityColors: [:],
        priorityColors: [:]
    )
}

// MARK: - Tree Formatter

public struct TreeFormatter {
    private let options: FormatOptions
    private let colorScheme: ColorScheme?

    init(options: FormatOptions, colorScheme: ColorScheme?) {
        self.options = options
        self.colorScheme = colorScheme
    }

    public func format(_ analysis: DependencyAnalysis) -> String {
        var output = [String]()

        // Header
        output.append("Dependency Analysis")
        output.append(String(repeating: "=", count: 20))
        output.append("")

        // Metrics
        if options.includeMetrics {
            output.append(formatMetrics(analysis.metrics))
            output.append("")
        }

        // Tree structure
        output.append("Dependency Tree:")
        output.append("")

        let graph = analysis.graph
        let depths = graph.dependencyDepths()
        let rootNodes = graph.rootNodes.isEmpty ? graph.nodes.map { $0.id } : graph.rootNodes

        for rootNodeId in rootNodes {
            if let node = graph.nodes.first(where: { $0.id == rootNodeId }) {
                output.append(formatTreeNode(
                    node: node,
                    depth: 0,
                    graph: graph,
                    depths: depths,
                    visited: Set([rootNodeId])
                ))
            }
        }

        // Issues
        if options.includeIssues && !analysis.issues.isEmpty {
            output.append("")
            output.append("Issues:")
            output.append(String(repeating: "-", count: 10))

            let issues = analysis.issues.sorted { $0.severity.level > $1.severity.level }
            for issue in issues {
                if let filterSeverity = options.filterSeverity,
                   !filterSeverity.contains(issue.severity) {
                    continue
                }
                output.append(formatIssue(issue))
            }
        }

        // Recommendations
        if options.includeRecommendations && !analysis.recommendations.isEmpty {
            output.append("")
            output.append("Recommendations:")
            output.append(String(repeating: "-", count: 16))

            let recommendations = analysis.recommendations.sorted { $0.priority.level > $1.priority.level }
            for recommendation in recommendations {
                output.append(formatRecommendation(recommendation))
            }
        }

        return output.joined(separator: "\n")
    }

    private func formatTreeNode(
        node: DependencyNode,
        depth: Int,
        graph: DependencyGraph,
        depths: [String: Int],
        visited: Set<String>
    ) -> String {
        var output = [String]()

        let indent = String(repeating: "  ", count: depth)
        let icon = iconForNodeType(node.type)
        let color = colorScheme?.nodeColors[node.type] ?? ""
        let reset = colorScheme?.reset ?? ""

        var nodeInfo = "\(indent)\(icon) \(color)\(node.name)\(reset)"

        if options.showVersions, let version = node.version {
            nodeInfo += " @ \(color)\(version)\(reset)"
        }

        if options.showPaths, let path = node.path {
            nodeInfo += " (\(path))"
        }

        output.append(nodeInfo)

        // Check depth limit
        if let maxDepth = options.maxDepth, depth >= maxDepth {
            output.append("\(indent)  ...")
            return output.joined()
        }

        // Add children
        let dependencies = graph.directDependencies(of: node.id)
            .sorted { $0.name < $1.name }

        for dep in dependencies {
            if !visited.contains(dep.id) {
                let childOutput = formatTreeNode(
                    node: dep,
                    depth: depth + 1,
                    graph: graph,
                    depths: depths,
                    visited: visited.union([dep.id])
                )
                output.append(childOutput)
            }
        }

        return output.joined()
    }

    private func iconForNodeType(_ type: DependencyNode.NodeType) -> String {
        switch type {
        case .package: return "📦"
        case .target: return "🎯"
        case .module: return "📋"
        case .framework: return "🏗️"
        case .library: return "📚"
        case .binary: return "🔧"
        case .product: return "📤"
        case .unknown: return "❓"
        }
    }

    private func formatMetrics(_ metrics: DependencyMetrics) -> String {
        var output = [String]()
        output.append("Metrics:")
        output.append("  Nodes: \(metrics.totalNodes)")
        output.append("  Edges: \(metrics.totalEdges)")
        output.append("  Max Depth: \(metrics.maxDepth)")
        output.append("  Density: \(String(format: "%.2f", metrics.density))")
        output.append("  Average Dependencies: \(String(format: "%.1f", metrics.averageDependencies))")
        output.append("  Cycles: \(metrics.cycles)")

        if !metrics.rootNodes.isEmpty {
            output.append("  Root Nodes: \(metrics.rootNodes.count)")
        }

        if !metrics.leafNodes.isEmpty {
            output.append("  Leaf Nodes: \(metrics.leafNodes.count)")
        }

        if !metrics.bottleneckNodes.isEmpty {
            output.append("  Bottleneck Nodes: \(metrics.bottleneckNodes.count)")
        }

        return output.joined(separator: "\n")
    }

    private func formatIssue(_ issue: DependencyIssue) -> String {
        let color = colorScheme?.severityColors[issue.severity] ?? ""
        let reset = colorScheme?.reset ?? ""

        var output = [String]()
        output.append("\(color)[\(issue.severity.rawValue.uppercased())]\(reset) \(issue.title)")
        output.append("  \(issue.description)")

        if !issue.affectedNodes.isEmpty {
            output.append("  Affected: \(issue.affectedNodes.joined(separator: ", "))")
        }

        if let fix = issue.suggestedFix {
            output.append("  Fix: \(fix)")
        }

        return output.joined(separator: "\n")
    }

    private func formatRecommendation(_ recommendation: DependencyRecommendation) -> String {
        let color = colorScheme?.priorityColors[recommendation.priority] ?? ""
        let reset = colorScheme?.reset ?? ""

        var output = [String]()
        output.append("\(color)[\(recommendation.priority.rawValue.uppercased())]\(reset) \(recommendation.title)")
        output.append("  \(recommendation.description)")
        output.append("  Action: \(recommendation.action)")

        if !recommendation.affectedNodes.isEmpty {
            output.append("  Affects: \(recommendation.affectedNodes.joined(separator: ", "))")
        }

        output.append("  Impact: \(recommendation.estimatedImpact.rawValue), Effort: \(recommendation.effort.rawValue)")

        return output.joined(separator: "\n")
    }
}

// MARK: - JSON Formatter

public struct JSONFormatter {
    private let options: FormatOptions
    private let encoder: JSONEncoder

    init(options: FormatOptions) {
        self.options = options
        self.encoder = JSONEncoder()

        if options.prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        encoder.dateEncodingStrategy = .iso8601
    }

    public func format(_ analysis: DependencyAnalysis) -> String {
        do {
            let jsonData = try encoder.encode(analysis)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to encode JSON: \(error.localizedDescription)\"}"
        }
    }
}

// MARK: - DOT Formatter

public struct DOTFormatter {
    private let options: FormatOptions

    init(options: FormatOptions) {
        self.options = options
    }

    public func format(_ analysis: DependencyAnalysis) -> String {
        var output = [String]()
        output.append("digraph Dependencies {")
        output.append("  rankdir=TB;")
        output.append("  splines=ortho;")
        output.append("  node [shape=box, style=rounded];")
        output.append("")

        // Graph metadata
        if options.includeMetadata {
            output.append("  // Metadata")
            output.append("  label=\"Dependency Analysis - \(analysis.analyzer) v\(analysis.version)\";")
            output.append("  labelloc=t;")
            output.append("  fontsize=16;")
            output.append("")
        }

        // Add nodes
        output.append("  // Nodes")
        var nodes = analysis.graph.nodes

        if options.sortNodes {
            nodes = nodes.sorted { $0.name < $1.name }
        }

        if options.groupByType {
            for type in DependencyNode.NodeType.allCases {
                let nodesOfType = nodes.filter { $0.type == type }
                if !nodesOfType.isEmpty {
                    output.append("  // \(type.rawValue.capitalized) nodes")
                    for node in nodesOfType {
                        output.append(formatNode(node))
                    }
                    output.append("")
                }
            }
        } else {
            for node in nodes {
                output.append("  \(formatNode(node))")
            }
        }

        // Add edges
        output.append("  // Edges")
        let edges = analysis.graph.edges.sorted { $0.from < $1.from || ($0.from == $1.from && $0.to < $1.to) }
        for edge in edges {
            output.append("  \(formatEdge(edge))")
        }

        // Add clusters if grouping by type
        if options.groupByType {
            output.append("")
            output.append("  // Type clusters")
            output.append(formatClusters(analysis.graph.nodes))
        }

        output.append("}")
        return output.joined(separator: "\n")
    }

    private func formatNode(_ node: DependencyNode) -> String {
        var label = node.name
        if options.showVersions, let version = node.version {
            label += "\\n\(version)"
        }

        var attributes = ["label=\"\(label)\""]

        // Color by type
        attributes.append("fillcolor=\(colorForNodeType(node.type))")
        attributes.append("style=filled")

        // Add tooltip with metadata if available
        if !node.metadata.isEmpty {
            let tooltip = node.metadata.map { "\($0.key): \($0.value)" }.joined(separator: "\\n")
            attributes.append("tooltip=\"\(tooltip)\"")
        }

        return "\"\(node.id)\" [\(attributes.joined(separator: ", "))];"
    }

    private func formatEdge(_ edge: DependencyEdge) -> String {
        var attributes = [edgeStyle(for: edge.type)]

        if edge.weight != 1.0 {
            attributes.append("penwidth=\(edge.weight)")
        }

        // Add label if metadata exists
        if !edge.metadata.isEmpty {
            let label = edge.metadata.values.first ?? ""
            attributes.append("label=\"\(label)\"")
        }

        return "\"\(edge.from)\" -> \"\(edge.to)\" [\(attributes.joined(separator: ", "))];"
    }

    private func formatClusters(_ nodes: [DependencyNode]) -> String {
        var output = [String]()

        for type in DependencyNode.NodeType.allCases {
            let nodesOfType = nodes.filter { $0.type == type }
            if nodesOfType.count > 1 {
                output.append("  subgraph cluster_\(type.rawValue) {")
                output.append("    label=\"\(type.rawValue.capitalized)s\";")
                output.append("    style=dashed;")
                output.append("    color=\(colorForNodeType(type));")

                for node in nodesOfType {
                    output.append("    \"\(node.id)\";")
                }

                output.append("  }")
            }
        }

        return output.joined(separator: "\n")
    }

    private func edgeStyle(for type: DependencyType) -> String {
        switch type {
        case .direct:
            return "style=solid,color=black"
        case .indirect:
            return "style=dashed,color=gray"
        case .weak:
            return "style=dotted,color=gray"
        case .runtime:
            return "style=solid,color=blue"
        case .build:
            return "style=dashed,color=green"
        case .test:
            return "style=dashed,color=orange"
        case .dynamic:
            return "style=solid,color=purple"
        case .static:
            return "style=solid,color=red"
        case .module:
            return "style=solid,color=brown"
        case .package:
            return "style=solid,color=navy"
        case .target:
            return "style=solid,color=darkgreen"
        case .unknown:
            return "style=solid,color=lightgray"
        }
    }

    private func colorForNodeType(_ type: DependencyNode.NodeType) -> String {
        switch type {
        case .package: return "lightblue"
        case .target: return "lightgreen"
        case .module: return "lightyellow"
        case .framework: return "lightcoral"
        case .library: return "lightgray"
        case .binary: return "pink"
        case .product: return "lavender"
        case .unknown: return "white"
        }
    }
}

// MARK: - Mermaid Formatter

public struct MermaidFormatter {
    private let options: FormatOptions

    init(options: FormatOptions) {
        self.options = options
    }

    public func format(_ analysis: DependencyAnalysis) -> String {
        var output = [String]()
        output.append("graph TD")
        output.append("%% Dependency Analysis - \(analysis.analyzer) v\(analysis.version)")
        output.append("")

        // Define subgraphs for node types if grouping
        if options.groupByType {
            output.append("%% Node type groups")
            for type in DependencyNode.NodeType.allCases {
                let nodesOfType = analysis.graph.nodes.filter { $0.type == type }
                if !nodesOfType.isEmpty {
                    output.append("subgraph \(type.rawValue.capitalized)s[\"\(type.rawValue.capitalized)s\"]")
                    for node in nodesOfType {
                        output.append("  \(node.id)[\"\(nodeLabel(node))\"]")
                    }
                    output.append("end")
                    output.append("")
                }
            }
        }

        // Add nodes (if not grouping)
        if !options.groupByType {
            output.append("%% Nodes")
            for node in analysis.graph.nodes {
                output.append("  \(node.id)[\"\(nodeLabel(node))\"]")
            }
            output.append("")
        }

        // Add edges
        output.append("%% Dependencies")
        for edge in analysis.graph.edges {
            let toNode = analysis.graph.nodes.first { $0.id == edge.to }
            let linkType = linkTypeForDependency(edge.type)
            var edgeLine = "  \(edge.from) \(linkType) \(edge.to)"

            // Add version info to label
            if options.showVersions, let toVersion = toNode?.version {
                edgeLine += "|@ \(toVersion)"
            }

            output.append(edgeLine)
        }

        // Add styling for node types
        output.append("")
        output.append("%% Styling")
        for type in DependencyNode.NodeType.allCases {
            let nodesOfType = analysis.graph.nodes.filter { $0.type == type }
            if !nodesOfType.isEmpty {
                output.append("classDef \(type.rawValue) fill:\(mermaidColorForNodeType(type)),stroke:#333,stroke-width:2px")
                let nodeIds = nodesOfType.map { $0.id }.joined(separator: ",")
                output.append("class \(nodeIds) \(type.rawValue)")
            }
        }

        // Add legend for edge types
        if analysis.graph.edges.count > 0 {
            output.append("")
            output.append("%% Legend")
            let edgeTypes = Set(analysis.graph.edges.map { $0.type })
            for type in edgeTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
                output.append("%% \(type.rawValue.capitalized): \(linkTypeForDependency(type))")
            }
        }

        return output.joined(separator: "\n")
    }

    private func nodeLabel(_ node: DependencyNode) -> String {
        var label = node.name
        if options.showVersions, let version = node.version {
            label += "<br>@ \(version)"
        }
        return label
    }

    private func linkTypeForDependency(_ type: DependencyType) -> String {
        switch type {
        case .direct:
            return "-->"
        case .indirect:
            return "-.->"
        case .weak:
            return "-..->"
        case .runtime:
            return "==>"
        case .build:
            return "-.->"
        case .test:
            return "-.->"
        case .dynamic:
            return "-->"
        case .static:
            return "==>"
        case .module:
            return "-->"
        case .package:
            return "-->"
        case .target:
            return "-->"
        case .unknown:
            return "-->"
        }
    }

    private func mermaidColorForNodeType(_ type: DependencyNode.NodeType) -> String {
        switch type {
        case .package: return "#e3f2fd"
        case .target: return "#e8f5e9"
        case .module: return "#fff9c4"
        case .framework: return "#ffebee"
        case .library: return "#f5f5f5"
        case .binary: return "#fce4ec"
        case .product: return "#f3e5f5"
        case .unknown: return "#ffffff"
        }
    }
}

// MARK: - Summary Formatter

public struct SummaryFormatter {
    private let options: FormatOptions
    private let colorScheme: ColorScheme?

    init(options: FormatOptions, colorScheme: ColorScheme?) {
        self.options = options
        self.colorScheme = colorScheme
    }

    public func format(_ analysis: DependencyAnalysis) -> String {
        var output = [String]()

        // Header
        output.append("Dependency Analysis Summary")
        output.append(String(repeating: "=", count: 28))
        output.append("")

        // Overview metrics
        output.append("📊 Overview")
        output.append(String(repeating: "-", count: 10))
        output.append("Total Dependencies: \(analysis.metrics.totalNodes)")
        output.append("Direct Relationships: \(analysis.metrics.totalEdges)")
        output.append("Maximum Depth: \(analysis.metrics.maxDepth)")
        output.append("Graph Density: \(String(format: "%.1f", analysis.metrics.density * 100))%")
        output.append("")

        // Node type breakdown
        output.append("🏗️ Components")
        output.append(String(repeating: "-", count: 13))
        let typeCounts = Dictionary(grouping: analysis.graph.nodes, by: { $0.type })
            .mapValues { $0.count }
            .sorted { $0.key.rawValue < $1.key.rawValue }

        for (type, count) in typeCounts {
            let icon = iconForNodeType(type)
            let color = colorScheme?.nodeColors[type] ?? ""
            let reset = colorScheme?.reset ?? ""
            output.append("\(icon) \(color)\(type.rawValue.capitalized)\(reset): \(count)")
        }
        output.append("")

        // Critical issues
        let criticalIssues = analysis.issues.filter { $0.severity.level >= 3 }
        if !criticalIssues.isEmpty {
            output.append("🚨 Critical Issues")
            output.append(String(repeating: "-", count: 18))
            for issue in criticalIssues.prefix(5) {
                output.append(formatIssueSummary(issue))
            }
            if criticalIssues.count > 5 {
                output.append("  ... and \(criticalIssues.count - 5) more")
            }
            output.append("")
        }

        // Top recommendations
        let highPriorityRecs = analysis.recommendations.filter { $0.priority.level >= 3 }
        if !highPriorityRecs.isEmpty {
            output.append("💡 Priority Recommendations")
            output.append(String(repeating: "-", count: 26))
            for rec in highPriorityRecs.prefix(3) {
                output.append(formatRecommendationSummary(rec))
            }
            if highPriorityRecs.count > 3 {
                output.append("  ... and \(highPriorityRecs.count - 3) more")
            }
            output.append("")
        }

        // Health score
        let healthScore = calculateHealthScore(analysis)
        let healthEmoji = healthEmoji(for: healthScore)
        output.append("\(healthEmoji) Overall Health Score: \(String(format: "%.0f", healthScore * 100))%")

        return output.joined(separator: "\n")
    }

    private func iconForNodeType(_ type: DependencyNode.NodeType) -> String {
        switch type {
        case .package: return "📦"
        case .target: return "🎯"
        case .module: return "📋"
        case .framework: return "🏗️"
        case .library: return "📚"
        case .binary: return "🔧"
        case .product: return "📤"
        case .unknown: return "❓"
        }
    }

    private func formatIssueSummary(_ issue: DependencyIssue) -> String {
        let color = colorScheme?.severityColors[issue.severity] ?? ""
        let reset = colorScheme?.reset ?? ""
        return "  \(color)●\(reset) \(issue.title) (\(issue.affectedNodes.count) affected)"
    }

    private func formatRecommendationSummary(_ rec: DependencyRecommendation) -> String {
        let color = colorScheme?.priorityColors[rec.priority] ?? ""
        let reset = colorScheme?.reset ?? ""
        return "  \(color)→\(reset) \(rec.title) [\(rec.estimatedImpact.rawValue) impact]"
    }

    private func healthEmoji(for score: Double) -> String {
        switch score {
        case 0.8...1.0: return "💚"
        case 0.6..<0.8: return "💛"
        case 0.4..<0.6: return "🧡"
        case 0.2..<0.4: return "❤️"
        default: return "💔"
        }
    }

    private func calculateHealthScore(_ analysis: DependencyAnalysis) -> Double {
        var score = 1.0

        // Penalize for issues
        let issueWeights: [DependencyIssue.Severity: Double] = [
            .critical: 0.3,
            .error: 0.2,
            .warning: 0.1,
            .info: 0.05
        ]

        for issue in analysis.issues {
            score -= issueWeights[issue.severity] ?? 0
        }

        // Penalize for cycles
        let cycles = analysis.graph.findCycles()
        score -= Double(cycles.count) * 0.15

        // Penalize for high density
        if analysis.metrics.density > 0.5 {
            score -= (analysis.metrics.density - 0.5) * 0.2
        }

        // Bonus for good structure
        if analysis.metrics.maxDepth <= 3 {
            score += 0.1
        }

        return max(0, min(1, score))
    }
}

// MARK: - Compact Formatter

public struct CompactFormatter {
    private let options: FormatOptions
    private let colorScheme: ColorScheme?

    init(options: FormatOptions, colorScheme: ColorScheme?) {
        self.options = options
        self.colorScheme = colorScheme
    }

    public func format(_ analysis: DependencyAnalysis) -> String {
        var output = [String]()

        // Single line summary
        let criticalCount = analysis.issues.filter { $0.severity == .critical }.count
        let errorCount = analysis.issues.filter { $0.severity == .error }.count
        let warningCount = analysis.issues.filter { $0.severity == .warning }.count

        var summary = "deps: \(analysis.metrics.totalNodes), depth: \(analysis.metrics.maxDepth)"

        if criticalCount > 0 {
            summary += ", critical: \(criticalCount)"
        }
        if errorCount > 0 {
            summary += ", errors: \(errorCount)"
        }
        if warningCount > 0 {
            summary += ", warnings: \(warningCount)"
        }

        let cycles = analysis.graph.findCycles().count
        if cycles > 0 {
            summary += ", cycles: \(cycles)"
        }

        output.append(summary)

        // Exit code for CI
        if criticalCount > 0 || errorCount > 0 || cycles > 0 {
            output.append("EXIT_CODE=1")
        } else {
            output.append("EXIT_CODE=0")
        }

        // Quick metrics as key-value pairs
        output.append("metrics_total_nodes=\(analysis.metrics.totalNodes)")
        output.append("metrics_total_edges=\(analysis.metrics.totalEdges)")
        output.append("metrics_max_depth=\(analysis.metrics.maxDepth)")
        output.append("metrics_density=\(String(format: "%.3f", analysis.metrics.density))")
        output.append("metrics_cycles=\(cycles)")
        output.append("issues_critical=\(criticalCount)")
        output.append("issues_error=\(errorCount)")
        output.append("issues_warning=\(warningCount)")

        return output.joined(separator: "\n")
    }
}