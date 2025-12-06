import Foundation

/// HangDetector provides intelligent build hang detection and root cause analysis
public class HangDetector: @unchecked Sendable {

    // MARK: - Configuration

    public struct HangDetectionConfig {
        public static let defaultTimeout: TimeInterval = 300 // 5 minutes
        public static let outputCheckInterval: TimeInterval = 30 // 30 seconds
        public static let processCheckInterval: TimeInterval = 60 // 1 minute
        public static let memoryThreshold: Double = 0.9 // 90% memory usage
        public static let diskSpaceThreshold: Int64 = 1_000_000_000 // 1GB free
    }

    // MARK: - Properties

    private var lastOutputTime: Date = Date()
    private var lastOutputLength: Int = 0
    private var buildStartTime: Date = Date()
    private var isMonitoring: Bool = false
    private var currentBuildPhase: String?
    private var activeTarget: String?
    private let timeout: TimeInterval

    // MARK: - Initializer

    /// Initialize with custom timeout
    public init(timeout: TimeInterval = HangDetectionConfig.defaultTimeout) {
        self.timeout = timeout
        self.buildStartTime = Date()
        self.lastOutputTime = Date()
    }

    // MARK: - Public Interface

    /// Start monitoring a build for potential hangs
    public func startMonitoring() {
        buildStartTime = Date()
        lastOutputTime = Date()
        isMonitoring = true

        print("🔍 Starting hang detection monitoring...")
        print("   Timeout: \(Int(timeout))s")
        print("   Check interval: \(Int(HangDetectionConfig.outputCheckInterval))s")
    }

    /// Process build output and check for hang indicators
    public func processOutput(_ output: String) -> HangDetection {
        guard isMonitoring else {
            return HangDetection(
                isHanging: false,
                suspectedPhase: nil,
                suspectedFile: nil,
                timeElapsed: Date().timeIntervalSince(buildStartTime),
                lastOutput: output,
                recommendations: []
            )
        }

        // Update tracking
        let currentTime = Date()
        let currentOutputLength = output.count

        // Check if we received new output
        if currentOutputLength > lastOutputLength {
            lastOutputTime = currentTime
            lastOutputLength = currentOutputLength

            // Parse current build state
            parseBuildState(from: output)
        }

        // Perform hang analysis
        let timeSinceLastOutput = currentTime.timeIntervalSince(lastOutputTime)
        let totalElapsed = currentTime.timeIntervalSince(buildStartTime)

        let hangIndicators = analyzeHangIndicators(
            timeSinceLastOutput: timeSinceLastOutput,
            totalElapsed: totalElapsed,
            output: output
        )

        return generateHangAnalysis(
            indicators: hangIndicators,
            timeSinceLastOutput: timeSinceLastOutput,
            totalElapsed: totalElapsed,
            output: output
        )
    }

    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
    }

    /// Generate recovery recommendations for hang indicators (public method)
    public func generateRecoveryRecommendations(indicators: [HangIndicator]) -> [String] {
        var recommendations: [String] = []

        for indicator in indicators {
            switch indicator {
            case .outputStagnation(let duration):
                recommendations.append("Build inactive for \(Int(duration))s - Consider killing process")
                recommendations.append("Command: killall xcodebuild && killall swiftc")

            case .excessiveDuration(let duration):
                recommendations.append("Build running for \(Int(duration/60)) minutes - May be stuck")
                recommendations.append("Check system resources: top | grep xcodebuild")

            case .packageResolution:
                recommendations.append("Package resolution hang detected")
                recommendations.append("Try: swift package reset")
                recommendations.append("Or: rm -rf .build && swift package resolve")

            case .indexingHang:
                recommendations.append("Source indexing hang detected")
                recommendations.append("Try: rm -rf ~/Library/Developer/Xcode/DerivedData")
                recommendations.append("Disable indexing temporarily in Xcode preferences")

            case .circularDependency:
                recommendations.append("Circular dependency detected")
                recommendations.append("Check: xcodebuild -list --json")
                recommendations.append("Review target dependencies in Xcode project")

            case .memoryPressure:
                recommendations.append("Memory pressure detected")
                recommendations.append("Reduce parallel jobs or free up memory")
                recommendations.append("Command: purge to clear disk cache")

            case .diskSpace:
                recommendations.append("Low disk space detected")
                recommendations.append("Clean up DerivedData or expand storage")
                recommendations.append("Command: rm -rf ~/Library/Developer/Xcode/DerivedData")

            case .systemMemoryPressure(let usage):
                recommendations.append("System memory pressure: \(Int(usage * 100))%")
                recommendations.append("Close other applications or restart build")

            case .diskSpacePressure(let freeSpace):
                recommendations.append("Disk space pressure: \(formatBytes(freeSpace)) free")
                recommendations.append("Clean up disk space and retry")

            case .stuckProcesses(let processes):
                recommendations.append("Stuck processes detected: \(processes.joined(separator: ", "))")
                recommendations.append("Kill stuck processes: pkill -f xcodebuild")
            }
        }

        // Add general recovery recommendations
        if recommendations.isEmpty {
            recommendations.append("No specific hang pattern detected")
            recommendations.append("Try basic recovery: xcodebuild clean build")
        }

        // Always add the escape hatch
        recommendations.append("EMERGENCY: Ctrl+C to stop build")
        recommendations.append("RECOVERY: Use appropriate tool to rebuild with clean state")

        return Array(Set(recommendations)) // Remove duplicates
    }

    // MARK: - Private Methods

    private func parseBuildState(from output: String) {
        let lines = output.components(separatedBy: .newlines)

        for line in lines.suffix(10) { // Check last 10 lines
            // Detect current build phase
            if line.contains("Build phase") {
                currentBuildPhase = extractPhase(from: line)
            }

            // Detect active target
            if line.contains("Build target") {
                activeTarget = extractTarget(from: line)
            }

            // Detect compilation activity
            if line.contains("Compiling") || line.contains("swiftc") {
                lastOutputTime = Date() // Reset timer on compilation activity
            }
        }
    }

    private func extractPhase(from line: String) -> String {
        if line.contains("CompileSwift") {
            return "Swift Compilation"
        } else if line.contains("PhaseScriptExecution") {
            return "Run Script"
        } else if line.contains("Ld") {
            return "Linking"
        } else if line.contains("Copy") {
            return "Copy Resources"
        } else {
            return "Unknown Phase"
        }
    }

    private func extractTarget(from line: String) -> String? {
        let pattern = #"Build target (.+) of project"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let targetRange = Range(match.range(at: 1), in: line)
        return targetRange.map(String.init)
    }

    private func analyzeHangIndicators(
        timeSinceLastOutput: TimeInterval,
        totalElapsed: TimeInterval,
        output: String
    ) -> [HangIndicator] {
        var indicators: [HangIndicator] = []

        // Check for output stagnation
        if timeSinceLastOutput > HangDetectionConfig.outputCheckInterval {
            indicators.append(.outputStagnation(duration: timeSinceLastOutput))
        }

        // Check for excessive total time
        if totalElapsed > timeout {
            indicators.append(.excessiveDuration(duration: totalElapsed))
        }

        // Check for common hang patterns
        if let hangPattern = detectHangPattern(in: output) {
            indicators.append(hangPattern)
        }

        // Check system resources
        indicators.append(contentsOf: checkSystemResources())

        return indicators
    }

    private func detectHangPattern(in output: String) -> HangIndicator? {
        let lines = output.components(separatedBy: .newlines).suffix(20)

        for line in lines {
            // Package resolution hang
            if line.contains("Resolving package dependencies") && output.count > 10000 {
                return .packageResolution
            }

            // Indexing hang
            if line.contains("Indexing") && output.count > 50000 {
                return .indexingHang
            }

            // Circular dependency
            if line.contains("circular") && line.contains("dependency") {
                return .circularDependency
            }

            // Memory pressure indicators
            if line.contains("out of memory") || line.contains("memory") && line.contains("error") {
                return .memoryPressure
            }

            // Disk space issues
            if line.contains("No space left") || line.contains("disk full") {
                return .diskSpace
            }
        }

        return nil
    }

    private func checkSystemResources() -> [HangIndicator] {
        var indicators: [HangIndicator] = []

        // Check memory pressure
        if let memoryUsage = getCurrentMemoryUsage(), memoryUsage > HangDetectionConfig.memoryThreshold {
            indicators.append(.systemMemoryPressure(usage: memoryUsage))
        }

        // Check disk space
        if let freeSpace = getFreeDiskSpace(), freeSpace < HangDetectionConfig.diskSpaceThreshold {
            indicators.append(.diskSpacePressure(freeSpace: freeSpace))
        }

        // Check for stuck processes
        if let stuckProcesses = getStuckProcesses(), !stuckProcesses.isEmpty {
            indicators.append(.stuckProcesses(processes: stuckProcesses))
        }

        return indicators
    }

    private func generateHangAnalysis(
        indicators: [HangIndicator],
        timeSinceLastOutput: TimeInterval,
        totalElapsed: TimeInterval,
        output: String
    ) -> HangDetection {
        let isHanging = !indicators.isEmpty || timeSinceLastOutput > timeout

        let suspectedPhase = determineSuspectedPhase(indicators: indicators)
        let suspectedFile = determineSuspectedFile(from: output)
        let recommendations = generateRecoveryRecommendations(indicators: indicators)

        return HangDetection(
            isHanging: isHanging,
            suspectedPhase: suspectedPhase,
            suspectedFile: suspectedFile,
            timeElapsed: totalElapsed,
            lastOutput: extractLastMeaningfulOutput(from: output),
            recommendations: recommendations
        )
    }

    private func determineSuspectedPhase(indicators: [HangIndicator]) -> String? {
        // Prioritize specific hang patterns over generic output stagnation
        for indicator in indicators {
            switch indicator {
            case .packageResolution:
                return "Package Resolution"
            case .indexingHang:
                return "Source Indexing"
            case .circularDependency:
                return "Dependency Resolution"
            case .memoryPressure:
                return currentBuildPhase ?? "Compilation"
            case .diskSpace:
                return "File I/O"
            case .stuckProcesses:
                return currentBuildPhase ?? "Build Process"
            case .outputStagnation, .excessiveDuration, .systemMemoryPressure, .diskSpacePressure:
                continue
            }
        }

        return currentBuildPhase
    }

    private func determineSuspectedFile(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines).suffix(50)

        for line in lines.reversed() {
            // Look for file compilation patterns
            if line.contains("Compiling") && line.contains(".swift") {
                return extractFilePath(from: line)
            }

            // Look for error messages with file locations
            if line.contains("error:") && line.contains(".swift:") {
                return extractFilePath(from: line)
            }
        }

        return nil
    }

    private func extractFilePath(from line: String) -> String? {
        let pattern = #"/[^:\s]+\.swift"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let range = Range(match.range, in: line)
        return range.map(String.init)
    }

    private func extractLastMeaningfulOutput(from output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        let meaningfulLines = lines.filter { line in
            !line.trimmingCharacters(in: .whitespaces).isEmpty &&
            !line.contains("note:") &&
            !line.contains("ld: warning:")
        }

        return meaningfulLines.suffix(5).joined(separator: "\n")
    }

  
    // MARK: - System Resource Checking

    private func getCurrentMemoryUsage() -> Double? {
        // Use vm_stat to get memory pressure
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        process.arguments = []

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return parseMemoryUsage(from: output)
            }
        } catch {
            // Fallback: return nil if can't get memory usage
        }

        return nil
    }

    private func parseMemoryUsage(from vmstat: String) -> Double? {
        // Simplified memory pressure calculation
        // In a real implementation, this would parse vm_stat output properly
        return Double.random(in: 0.3...0.8) // Placeholder
    }

    private func getFreeDiskSpace() -> Int64? {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
            return attributes[.systemFreeSize] as? Int64
        } catch {
            return nil
        }
    }

    private func getStuckProcesses() -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "pid,etime,comm"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return parseStuckProcesses(from: output)
            }
        } catch {
            return nil
        }

        return nil
    }

    private func parseStuckProcesses(from psOutput: String) -> [String]? {
        let lines = psOutput.components(separatedBy: .newlines)
        var stuckProcesses: [String] = []

        for line in lines {
            // Look for processes running for more than 30 minutes
            if (line.contains("30:") || line.contains("1:") || line.contains("2:")) &&
               (line.contains("xcodebuild") || line.contains("swiftc") || line.contains("clang")) {
                let components = line.components(separatedBy: .whitespaces)
                if let processName = components.last {
                    stuckProcesses.append(processName)
                }
            }
        }

        return stuckProcesses.isEmpty ? nil : stuckProcesses
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

/// Hang indicators for different types of build hangs
public enum HangIndicator {
    case outputStagnation(duration: TimeInterval)
    case excessiveDuration(duration: TimeInterval)
    case packageResolution
    case indexingHang
    case circularDependency
    case memoryPressure
    case diskSpace
    case systemMemoryPressure(usage: Double)
    case diskSpacePressure(freeSpace: Int64)
    case stuckProcesses(processes: [String])
}

/// Extension for convenient creation of HangDetection from monitoring
public extension HangDetection {
    /// Create a hang detection from real-time monitoring
    static func fromMonitoring(
        isHanging: Bool,
        timeElapsed: TimeInterval,
        currentPhase: String? = nil,
        activeTarget: String? = nil,
        lastOutput: String = "",
        indicators: [HangIndicator] = []
    ) -> HangDetection {
        let recommendations = HangDetector().generateRecoveryRecommendations(indicators: indicators)

        return HangDetection(
            isHanging: isHanging,
            suspectedPhase: currentPhase,
            suspectedFile: nil,
            timeElapsed: timeElapsed,
            lastOutput: lastOutput,
            recommendations: recommendations
        )
    }
}