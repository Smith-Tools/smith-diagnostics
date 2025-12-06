import Foundation

// MARK: - Core Dependency Types

/// Represents the type of dependency relationship between nodes
public enum DependencyType: String, Codable, CaseIterable, Sendable {
    case direct = "direct"           // Explicit dependency
    case indirect = "indirect"       // Transitive dependency
    case weak = "weak"               // Optional dependency
    case runtime = "runtime"         // Runtime dependency
    case build = "build"             // Build-time only dependency
    case test = "test"               // Test dependency
    case dynamic = "dynamic"         // Dynamically linked
    case `static` = "static"           // Statically linked
    case module = "module"           // Module import
    case package = "package"         // Package dependency
    case target = "target"           // Target dependency
    case unknown = "unknown"

    public var category: Category {
        switch self {
        case .direct, .indirect:
            return .structural
        case .weak, .runtime:
            return .runtime
        case .build, .test:
            return .buildTime
        case .dynamic, .static:
            return .linking
        case .module, .package, .target:
            return .modular
        case .unknown:
            return .unspecified
        }
    }

    public enum Category: String, Codable {
        case structural = "structural"
        case runtime = "runtime"
        case buildTime = "build_time"
        case linking = "linking"
        case modular = "modular"
        case unspecified = "unspecified"
    }
}

/// Represents a node in the dependency graph (package, target, or module)
public struct DependencyNode: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let version: String?
    public let path: String?
    public let type: NodeType
    public let metadata: [String: String]

    public enum NodeType: String, Codable, CaseIterable, Sendable {
        case package = "package"
        case target = "target"
        case module = "module"
        case framework = "framework"
        case library = "library"
        case binary = "binary"
        case product = "product"
        case unknown = "unknown"
    }

    public init(
        id: String,
        name: String,
        version: String? = nil,
        path: String? = nil,
        type: NodeType = .unknown,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.path = path
        self.type = type
        self.metadata = metadata
    }
}

/// Represents an edge in the dependency graph
public struct DependencyEdge: Codable, Hashable {
    public let from: String  // Source node ID
    public let to: String    // Target node ID
    public let type: DependencyType
    public let weight: Double // Optional weight for analysis
    public let metadata: [String: String]

    public init(
        from: String,
        to: String,
        type: DependencyType,
        weight: Double = 1.0,
        metadata: [String: String] = [:]
    ) {
        self.from = from
        self.to = to
        self.type = type
        self.weight = weight
        self.metadata = metadata
    }
}

/// Generic dependency graph structure
public struct DependencyGraph: Codable {
    public let nodes: [DependencyNode]
    public let edges: [DependencyEdge]
    public let metadata: [String: String]

    // Computed properties for analysis
    public var nodeCount: Int { nodes.count }
    public var edgeCount: Int { edges.count }
    public var isEmpty: Bool { nodes.isEmpty }
    public var rootNodes: [String] { nodes.filter { incomingEdges(to: $0.id).isEmpty }.map { $0.id } }

    public init(
        nodes: [DependencyNode] = [],
        edges: [DependencyEdge] = [],
        metadata: [String: String] = [:]
    ) {
        self.nodes = nodes
        self.edges = edges
        self.metadata = metadata
    }

    /// Get all nodes of a specific type
    public func nodes(ofType type: DependencyNode.NodeType) -> [DependencyNode] {
        nodes.filter { $0.type == type }
    }

    /// Get all edges of a specific type
    public func edges(ofType type: DependencyType) -> [DependencyEdge] {
        edges.filter { $0.type == type }
    }

    /// Get outgoing edges from a node
    public func outgoingEdges(from nodeId: String) -> [DependencyEdge] {
        edges.filter { $0.from == nodeId }
    }

    /// Get incoming edges to a node
    public func incomingEdges(to nodeId: String) -> [DependencyEdge] {
        edges.filter { $0.to == nodeId }
    }

    /// Get direct dependencies of a node
    public func directDependencies(of nodeId: String) -> [DependencyNode] {
        let edgeTargets = outgoingEdges(from: nodeId).map { $0.to }
        return nodes.filter { edgeTargets.contains($0.id) }
    }

    /// Get dependents of a node (nodes that depend on this node)
    public func dependents(of nodeId: String) -> [DependencyNode] {
        let edgeSources = incomingEdges(to: nodeId).map { $0.from }
        return nodes.filter { edgeSources.contains($0.id) }
    }

    /// Calculate graph density
    public var density: Double {
        guard nodeCount > 1 else { return 0.0 }
        return Double(edgeCount) / Double(nodeCount * (nodeCount - 1))
    }

    /// Find circular dependencies
    public func findCycles() -> [[String]] {
        var visited = Set<String>()
        var recursionStack = Set<String>()
        var cycles: [[String]] = []
        var path: [String] = []

        func dfs(nodeId: String) {
            visited.insert(nodeId)
            recursionStack.insert(nodeId)
            path.append(nodeId)

            for edge in outgoingEdges(from: nodeId) {
                if !visited.contains(edge.to) {
                    dfs(nodeId: edge.to)
                } else if recursionStack.contains(edge.to) {
                    // Found a cycle
                    if let cycleStart = path.firstIndex(of: edge.to) {
                        let cycle = Array(path[cycleStart...]) + [edge.to]
                        cycles.append(cycle)
                    }
                }
            }

            recursionStack.remove(nodeId)
            path.removeLast()
        }

        for node in nodes {
            if !visited.contains(node.id) {
                dfs(nodeId: node.id)
            }
        }

        return cycles
    }

    /// Calculate dependency depth for each node
    public func dependencyDepths() -> [String: Int] {
        var depths: [String: Int] = [:]
        let nodesWithNoDeps = nodes.filter { outgoingEdges(from: $0.id).isEmpty }

        // Initialize nodes with no dependencies
        for node in nodesWithNoDeps {
            depths[node.id] = 0
        }

        // Calculate depths using topological sort
        var changed = true
        while changed {
            changed = false
            for node in nodes {
                let incoming = incomingEdges(to: node.id)
                if incoming.isEmpty {
                    if depths[node.id] == nil {
                        depths[node.id] = 0
                        changed = true
                    }
                } else {
                    let dependencyDepths = incoming.compactMap { depths[$0.from] }
                    if dependencyDepths.count == incoming.count && depths[node.id] == nil {
                        depths[node.id] = (dependencyDepths.max() ?? 0) + 1
                        changed = true
                    }
                }
            }
        }

        return depths
    }

    /// Get maximum depth of the dependency graph
    public var maxDepth: Int {
        let depths = dependencyDepths()
        return depths.values.max() ?? 0
    }
}

// MARK: - Analysis Results

/// Unified dependency analysis result container
public struct DependencyAnalysis: Codable {
    public let graph: DependencyGraph
    public let metrics: DependencyMetrics
    public let issues: [DependencyIssue]
    public let recommendations: [DependencyRecommendation]
    public let timestamp: Date
    public let analyzer: String
    public let version: String

    public init(
        graph: DependencyGraph,
        metrics: DependencyMetrics? = nil,
        issues: [DependencyIssue] = [],
        recommendations: [DependencyRecommendation] = [],
        analyzer: String = "unknown",
        version: String = "1.0.0"
    ) {
        self.graph = graph
        self.metrics = metrics ?? DependencyMetrics(from: graph)
        self.issues = issues
        self.recommendations = recommendations
        self.timestamp = Date()
        self.analyzer = analyzer
        self.version = version
    }
}

/// Metrics calculated from a dependency graph
public struct DependencyMetrics: Codable {
    public let totalNodes: Int
    public let totalEdges: Int
    public let maxDepth: Int
    public let cycles: Int
    public let density: Double
    public let averageDependencies: Double
    public let bottleneckNodes: [String]
    public let leafNodes: [String]
    public let rootNodes: [String]

    public init(from graph: DependencyGraph) {
        self.totalNodes = graph.nodeCount
        self.totalEdges = graph.edgeCount
        self.maxDepth = graph.maxDepth
        self.cycles = graph.findCycles().count
        self.density = graph.density

        // Calculate average number of dependencies per node
        let totalDependencies = graph.nodes.map { graph.outgoingEdges(from: $0.id).count }.reduce(0, +)
        self.averageDependencies = totalNodes > 0 ? Double(totalDependencies) / Double(totalNodes) : 0.0

        // Find bottleneck nodes (nodes with many dependents)
        let dependencyCounts = graph.nodes.map { ($0.id, graph.incomingEdges(to: $0.id).count) }
        let avgDeps = dependencyCounts.map { $0.1 }.reduce(0, +) / max(dependencyCounts.count, 1)
        self.bottleneckNodes = dependencyCounts.filter { $0.1 > avgDeps * 2 }.map { $0.0 }

        // Find leaf nodes (nodes with no outgoing edges)
        self.leafNodes = graph.nodes.filter { graph.outgoingEdges(from: $0.id).isEmpty }.map { $0.id }

        // Find root nodes (nodes with no incoming edges)
        self.rootNodes = graph.nodes.filter { graph.incomingEdges(to: $0.id).isEmpty }.map { $0.id }
    }
}

/// Base class for dependency-related issues
public class DependencyIssue: Codable {
    public let id: String
    public let type: IssueType
    public let severity: Severity
    public let title: String
    public let description: String
    public let affectedNodes: [String]
    public let suggestedFix: String?
    public let metadata: [String: String]

    public enum IssueType: String, Codable {
        case circularDependency = "circular_dependency"
        case outdatedDependency = "outdated_dependency"
        case securityVulnerability = "security_vulnerability"
        case versionConflict = "version_conflict"
        case missingDependency = "missing_dependency"
        case unusedDependency = "unused_dependency"
        case incompatiblePlatform = "incompatible_platform"
        case licenseConflict = "license_conflict"
        case duplicateDependency = "duplicate_dependency"
        case transitiveBloat = "transitive_bloat"
        case unknown = "unknown"
    }

    public enum Severity: String, Codable, CaseIterable, Sendable {
        case info = "info"
        case warning = "warning"
        case error = "error"
        case critical = "critical"

        public var level: Int {
            switch self {
            case .info: return 1
            case .warning: return 2
            case .error: return 3
            case .critical: return 4
            }
        }
    }

    public init(
        id: String,
        type: IssueType,
        severity: Severity,
        title: String,
        description: String,
        affectedNodes: [String] = [],
        suggestedFix: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.affectedNodes = affectedNodes
        self.suggestedFix = suggestedFix
        self.metadata = metadata
    }
}

/// Circular dependency issue
public class CircularDependency: DependencyIssue {
    public let cycle: [String]
    public let cycleLength: Int

    public init(
        cycle: [String],
        metadata: [String: String] = [:]
    ) {
        self.cycle = cycle
        self.cycleLength = cycle.count

        let cycleDescription = cycle.joined(separator: " → ")
        super.init(
            id: "cycle-\(cycle.hashValue)",
            type: .circularDependency,
            severity: .error,
            title: "Circular Dependency Detected",
            description: "Circular dependency found: \(cycleDescription)",
            affectedNodes: cycle,
            suggestedFix: "Consider refactoring to break the cycle by extracting common functionality into a separate module",
            metadata: metadata
        )
    }

    enum CodingKeys: String, CodingKey {
        case cycle, cycleLength
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cycle = try container.decode([String].self, forKey: .cycle)
        cycleLength = try container.decode(Int.self, forKey: .cycleLength)

        let cycleDescription = cycle.joined(separator: " → ")
        super.init(
            id: "cycle-\(cycle.hashValue)",
            type: .circularDependency,
            severity: .error,
            title: "Circular Dependency Detected",
            description: "Circular dependency found: \(cycleDescription)",
            affectedNodes: cycle,
            suggestedFix: "Consider refactoring to break the cycle by extracting common functionality into a separate module"
        )
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cycle, forKey: .cycle)
        try container.encode(cycleLength, forKey: .cycleLength)
    }
}

/// Outdated dependency issue
public class OutdatedDependency: DependencyIssue {
    public let currentVersion: String
    public let latestVersion: String
    public let updateAvailable: Bool

    public init(
        nodeId: String,
        currentVersion: String,
        latestVersion: String,
        metadata: [String: String] = [:]
    ) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.updateAvailable = currentVersion != latestVersion

        let severity: Severity = {
            let current = SemanticVersion(currentVersion) ?? SemanticVersion(0, 0, 0)
            let latest = SemanticVersion(latestVersion) ?? SemanticVersion(0, 0, 0)

            if latest.major > current.major {
                return .warning
            } else if latest.minor > current.minor {
                return .info
            } else {
                return .info
            }
        }()

        super.init(
            id: "outdated-\(nodeId)",
            type: .outdatedDependency,
            severity: severity,
            title: "Outdated Dependency",
            description: "Dependency \(nodeId) is outdated (current: \(currentVersion), latest: \(latestVersion))",
            affectedNodes: [nodeId],
            suggestedFix: "Update to version \(latestVersion) using your package manager",
            metadata: metadata
        )
    }

    enum CodingKeys: String, CodingKey {
        case currentVersion, latestVersion, updateAvailable
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentVersion = try container.decode(String.self, forKey: .currentVersion)
        latestVersion = try container.decode(String.self, forKey: .latestVersion)
        updateAvailable = try container.decode(Bool.self, forKey: .updateAvailable)

        let nodeId = container.codingPath.last?.stringValue ?? "unknown"
        super.init(
            id: "outdated-\(nodeId)",
            type: .outdatedDependency,
            severity: .info,
            title: "Outdated Dependency",
            description: "Dependency \(nodeId) is outdated (current: \(currentVersion), latest: \(latestVersion))",
            affectedNodes: [nodeId],
            suggestedFix: "Update to version \(latestVersion) using your package manager"
        )
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentVersion, forKey: .currentVersion)
        try container.encode(latestVersion, forKey: .latestVersion)
        try container.encode(updateAvailable, forKey: .updateAvailable)
    }
}

/// Security vulnerability issue
public class SecurityVulnerability: DependencyIssue {
    public let cveId: String?
    public let severityScore: Double?
    public let patchedVersion: String?

    public init(
        nodeId: String,
        cveId: String? = nil,
        severityScore: Double? = nil,
        patchedVersion: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.cveId = cveId
        self.severityScore = severityScore
        self.patchedVersion = patchedVersion

        let severity: Severity = {
            if let score = severityScore {
                switch score {
                case 0..<4: return .info
                case 4..<7: return .warning
                case 7..<9: return .error
                default: return .critical
                }
            }
            return .warning
        }()

        let description = cveId != nil
            ? "Security vulnerability \(cveId!) found in dependency \(nodeId)"
            : "Security vulnerability found in dependency \(nodeId)"

        let fix = patchedVersion != nil
            ? "Update to version \(patchedVersion!) or later to patch the vulnerability"
            : "Check for security updates and apply patches as soon as possible"

        super.init(
            id: "security-\(nodeId)-\(cveId ?? "unknown")",
            type: .securityVulnerability,
            severity: severity,
            title: "Security Vulnerability",
            description: description,
            affectedNodes: [nodeId],
            suggestedFix: fix,
            metadata: metadata
        )
    }

    enum CodingKeys: String, CodingKey {
        case cveId, severityScore, patchedVersion
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cveId = try container.decodeIfPresent(String.self, forKey: .cveId)
        severityScore = try container.decodeIfPresent(Double.self, forKey: .severityScore)
        patchedVersion = try container.decodeIfPresent(String.self, forKey: .patchedVersion)

        let nodeId = container.codingPath.last?.stringValue ?? "unknown"
        super.init(
            id: "security-\(nodeId)-\(cveId ?? "unknown")",
            type: .securityVulnerability,
            severity: .warning,
            title: "Security Vulnerability",
            description: "Security vulnerability found in dependency \(nodeId)",
            affectedNodes: [nodeId],
            suggestedFix: "Check for security updates and apply patches as soon as possible"
        )
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(cveId, forKey: .cveId)
        try container.encodeIfPresent(severityScore, forKey: .severityScore)
        try container.encodeIfPresent(patchedVersion, forKey: .patchedVersion)
    }
}

/// Recommendation for improving dependencies
public struct DependencyRecommendation: Codable {
    public let id: String
    public let type: RecommendationType
    public let priority: Priority
    public let title: String
    public let description: String
    public let action: String
    public let affectedNodes: [String]
    public let estimatedImpact: ImpactLevel
    public let effort: EffortLevel

    public enum RecommendationType: String, Codable, CaseIterable {
        case removeUnused = "remove_unused"
        case updateVersion = "update_version"
        case consolidateDuplicate = "consolidate_duplicate"
        case extractCommon = "extract_common"
        case reduceTransitive = "reduce_transitive"
        case fixCircular = "fix_circular"
        case resolveConflict = "resolve_conflict"
        case improveStructure = "improve_structure"
        case securityPatch = "security_patch"
        case optimizeLoad = "optimize_load"
    }

    public enum Priority: String, Codable, CaseIterable, Sendable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"

        public var level: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .critical: return 4
            }
        }
    }

    public enum ImpactLevel: String, Codable, CaseIterable {
        case minimal = "minimal"
        case minor = "minor"
        case moderate = "moderate"
        case significant = "significant"
        case major = "major"
    }

    public enum EffortLevel: String, Codable, CaseIterable {
        case trivial = "trivial"
        case low = "low"
        case medium = "medium"
        case high = "high"
        case extensive = "extensive"
    }

    public init(
        id: String,
        type: RecommendationType,
        priority: Priority,
        title: String,
        description: String,
        action: String,
        affectedNodes: [String] = [],
        estimatedImpact: ImpactLevel = .moderate,
        effort: EffortLevel = .medium
    ) {
        self.id = id
        self.type = type
        self.priority = priority
        self.title = title
        self.description = description
        self.action = action
        self.affectedNodes = affectedNodes
        self.estimatedImpact = estimatedImpact
        self.effort = effort
    }
}

// MARK: - Utility Protocols

/// Common interface for dependency analyzers
public protocol DependencyAnalyzerProtocol {
    associatedtype InputType
    associatedtype OutputType

    func analyze(input: InputType) throws -> OutputType
    var name: String { get }
    var version: String { get }
    var supportedProjectTypes: [ProjectType] { get }
}

/// Graph visualization format enum
public enum VisualizationFormat: String, CaseIterable, Sendable {
    case dot = "dot"
    case mermaid = "mermaid"
    case plantUml = "plantuml"
    case json = "json"
    case csv = "csv"
    case d3 = "d3"
    case graphviz = "graphviz"
}

/// Protocol for graph visualization
public protocol GraphVisualization {
    func visualize(graph: DependencyGraph) -> String
    var format: VisualizationFormat { get }
    var fileExtension: String { get }
}

/// DOT format visualization
public struct DOTVisualization: GraphVisualization {
    public let format: VisualizationFormat = .dot
    public let fileExtension: String = "dot"

    public func visualize(graph: DependencyGraph) -> String {
        var output = "digraph Dependencies {\n"
        output += "  rankdir=TB;\n"
        output += "  node [shape=box];\n\n"

        // Add nodes
        for node in graph.nodes {
            let label = node.version != nil ? "\(node.name)\\n\(node.version!)" : node.name
            output += "  \"\(node.id)\" [label=\"\(label)\"];\n"
        }

        output += "\n"

        // Add edges
        for edge in graph.edges {
            let style = edgeStyle(for: edge.type)
            output += "  \"\(edge.from)\" -> \"\(edge.to)\" [\(style)];\n"
        }

        output += "}"
        return output
    }

    private func edgeStyle(for type: DependencyType) -> String {
        switch type {
        case .direct:
            return "style=solid"
        case .indirect:
            return "style=dashed,color=gray"
        case .weak:
            return "style=dotted"
        case .runtime:
            return "style=solid,color=blue"
        case .build:
            return "style=dashed,color=green"
        case .test:
            return "style=dashed,color=orange"
        default:
            return "style=solid"
        }
    }
}

/// Mermaid format visualization
public struct MermaidVisualization: GraphVisualization {
    public let format: VisualizationFormat = .mermaid
    public let fileExtension: String = "mmd"

    public func visualize(graph: DependencyGraph) -> String {
        var output = "graph TD\n"

        // Add edges (Mermaid automatically creates nodes)
        for edge in graph.edges {
            let fromNode = graph.nodes.first { $0.id == edge.from }
            let toNode = graph.nodes.first { $0.id == edge.to }

            let fromLabel = fromNode?.name ?? edge.from
            let toLabel = toNode?.name ?? edge.to

            let arrow = arrowType(for: edge.type)
            output += "  \(fromLabel) \(arrow) \(toLabel)\n"
        }

        // Add styling for node types
        output += "\n"
        let nodeTypes = Set(graph.nodes.map { $0.type })
        for type in nodeTypes {
            let nodesOfType = graph.nodes.filter { $0.type == type }
            if !nodesOfType.isEmpty {
                output += "  classDef \(type.rawValue) fill:\(colorForNodeType(type))\n"
                let nodeNames = nodesOfType.map { $0.name }.joined(separator: ",")
                output += "  class \(nodeNames) \(type.rawValue)\n"
            }
        }

        return output
    }

    private func arrowType(for type: DependencyType) -> String {
        switch type {
        case .direct:
            return "-->"
        case .indirect:
            return "-..->"
        case .weak:
            return "-.->"
        case .runtime:
            return "==>"
        case .build:
            return "-.->"
        default:
            return "-->"
        }
    }

    private func colorForNodeType(_ type: DependencyNode.NodeType) -> String {
        switch type {
        case .package: return "#lightblue"
        case .target: return "#lightgreen"
        case .module: return "#lightyellow"
        case .framework: return "#lightcoral"
        case .library: return "#lightgray"
        default: return "#white"
        }
    }
}

// MARK: - Helper Types

/// Simple semantic version implementation
public struct SemanticVersion: Codable, Equatable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?
    public let build: String?

    public init(_ major: Int, _ minor: Int, _ patch: Int, prerelease: String? = nil, build: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.build = build
    }

    public init?(_ string: String) {
        let pattern = #"^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z-]+))?(?:\+([0-9A-Za-z-]+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, options: [], range: NSRange(string.startIndex..., in: string)) else {
            return nil
        }

        guard let majorRange = Range(match.range(at: 1), in: string),
              let minorRange = Range(match.range(at: 2), in: string),
              let patchRange = Range(match.range(at: 3), in: string) else {
            return nil
        }

        guard let major = Int(string[majorRange]),
              let minor = Int(string[minorRange]),
              let patch = Int(string[patchRange]) else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch

        if let prereleaseRange = Range(match.range(at: 4), in: string) {
            self.prerelease = String(string[prereleaseRange])
        } else {
            self.prerelease = nil
        }

        if let buildRange = Range(match.range(at: 5), in: string) {
            self.build = String(string[buildRange])
        } else {
            self.build = nil
        }
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }

        // Prerelease comparison: versions without prerelease are greater than those with
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, _):
            return false
        case (_, nil):
            return true
        case (let l?, let r?):
            return l < r
        }
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.prerelease == rhs.prerelease
    }
}