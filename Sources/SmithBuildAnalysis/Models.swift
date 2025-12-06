import Foundation

// MARK: - Project Types

public enum ProjectType: Codable, Equatable {
    case spm
    case xcodeWorkspace(workspace: String)
    case xcodeProject(project: String)
    case unknown
}

// MARK: - Build Status

public enum BuildStatus: String, Codable {
    case success = "success"
    case failed = "failed"
    case hung = "hung"
    case partial = "partial"
    case timeout = "timeout"
    case unknown = "unknown"
}

// MARK: - Complexity Level

public enum ComplexityLevel: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case extreme = "extreme"
}

// MARK: - Build Phase

public struct BuildPhase: Codable {
    public let name: String
    public let status: BuildStatus
    public let duration: TimeInterval?
    public let startTime: Date?
    public let endTime: Date?

    public init(name: String, status: BuildStatus, duration: TimeInterval? = nil, startTime: Date? = nil, endTime: Date? = nil) {
        self.name = name
        self.status = status
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
    }
}

// MARK: - Dependency Graph

public struct BuildDependencySummary: Codable {
    public let targetCount: Int
    public let maxDepth: Int
    public let circularDeps: Bool
    public let bottleneckTargets: [String]
    public let complexity: ComplexityLevel

    public init(targetCount: Int, maxDepth: Int, circularDeps: Bool, bottleneckTargets: [String] = [], complexity: ComplexityLevel) {
        self.targetCount = targetCount
        self.maxDepth = maxDepth
        self.circularDeps = circularDeps
        self.bottleneckTargets = bottleneckTargets
        self.complexity = complexity
    }

    public static func calculateComplexity(targetCount: Int, maxDepth: Int) -> ComplexityLevel {
        if targetCount > 100 || maxDepth > 8 {
            return .extreme
        } else if targetCount > 50 || maxDepth > 6 {
            return .high
        } else if targetCount > 20 || maxDepth > 4 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Build Metrics

public struct BuildMetrics: Codable {
    public let totalDuration: TimeInterval?
    public let compilationDuration: TimeInterval?
    public let linkingDuration: TimeInterval?
    public let dependencyResolutionDuration: TimeInterval?
    public let memoryUsage: Int64?
    public let fileCount: Int?

    public init(totalDuration: TimeInterval? = nil, compilationDuration: TimeInterval? = nil, linkingDuration: TimeInterval? = nil, dependencyResolutionDuration: TimeInterval? = nil, memoryUsage: Int64? = nil, fileCount: Int? = nil) {
        self.totalDuration = totalDuration
        self.compilationDuration = compilationDuration
        self.linkingDuration = linkingDuration
        self.dependencyResolutionDuration = dependencyResolutionDuration
        self.memoryUsage = memoryUsage
        self.fileCount = fileCount
    }
}

// MARK: - Macro Diagnostics

public struct MacroDiagnostic: Codable {
    public let issues: [MacroIssue]
    public let detectedFramework: MacroFramework
    public let recommendation: String

    public init(issues: [MacroIssue], detectedFramework: MacroFramework, recommendation: String) {
        self.issues = issues
        self.detectedFramework = detectedFramework
        self.recommendation = recommendation
    }
}

public enum MacroIssue: String, Codable {
    case executionPolicyException = "RegisterExecutionPolicyException during compilation"
    case macroValidationFailure = "Build fails without -skipMacroValidation but succeeds with it"
    case externalMacroNotFound = "External macro implementation could not be found"
    case macroExpansionTimeout = "Macro expansion timeout during compilation"
    case swift6EquatableBug = "Swift 6 Equatable conformance issue with synthesized State"

    public var severity: String {
        switch self {
        case .executionPolicyException:
            return "critical"
        case .macroValidationFailure:
            return "high"
        case .externalMacroNotFound:
            return "high"
        case .macroExpansionTimeout:
            return "medium"
        case .swift6EquatableBug:
            return "medium"
        }
    }

    public var fix: String {
        switch self {
        case .executionPolicyException:
            return "Try building with -skipMacroValidation flag"
        case .macroValidationFailure:
            return "Use -skipMacroValidation or fix macro conformance issues"
        case .externalMacroNotFound:
            return "Check build configuration and macro target dependencies"
        case .macroExpansionTimeout:
            return "Increase build timeout or simplify macro usage"
        case .swift6EquatableBug:
            return "Add explicit conformance: @Reducer(state: .equatable, .sendable)"
        }
    }
}

public enum MacroFramework: String, Codable {
    case tca = "Swift Composable Architecture (@Reducer)"
    case swiftData = "SwiftData (@Model, @ObservableModel)"
    case dependencies = "Swift Dependencies (@DependencyClient)"
    case perception = "Swift Perception (@Perception, @PerceptionMacros)"
    case customMacros = "Custom Swift Macros"
    case unknown = "Unknown Macro Framework"
}

// MARK: - Diagnostic

public struct Diagnostic: Codable {
    public let severity: Severity
    public let category: Category
    public let message: String
    public let location: String?
    public let suggestion: String?

    public enum Severity: String, Codable {
        case info = "info"
        case warning = "warning"
        case error = "error"
        case critical = "critical"
    }

    public enum Category: String, Codable {
        case dependency = "dependency"
        case compilation = "compilation"
        case performance = "performance"
        case configuration = "configuration"
        case environment = "environment"
    }

    public init(severity: Severity, category: Category, message: String, location: String? = nil, suggestion: String? = nil) {
        self.severity = severity
        self.category = category
        self.message = message
        self.location = location
        self.suggestion = suggestion
    }
}

// MARK: - Build Analysis

public struct BuildAnalysis: Codable {
    public let projectType: ProjectType
    public let status: BuildStatus
    public let phases: [BuildPhase]
    public let dependencyGraph: BuildDependencySummary
    public let metrics: BuildMetrics
    public let diagnostics: [Diagnostic]
    public let timestamp: Date

    public init(projectType: ProjectType, status: BuildStatus, phases: [BuildPhase] = [], dependencyGraph: BuildDependencySummary, metrics: BuildMetrics = BuildMetrics(), diagnostics: [Diagnostic] = []) {
        self.projectType = projectType
        self.status = status
        self.phases = phases
        self.dependencyGraph = dependencyGraph
        self.metrics = metrics
        self.diagnostics = diagnostics
        self.timestamp = Date()
    }
}

// MARK: - Build Result

public struct BuildResult: Codable {
    public let analysis: BuildAnalysis
    public let rawOutput: String?
    public let warnings: [String]
    public let errors: [String]
    public let summary: String

    public init(analysis: BuildAnalysis, rawOutput: String? = nil, warnings: [String] = [], errors: [String] = [], summary: String) {
        self.analysis = analysis
        self.rawOutput = rawOutput
        self.warnings = warnings
        self.errors = errors
        self.summary = summary
    }
}

// MARK: - Hang Detection

public struct HangDetection: Codable {
    public let isHanging: Bool
    public let suspectedPhase: String?
    public let suspectedFile: String?
    public let timeElapsed: TimeInterval
    public let lastOutput: String?
    public let recommendations: [String]

    public init(isHanging: Bool, suspectedPhase: String? = nil, suspectedFile: String? = nil, timeElapsed: TimeInterval, lastOutput: String? = nil, recommendations: [String] = []) {
        self.isHanging = isHanging
        self.suspectedPhase = suspectedPhase
        self.suspectedFile = suspectedFile
        self.timeElapsed = timeElapsed
        self.lastOutput = lastOutput
        self.recommendations = recommendations
    }
}

// MARK: - Resource Monitoring

public struct ResourceUsage: Codable {
    public let cpuUsage: Double
    public let memoryUsage: Int64
    public let timestamp: Date

    public init(cpuUsage: Double, memoryUsage: Int64, timestamp: Date = Date()) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.timestamp = timestamp
    }
}

// MARK: - Build System Information

public struct BuildSystemInfo: Codable {
    public let type: ProjectType
    public let projectPath: String
    public let scheme: String?

    public init(type: ProjectType, projectPath: String, scheme: String? = nil) {
        self.type = type
        self.projectPath = projectPath
        self.scheme = scheme
    }
}

// MARK: - Hang Analysis (Alias for HangDetection)

public typealias HangAnalysis = HangDetection

// MARK: - Build Timing Data

public struct BuildTimingData: Codable {
    public let totalDuration: TimeInterval
    public let targetTimings: [String: TimeInterval]
    public let phaseTimings: [String: TimeInterval]
    public let rawOutput: String

    public init(totalDuration: TimeInterval, targetTimings: [String: TimeInterval], phaseTimings: [String: TimeInterval], rawOutput: String) {
        self.totalDuration = totalDuration
        self.targetTimings = targetTimings
        self.phaseTimings = phaseTimings
        self.rawOutput = rawOutput
    }
}

// MARK: - Target Analysis

public struct TargetAnalysis: Codable {
    public let totalFileCount: Int
    public let totalMemoryUsage: Int64
    public let slowTargets: [String]
    public let parallelTargets: [String]

    public init(totalFileCount: Int, totalMemoryUsage: Int64, slowTargets: [String], parallelTargets: [String]) {
        self.totalFileCount = totalFileCount
        self.totalMemoryUsage = totalMemoryUsage
        self.slowTargets = slowTargets
        self.parallelTargets = parallelTargets
    }
}

// MARK: - Optimization Types

public struct OptimizationRecommendations: Codable {
    public let projectPath: String
    public let scheme: String
    public let buildAnalysis: BuildAnalysis
    public let recommendations: [OptimizationRecommendation]
    public let estimatedImprovement: Double
}

public struct OptimizationRecommendation: Codable {
    public let title: String
    public let description: String
    public let impact: OptimizationImpact
    public let difficulty: OptimizationDifficulty
    public let category: OptimizationCategory
    public let isSafeToApply: Bool
    public let implementation: String
    public let estimatedSpeedup: Double

    public enum OptimizationImpact: Int, Codable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
    }

    public enum OptimizationDifficulty: Int, Codable {
        case low = 1
        case medium = 2
        case high = 3
    }

    public enum OptimizationCategory: String, Codable {
        case compiler = "compiler"
        case parallelBuilds = "parallel_builds"
        case memory = "memory"
        case dependency = "dependency"
        case targetStructure = "target_structure"
        case buildSystem = "build_system"
    }
}

public struct ResourceProfile: Codable {
    public let peakMemoryUsage: Int64
    public let averageMemoryUsage: Int64
    public let peakCPUUsage: Double
    public let averageCPUUsage: Double
    public let diskIOBytes: Int64
    public let buildDuration: TimeInterval

    public init(peakMemoryUsage: Int64, averageMemoryUsage: Int64, peakCPUUsage: Double, averageCPUUsage: Double, diskIOBytes: Int64, buildDuration: TimeInterval) {
        self.peakMemoryUsage = peakMemoryUsage
        self.averageMemoryUsage = averageMemoryUsage
        self.peakCPUUsage = peakCPUUsage
        self.averageCPUUsage = averageCPUUsage
        self.diskIOBytes = diskIOBytes
        self.buildDuration = buildDuration
    }
}

public struct TimingBreakdown: Codable {
    public let totalDuration: TimeInterval
    public let phases: [PhaseTiming]

    public init(totalDuration: TimeInterval, phases: [PhaseTiming]) {
        self.totalDuration = totalDuration
        self.phases = phases
    }
}

public struct PhaseTiming: Codable {
    public let name: String
    public let duration: TimeInterval
    public let percentage: Double

    public init(name: String, duration: TimeInterval, percentage: Double) {
        self.name = name
        self.duration = duration
        self.percentage = percentage
    }
}

public struct BuildProfile: Codable {
    public let projectPath: String
    public let scheme: String
    public let timestamp: Date
    public let totalDuration: TimeInterval
    public let targetAnalysis: TargetAnalysis
    public let resourceProfile: ResourceProfile?
    public let timingBreakdown: TimingBreakdown?
    public let rawMetrics: BuildProcessMetrics

    public init(projectPath: String, scheme: String, timestamp: Date, totalDuration: TimeInterval, targetAnalysis: TargetAnalysis, resourceProfile: ResourceProfile?, timingBreakdown: TimingBreakdown?, rawMetrics: BuildProcessMetrics) {
        self.projectPath = projectPath
        self.scheme = scheme
        self.timestamp = timestamp
        self.totalDuration = totalDuration
        self.targetAnalysis = targetAnalysis
        self.resourceProfile = resourceProfile
        self.timingBreakdown = timingBreakdown
        self.rawMetrics = rawMetrics
    }
}

public struct BuildProcessMetrics: Codable {
    public let peakMemoryUsage: Int64
    public let averageMemoryUsage: Int64
    public let peakCPUUsage: Double
    public let averageCPUUsage: Double
    public let diskIOBytes: Int64
    public let buildDuration: TimeInterval

    public init(peakMemoryUsage: Int64, averageMemoryUsage: Int64, peakCPUUsage: Double, averageCPUUsage: Double, diskIOBytes: Int64, buildDuration: TimeInterval) {
        self.peakMemoryUsage = peakMemoryUsage
        self.averageMemoryUsage = averageMemoryUsage
        self.peakCPUUsage = peakCPUUsage
        self.averageCPUUsage = averageCPUUsage
        self.diskIOBytes = diskIOBytes
        self.buildDuration = buildDuration
    }
}