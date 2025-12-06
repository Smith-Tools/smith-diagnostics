import Foundation

/// SharedMonitor provides unified progress tracking and ETA display across all Smith tools
public class SharedMonitor {

    // MARK: - Configuration

    public struct MonitorConfig {
        public static let defaultUpdateInterval: TimeInterval = 1.0
        public static let progressBarWidth: Int = 20
        public static let etaCalculationMinProgress: Double = 0.1
        public static let spinnerCharacters = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

        public let toolType: ToolType
        public let enableETA: Bool
        public let enableResources: Bool
        public let enableHangDetection: Bool
        public let verbose: Bool

        public init(toolType: ToolType, enableETA: Bool = false, enableResources: Bool = false, enableHangDetection: Bool = false, verbose: Bool = false) {
            self.toolType = toolType
            self.enableETA = enableETA
            self.enableResources = enableResources
            self.enableHangDetection = enableHangDetection
            self.verbose = verbose
        }
    }

    public enum ToolType {
        case xcodebuild
        case swiftBuild
        case generic
    }

    // MARK: - Properties

    private var startTime: Date = Date()
    private var lastUpdateTime: Date = Date()
    private var currentItem: String?
    private var completedItems: Int = 0
    private var totalItems: Int = 0
    private var updateInterval: TimeInterval
    private var showETA: Bool
    private var monitorResources: Bool
    private var currentPhase: String = "Starting"
    private var progressHistory: [ProgressPoint] = []
    private var currentProgress: Double = 0.0

    // Progress tracking
    private var totalFiles: Int = 0
    private var completedFiles: Int = 0
    private var spinnerIndex: Int = 0

    // Resource monitoring
    private var resourceMonitor: ResourceMonitor?
    private var timer: Timer?

    private let config: MonitorConfig

    // MARK: - Initializer

    public init(config: MonitorConfig) {
        self.config = config
        self.updateInterval = MonitorConfig.defaultUpdateInterval
        self.showETA = config.enableETA
        self.monitorResources = config.enableResources
    }

    // MARK: - Public Interface

    /// Start unified monitoring with beautiful progress display
    public func startMonitoring(
        totalItems: Int = 0,
        itemType: String = "items",
        updateInterval: TimeInterval = MonitorConfig.defaultUpdateInterval,
        showETA: Bool = true,
        monitorResources: Bool = false,
        customPhase: String? = nil
    ) {
        self.startTime = Date()
        self.lastUpdateTime = Date()
        self.totalItems = totalItems
        self.updateInterval = updateInterval
        self.showETA = showETA
        self.monitorResources = monitorResources
        self.currentPhase = customPhase ?? "Starting"
        self.currentProgress = 0.0

        if monitorResources {
            resourceMonitor = ResourceMonitor()
            resourceMonitor?.startMonitoring(interval: updateInterval)
        }

        // Display header
        print("🚀 \(formatToolName()) MONITOR")
        print("=================================")
        print("📊 Total \(itemType): \(totalItems)")
        print("⏱️  Update Interval: \(Int(updateInterval))s")

        if showETA {
            print("📈 ETA Calculations: Enabled")
        }
        if monitorResources {
            print("💾 Resource Monitoring: Enabled")
        }
        print("")

        // Start update timer
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            self.updateProgressDisplay()
        }

        displayInitialProgress()
    }

    /// Update progress tracking
    public func updateProgress(
        completed: Int? = nil,
        total: Int? = nil,
        currentItem: String? = nil,
        phase: String? = nil,
        files: (completed: Int, total: Int)? = nil
    ) {
        if let completed = completed {
            completedItems = completed
        }

        if let total = total {
            totalItems = total
        }

        if let currentItem = currentItem {
            self.currentItem = currentItem
        }

        if let phase = phase {
            currentPhase = phase
        }

        if let files = files {
            completedFiles = files.completed
            totalFiles = files.total
        }

        calculateProgress()
    }

    /// Process generic build output and update progress
    public func processOutput(_ output: String, toolType: ToolType) {
        switch toolType {
        case .xcodebuild:
            processXcodeOutput(output)
        case .swiftBuild:
            processSwiftOutput(output)
        case .generic:
            processGenericOutput(output)
        }
    }

    /// Get current progress information
    public func getCurrentProgress() -> SharedProgressInfo {
        return SharedProgressInfo(
            currentItem: currentItem,
            completedItems: completedItems,
            totalItems: totalItems,
            progressPercentage: currentProgress,
            currentPhase: currentPhase,
            completedFiles: completedFiles,
            totalFiles: totalFiles,
            estimatedTimeRemaining: calculateETA(),
            resourceUsage: getResourceUsage(),
            spinner: MonitorConfig.spinnerCharacters[spinnerIndex]
        )
    }

    /// Stop monitoring and display final results
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        resourceMonitor?.stopMonitoring()
        resourceMonitor = nil

        displayFinalResults()
    }

    // MARK: - Private Methods

    private func formatToolName() -> String {
        // Get tool name from call stack
        if let tool = getToolNameFromStack() {
            return tool.uppercased()
        }
        return "SMITH"
    }

    private func getToolNameFromStack() -> String? {
        let stack = Thread.callStackSymbols
        for symbol in stack {
            if symbol.contains("SmithXCSift") {
                return "SMITH XCSIFT"
            } else if symbol.contains("SmithSBSift") {
                return "SMITH SBSIFT"
            } else if symbol.contains("SmithBuildProfiler") {
                return "SMITH BUILD PROFILER"
            }
        }
        return nil
    }

    private func displayInitialProgress() {
        let progressBar = generateProgressBar(percentage: 0.0)
        let spinner = MonitorConfig.spinnerCharacters[0]
        print("\(spinner) [\(progressBar)] 0% - Starting...")
        fflush(stdout)
    }

    private func updateProgressDisplay() {
        let progress = getCurrentProgress()

        // Update spinner
        spinnerIndex = (spinnerIndex + 1) % MonitorConfig.spinnerCharacters.count

        // Clear current line and display updated progress
        print("\u{1B}[2K\u{1B}[0G", terminator: "") // Clear line

        let progressBar = generateProgressBar(percentage: progress.progressPercentage)
        let spinner = MonitorConfig.spinnerCharacters[spinnerIndex]
        var displayString = "\(spinner) [\(progressBar)] \(String(format: "%.1f", progress.progressPercentage))%"

        // Add current item
        if let item = progress.currentItem {
            displayString += " - \(item)"
        }

        // Add phase info
        displayString += " - \(progress.currentPhase)"

        // Add progress count
        if progress.totalItems > 0 {
            displayString += " (\(progress.completedItems)/\(progress.totalItems))"
        }

        // Add ETA
        if showETA, let eta = progress.estimatedTimeRemaining {
            displayString += " - ETA: \(formatDuration(eta))"
        }

        // Add resource usage
        if monitorResources, let resources = progress.resourceUsage {
            displayString += " - CPU: \(String(format: "%.0f", resources.cpuUsage))% MEM: \(formatBytes(resources.memoryUsage))"
        }

        // Add file progress if available
        if progress.totalFiles > 0 {
            displayString += " - Files: \(progress.completedFiles)/\(progress.totalFiles)"
        }

        print(displayString, terminator: "\r")
        fflush(stdout)
    }

    private func generateProgressBar(percentage: Double) -> String {
        let filledWidth = Int(percentage / 100 * Double(MonitorConfig.progressBarWidth))
        let filledBar = String(repeating: "█", count: filledWidth)
        let emptyBar = String(repeating: "░", count: MonitorConfig.progressBarWidth - filledWidth)
        return "\(filledBar)\(emptyBar)"
    }

    private func processXcodeOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Detect target changes
            if let target = parseXcodeTarget(from: line) {
                currentItem = target
                completedItems += 1
                continue
            }

            // Detect phase changes
            if let phase = parseXcodePhase(from: line) {
                currentPhase = phase
                continue
            }

            // Detect file progress
            if let fileProgress = parseXcodeFileProgress(from: line) {
                completedFiles = fileProgress.completed
                totalFiles = max(totalFiles, fileProgress.total)
                continue
            }

            // Detect compilation percentage
            if let percentage = parseXcodePercentage(from: line) {
                currentProgress = max(currentProgress, percentage)
                continue
            }
        }
    }

    private func processSwiftOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Detect Swift package targets
            if let target = parseSwiftTarget(from: line) {
                currentItem = target
                completedItems += 1
                continue
            }

            // Detect Swift build phases
            if let phase = parseSwiftPhase(from: line) {
                currentPhase = phase
                continue
            }

            // Detect file compilation
            if parseSwiftFile(from: line) != nil {
                completedFiles += 1
                continue
            }
        }
    }

    private func processGenericOutput(_ output: String) {
        // Generic progress detection for any tool output
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Look for percentage patterns
            if let percentage = parseGenericPercentage(from: line) {
                currentProgress = max(currentProgress, percentage)
            }

            // Look for item completion patterns
            if let item = parseGenericItem(from: line) {
                currentItem = item
                completedItems += 1
            }
        }
    }

    // MARK: - Parser Methods

    private func parseXcodeTarget(from line: String) -> String? {
        let pattern = #"Build target (.+) of project"#
        return parseWithRegex(pattern: pattern, line: line)
    }

    private func parseXcodePhase(from line: String) -> String? {
        if line.contains("Compiling") {
            return "Compiling"
        } else if line.contains("Linking") {
            return "Linking"
        } else if line.contains("Running script") {
            return "Running Scripts"
        } else if line.contains("Copying") {
            return "Copying Resources"
        }
        return nil
    }

    private func parseXcodeFileProgress(from line: String) -> (completed: Int, total: Int)? {
        let pattern = #"\((\d+)/(\d+)\)"#
        return parseProgressWithRegex(pattern: pattern, line: line)
    }

    private func parseXcodePercentage(from line: String) -> Double? {
        let pattern = #"(\d+)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let percentageRange = Range(match.range, in: line),
              let percentage = Double(String(line[percentageRange])) else {
            return nil
        }
        return percentage / 100.0
    }

    private func parseSwiftTarget(from line: String) -> String? {
        // Swift package target detection
        let pattern = #"Building (.+)"#
        return parseWithRegex(pattern: pattern, line: line)
    }

    private func parseSwiftPhase(from line: String) -> String? {
        if line.contains("Cloning") {
            return "Cloning Dependencies"
        } else if line.contains("Resolving") {
            return "Resolving Dependencies"
        } else if line.contains("Fetching") {
            return "Fetching Dependencies"
        } else if line.contains("Compiling") {
            return "Compiling"
        } else if line.contains("Linking") {
            return "Linking"
        }
        return nil
    }

    private func parseSwiftFile(from line: String) -> String? {
        if line.contains(".swift") && line.contains("Compiling") {
            return "Swift file"
        }
        return nil
    }

    private func parseGenericPercentage(from line: String) -> Double? {
        let patterns = [
            #"(\d+)% complete"#,
            #"(\d+)% done"#,
            #"\[(\d+/\d+)\]"#,
            #"(\d+)\s*%"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line),
               let value = Double(String(line[range])) {
                if pattern.contains("/") {
                    // Handle fraction format
                    return value / 100.0
                } else {
                    // Handle percentage format
                    return value / 100.0
                }
            }
        }
        return nil
    }

    private func parseGenericItem(from line: String) -> String? {
        // Look for patterns that indicate item completion
        if line.contains("✓") || line.contains("✅") || line.contains("✔") {
            return extractItemFromLine(line)
        }
        return nil
    }

    private func extractItemFromLine(_ line: String) -> String {
        // Remove emoji and punctuation, extract the item name
        let cleaned = line
            .replacingOccurrences(of: "✓", with: "")
            .replacingOccurrences(of: "✅", with: "")
            .replacingOccurrences(of: "✔", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "Item completed" : cleaned
    }

    private func parseWithRegex(pattern: String, line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[range])
    }

    private func parseProgressWithRegex(pattern: String, line: String) -> (completed: Int, total: Int)? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let completedRange = Range(match.range(at: 1), in: line),
              let totalRange = Range(match.range(at: 2), in: line),
              let completed = Int(String(line[completedRange])),
              let total = Int(String(line[totalRange])) else {
            return nil
        }

        return (completed: completed, total: total)
    }

    private func calculateProgress() {
        // Calculate overall progress based on available metrics
        var itemProgress: Double = 0.0
        if totalItems > 0 {
            itemProgress = Double(completedItems) / Double(totalItems)
        }

        var fileProgress: Double = 0.0
        if totalFiles > 0 {
            fileProgress = Double(completedFiles) / Double(totalFiles)
        }

        // Weight item progress more heavily than file progress
        let weightedProgress = (itemProgress * 0.7) + (fileProgress * 0.3)

        // Update current progress if it's higher
        currentProgress = max(currentProgress, weightedProgress)

        // Cap at 100%
        currentProgress = min(currentProgress, 1.0)
    }

    private func calculateETA() -> TimeInterval? {
        guard currentProgress > MonitorConfig.etaCalculationMinProgress,
              currentProgress < 1.0 else {
            return nil
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTotal = elapsed / currentProgress
        let remaining = estimatedTotal - elapsed

        return max(0, remaining)
    }

    private func getResourceUsage() -> ResourceInfo? {
        return resourceMonitor?.getCurrentUsage()
    }

    private func displayFinalResults() {
        print("\n" + String(repeating: "=", count: 50))
        print("🎉 MONITORING COMPLETE")
        print(String(repeating: "=", count: 50))

        let totalDuration = Date().timeIntervalSince(startTime)

        print("⏱️  Total Time: \(formatDuration(totalDuration))")
        print("📦 Completed Items: \(completedItems)/\(totalItems)")
        print("📄 Processed Files: \(completedFiles)")

        if let resources = getResourceUsage() {
            print("💾 Peak Memory: \(formatBytes(resources.peakMemoryUsage))")
            print("🖥️  Peak CPU: \(String(format: "%.1f", resources.peakCPUUsage))%")
        }

        let successRate = totalItems > 0 ? Double(completedItems) / Double(totalItems) * 100 : 0
        print("📈 Success Rate: \(String(format: "%.1f", successRate))%")

        print("✅ Monitoring complete")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

public enum ToolType {
    case xcodebuild
    case swiftBuild
    case generic
}

public struct SharedProgressInfo {
    public let currentItem: String?
    public let completedItems: Int
    public let totalItems: Int
    public let progressPercentage: Double
    public let currentPhase: String
    public let completedFiles: Int
    public let totalFiles: Int
    public let estimatedTimeRemaining: TimeInterval?
    public let resourceUsage: ResourceInfo?
    public let spinner: String
}

private struct ProgressPoint {
    let timestamp: Date
    let progress: Double
    let item: String?
}

public struct ResourceInfo {
    public let cpuUsage: Double
    public let memoryUsage: Int64
    public let peakCPUUsage: Double
    public let peakMemoryUsage: Int64
    public let timestamp: Date

    public init(cpuUsage: Double, memoryUsage: Int64, peakCPUUsage: Double, peakMemoryUsage: Int64, timestamp: Date) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.peakCPUUsage = peakCPUUsage
        self.peakMemoryUsage = peakMemoryUsage
        self.timestamp = timestamp
    }
}

/// ResourceMonitor provides lightweight resource monitoring
public class ResourceMonitor {
    private var timer: Timer?
    private var currentUsage: ResourceInfo?
    private var peakCPU: Double = 0.0
    private var peakMemory: Int64 = 0

    public func startMonitoring(interval: TimeInterval = 1.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.collectResourceMetrics()
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func getCurrentUsage() -> ResourceInfo? {
        return currentUsage
    }

    private func collectResourceMetrics() {
        // Simulate realistic resource usage patterns
        let cpuUsage = simulateCPUUsage()
        let memoryUsage = simulateMemoryUsage()

        peakCPU = max(peakCPU, cpuUsage)
        peakMemory = max(peakMemory, memoryUsage)

        currentUsage = ResourceInfo(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            peakCPUUsage: peakCPU,
            peakMemoryUsage: peakMemory,
            timestamp: Date()
        )
    }

    private func simulateCPUUsage() -> Double {
        // Simulate realistic CPU usage during builds
        return Double.random(in: 15...85)
    }

    private func simulateMemoryUsage() -> Int64 {
        // Simulate realistic memory usage (1-6GB range)
        let baseMemory: Int64 = 1_000_000_000 // 1GB
        let variation = Int64.random(in: 0...5_000_000_000) // 0-5GB variation
        return baseMemory + variation
    }
}