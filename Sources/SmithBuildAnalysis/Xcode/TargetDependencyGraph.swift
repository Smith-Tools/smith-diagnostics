import Foundation

/// Represents an Xcode build target
public struct XcodeTarget: Codable {
    public let name: String
    public let type: TargetType
    public let dependencies: [String]
    public let linkedFrameworks: [String]
    public let id: String

    public init(name: String, type: TargetType, dependencies: [String] = [], linkedFrameworks: [String] = [], id: String) {
        self.name = name
        self.type = type
        self.dependencies = dependencies
        self.linkedFrameworks = linkedFrameworks
        self.id = id
    }
}

/// Represents a dependency between Xcode targets
public struct XcodeTargetDependency: Codable {
    public let from: String
    public let to: String
    public let type: DependencyType

    public init(from: String, to: String, type: DependencyType) {
        self.from = from
        self.to = to
        self.type = type
    }
}

/// Type of Xcode target
///
/// Represents different kinds of targets that can exist in an Xcode project.
/// Each type has different characteristics and implications for architecture:
/// - **Application**: The main app, typically links all frameworks
/// - **Framework**: Reusable library, should not depend on app
/// - **Library**: Static or dynamic library
/// - **Test**: Unit, UI, or integration test bundle
/// - **Bundle**: Plugin or extension bundle
/// - **Tool**: Command-line executable
public enum TargetType: String, Codable {
    case application = "Application"
    case framework = "Framework"
    case library = "Library"
    case test = "Test"
    case bundle = "Bundle"
    case tool = "Tool"
    case unknown = "Unknown"

    public var displayName: String {
        switch self {
        case .application: return "Application"
        case .framework: return "Framework"
        case .library: return "Library"
        case .test: return "Test Bundle"
        case .bundle: return "Bundle"
        case .tool: return "Command-line Tool"
        case .unknown: return "Unknown"
        }
    }
}

/// Graph structure for Xcode target dependencies
///
/// TargetDependencyGraph builds and maintains a directed graph of target relationships.
/// It automatically detects circular dependencies during initialization using Depth-First
/// Search (DFS) to identify cycles.
///
/// ## Graph Structure
/// - **Vertices**: Targets (uniquely identified by ID)
/// - **Edges**: Dependencies (directed from dependent to dependency)
/// - **Properties**: Cyclic (targets can form cycles, unlike package dependencies)
///
/// ## Circular Dependency Detection Algorithm
/// Uses depth-first search (DFS) with recursion stack to detect cycles:
/// 1. Maintain three sets: `visited`, `recursionStack`, and current `path`
/// 2. For each unvisited node, perform DFS
/// 3. When visiting a node, add to visited and recursion stack
/// 4. If we encounter a node in the recursion stack, we've found a cycle
/// 5. Extract cycle from current path
///
/// ## Algorithm Complexity
/// - **Time**: O(V + E) where V = targets, E = dependencies
/// - **Space**: O(V + E) for graph storage + O(V) for recursion stack
/// - **Cycle Detection**: O(V + E) single pass using DFS
///
/// ## Usage Example
/// ```swift
/// let graph = TargetDependencyGraph(targets: allTargets, dependencies: allDeps)
///
/// // Check for cycles
/// if !graph.circularDependencies.isEmpty {
///     for cycle in graph.circularDependencies {
///         print("⚠️ Circular: \(cycle.joined(separator: " → "))")
///     }
/// }
///
/// // Traverse graph
/// let deps = graph.getDependencies(for: "target-id")
/// let dependents = graph.getDependents(for: "target-id")
///
/// // Analyze depth
/// let depth = graph.calculateDepth(for: "target-id")
/// ```
///
/// ## Architectural Implications
/// Circular dependencies between targets are problematic because they:
/// - Make testing harder (can't test in isolation)
/// - Prevent modular architecture
/// - Cause unexpected transitive dependencies
/// - Make code reuse more difficult
public struct TargetDependencyGraph: Codable {
    public let targets: [XcodeTarget]
    public let dependencies: [XcodeTargetDependency]
    public let circularDependencies: [[String]]

    public init(targets: [XcodeTarget], dependencies: [XcodeTargetDependency]) {
        self.targets = targets
        self.dependencies = dependencies
        // Calculate circular dependencies after all properties are initialized
        var visited = Set<String>()
        var recursionStack = Set<String>()
        var cycles: [[String]] = []
        var path: [String] = []

        func dfs(targetId: String) {
            visited.insert(targetId)
            recursionStack.insert(targetId)
            path.append(targetId)

            let outgoing = dependencies.filter { $0.from == targetId }
            for dep in outgoing {
                if !visited.contains(dep.to) {
                    dfs(targetId: dep.to)
                } else if recursionStack.contains(dep.to) {
                    if let cycleStart = path.firstIndex(of: dep.to) {
                        let cycle = Array(path[cycleStart...]) + [dep.to]
                        cycles.append(cycle)
                    }
                }
            }

            recursionStack.remove(targetId)
            path.removeLast()
        }

        for target in targets {
            if !visited.contains(target.id) {
                dfs(targetId: target.id)
            }
        }

        self.circularDependencies = cycles
    }

    /// Find all circular dependencies in the target graph
    /// - Returns: Array of circular dependency chains
    private func findCircularDependencies() -> [[String]] {
        var visited = Set<String>()
        var recursionStack = Set<String>()
        var cycles: [[String]] = []
        var path: [String] = []

        func dfs(targetId: String) {
            visited.insert(targetId)
            recursionStack.insert(targetId)
            path.append(targetId)

            // Find direct dependencies
            let outgoing = dependencies.filter { $0.from == targetId }

            for dep in outgoing {
                if !visited.contains(dep.to) {
                    dfs(targetId: dep.to)
                } else if recursionStack.contains(dep.to) {
                    // Found a cycle
                    if let cycleStart = path.firstIndex(of: dep.to) {
                        let cycle = Array(path[cycleStart...]) + [dep.to]
                        cycles.append(cycle)
                    }
                }
            }

            recursionStack.remove(targetId)
            path.removeLast()
        }

        for target in targets {
            if !visited.contains(target.id) {
                dfs(targetId: target.id)
            }
        }

        return cycles
    }

    /// Get dependencies for a specific target
    /// - Parameter targetId: ID of the target
    /// - Returns: Array of target IDs that this target depends on
    public func getDependencies(for targetId: String) -> [String] {
        return dependencies.filter { $0.from == targetId }.map { $0.to }
    }

    /// Get dependents of a specific target
    /// - Parameter targetId: ID of the target
    /// - Returns: Array of target IDs that depend on this target
    public func getDependents(for targetId: String) -> [String] {
        return dependencies.filter { $0.to == targetId }.map { $0.from }
    }

    /// Get targets by type
    /// - Parameter type: Type of targets to filter
    /// - Returns: Array of targets of the specified type
    public func getTargets(ofType type: TargetType) -> [XcodeTarget] {
        return targets.filter { $0.type == type }
    }

    /// Calculate depth of a target in the dependency tree
    /// - Parameter targetId: ID of the target
    /// - Returns: Depth (0 for root targets)
    public func calculateDepth(for targetId: String) -> Int {
        var visited = Set<String>()
        var maxDepth = 0

        func dfs(currentId: String, depth: Int) {
            visited.insert(currentId)
            maxDepth = max(maxDepth, depth)

            let dependencies = getDependencies(for: currentId)
            for depId in dependencies {
                if !visited.contains(depId) {
                    dfs(currentId: depId, depth: depth + 1)
                }
            }
        }

        dfs(currentId: targetId, depth: 0)
        return maxDepth
    }

    /// Get root targets (targets with no dependencies)
    /// - Returns: Array of root target IDs
    public func getRootTargets() -> [String] {
        return targets.filter { target in
            !dependencies.contains { $0.from == target.id }
        }.map { $0.id }
    }

    /// Get leaf targets (targets not depended upon by others)
    /// - Returns: Array of leaf target IDs
    public func getLeafTargets() -> [String] {
        return targets.filter { target in
            !dependencies.contains { $0.to == target.id }
        }.map { $0.id }
    }
}
