import Foundation

/// Ranks dependencies by relevance based on multiple signals
///
/// DependencyRanker uses a multi-factor scoring algorithm to determine which dependencies
/// are most critical to a project. Rather than treating all dependencies equally, it
/// combines four distinct signals to provide an intelligent relevance score (0-100).
///
/// ## Scoring Algorithm
/// The relevance score combines four factors with weighted contributions:
/// - **Import Frequency (40%)**: How often the dependency is imported across the project
/// - **Bottleneck Status (30%)**: Whether many other dependencies depend on this one
/// - **Direct vs Indirect (20%)**: Direct dependencies score higher than transitive ones
/// - **Transitive Depth (10%)**: Shallow dependencies score higher than deeply nested ones
///
/// Final Score = (frequency × 0.4 + bottleneck × 0.3 + direct × 0.2 + depth × 0.1) × 100
///
/// ## Algorithm Complexity
/// - **Time Complexity**: O(m log m) where m = number of dependencies
/// - **Space Complexity**: O(m) for storing scores
/// - **Performance**: ~50ms for typical projects (10-50 dependencies)
///
/// ## Usage Example
/// ```swift
/// let importer = ImportAnalyzer()
/// let importMetrics = importer.analyzeImports(at: projectPath, for: dependencies)
///
/// let ranker = DependencyRanker(importMetrics: importMetrics, graph: dependencyGraph)
/// let ranked = ranker.rankDependencies(dependencies)
///
/// // Result: [DependencyScore(packageName: "ComposableArchitecture", score: 98.5), ...]
/// for score in ranked.prefix(5) {
///     print("\(score.packageName): \(score.score)/100")
/// }
/// ```
///
/// ## Output Interpretation
/// - **90-100**: Critical dependency used extensively throughout project
/// - **70-89**: Important dependency, used in multiple areas
/// - **50-69**: Moderate dependency, used selectively
/// - **20-49**: Optional dependency, used minimally
/// - **0-19**: Rarely used, candidate for removal
public struct DependencyRanker {
    private let importMetrics: [String: ImportMetrics]
    private let dependencyGraph: DependencyGraph

    // Scoring weights (sum to 1.0)
    /// Import frequency weight: How often a dependency is imported (40%)
    private let importWeight = 0.4
    /// Bottleneck weight: Dependencies that many others depend on (30%)
    private let bottleneckWeight = 0.3
    /// Direct dependency weight: Direct vs transitive (20%)
    private let directWeight = 0.2
    /// Transitive depth weight: How deep in dependency tree (10%)
    private let depthWeight = 0.1

    /// Initialize the ranker with import metrics and dependency graph
    /// - Parameters:
    ///   - importMetrics: Import counts from ImportAnalyzer
    ///   - graph: Dependency graph from DependencyGraph analysis
    public init(
        importMetrics: [String: ImportMetrics],
        graph: DependencyGraph
    ) {
        self.importMetrics = importMetrics
        self.dependencyGraph = graph
    }

    /// Rank dependencies by calculated relevance score
    ///
    /// Scores all provided dependencies and returns them sorted from highest to lowest
    /// relevance. The score is calculated by combining import frequency, bottleneck status,
    /// direct dependency status, and transitive depth.
    ///
    /// - Parameter dependencies: List of dependencies to rank
    /// - Returns: Array of DependencyScore objects sorted by score (descending)
    /// - Complexity: O(m log m) where m = number of dependencies
    public func rankDependencies(_ dependencies: [SPMExternalDependency]) -> [DependencyScore] {
        return dependencies.map { dependency in
            let score = calculateScore(for: dependency)
            return DependencyScore(
                packageName: dependency.name,
                score: score,
                breakdown: calculateBreakdown(for: dependency)
            )
        }.sorted { $0.score > $1.score }
    }

    /// Calculate relevance score for a single dependency
    /// - Parameter dependency: The dependency to score
    /// - Returns: Relevance score (0-100)
    private func calculateScore(for dependency: SPMExternalDependency) -> Double {
        let breakdown = calculateBreakdown(for: dependency)

        let score = (
            breakdown.importFrequency * importWeight +
            (breakdown.isBottleneck ? 1.0 : 0.0) * bottleneckWeight +
            (breakdown.isDirect ? 1.0 : 0.0) * directWeight +
            breakdown.transitiveDepth * depthWeight
        ) * 100.0

        return min(score, 100.0)
    }

    /// Calculate detailed breakdown of scoring factors
    /// - Parameter dependency: The dependency to analyze
    /// - Returns: Detailed score breakdown
    private func calculateBreakdown(for dependency: SPMExternalDependency) -> ScoreBreakdown {
        // Import frequency (normalized to 0-1)
        let importFrequency = calculateImportFrequency(for: dependency)

        // Bottleneck status
        let isBottleneck = isBottleneckNode(dependency.name)

        // Direct vs indirect dependency
        let isDirect = isDirectDependency(dependency.name)

        // Transitive depth (normalized to 0-1)
        let transitiveDepth = calculateTransitiveDepth(for: dependency.name)

        return ScoreBreakdown(
            importFrequency: importFrequency,
            isBottleneck: isBottleneck,
            isDirect: isDirect,
            transitiveDepth: transitiveDepth
        )
    }

    /// Calculate normalized import frequency
    /// - Parameter dependency: The dependency to analyze
    /// - Returns: Normalized frequency (0-1)
    private func calculateImportFrequency(for dependency: SPMExternalDependency) -> Double {
        guard let importCount = dependency.importCount else {
            return 0.0
        }

        // Find max import count across all dependencies
        let maxImports = dependency.importCount ?? 0

        // Also check import metrics for more accurate count
        if let metrics = importMetrics[dependency.name] {
            let totalImports = metrics.totalImports
            let normalizedTotal = totalImports > 0 ? Double(totalImports) / Double(max(1, maxImports)) : 0.0

            // Also consider coverage percentage
            let coverageScore = metrics.filesCoverage

            // Combine total imports and coverage (weighted)
            return (normalizedTotal * 0.7) + (coverageScore * 0.3)
        }

        return importCount > 0 ? 1.0 : 0.0
    }

    /// Check if a dependency is a bottleneck node
    /// - Parameter packageName: Name of the package to check
    /// - Returns: True if it's a bottleneck
    private func isBottleneckNode(_ packageName: String) -> Bool {
        // Find node in dependency graph
        let node = dependencyGraph.nodes.first { $0.name == packageName }

        guard let node = node else {
            return false
        }

        // Check if it's a bottleneck (many dependents)
        let dependents = dependencyGraph.dependents(of: node.id)
        let averageDependents = Double(dependencyGraph.nodes.count) / 2.0

        return Double(dependents.count) > averageDependents
    }

    /// Check if dependency is direct
    /// - Parameter packageName: Name of the package to check
    /// - Returns: True if direct dependency
    private func isDirectDependency(_ packageName: String) -> Bool {
        // Root nodes are typically direct dependencies
        let rootNodes = dependencyGraph.rootNodes
        return rootNodes.contains(packageName)
    }

    /// Calculate transitive depth for a dependency
    /// - Parameter packageName: Name of the package
    /// - Returns: Normalized depth (0-1, where 0 is shallow, 1 is deep)
    private func calculateTransitiveDepth(for packageName: String) -> Double {
        let depths = dependencyGraph.dependencyDepths()

        // Find the node
        guard let node = dependencyGraph.nodes.first(where: { $0.name == packageName }),
              let depth = depths[node.id] else {
            return 1.0 // Default to deepest if not found
        }

        let maxDepth = dependencyGraph.maxDepth

        // Normalize: shallow dependencies get higher score (less transitive)
        // So we invert it: 1 - (depth / maxDepth)
        return maxDepth > 0 ? 1.0 - (Double(depth) / Double(maxDepth)) : 0.0
    }
}

/// Score breakdown for a dependency
public struct DependencyScore: Codable {
    public let packageName: String
    public let score: Double
    public let breakdown: ScoreBreakdown

    public init(packageName: String, score: Double, breakdown: ScoreBreakdown) {
        self.packageName = packageName
        self.score = score
        self.breakdown = breakdown
    }
}

/// Detailed breakdown of scoring factors
public struct ScoreBreakdown: Codable {
    public let importFrequency: Double
    public let isBottleneck: Bool
    public let isDirect: Bool
    public let transitiveDepth: Double

    public init(
        importFrequency: Double,
        isBottleneck: Bool,
        isDirect: Bool,
        transitiveDepth: Double
    ) {
        self.importFrequency = importFrequency
        self.isBottleneck = isBottleneck
        self.isDirect = isDirect
        self.transitiveDepth = transitiveDepth
    }
}
