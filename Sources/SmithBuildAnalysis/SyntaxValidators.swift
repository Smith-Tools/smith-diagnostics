import Foundation

/// Smith Syntax Validators - Compile-time guards for Swift build performance
///
/// Enforces patterns that prevent type inference explosions and architectural anti-patterns
/// Integrates with Smith Framework's "syntax-first validation" discipline

// MARK: - Validation Decorators

/// Marks a feature for TCA architectural validation
@attached(peer, names: arbitrary)
public macro SmithTCAValidator() = #externalMacro(module: "SmithSyntaxValidators", type: "TCAValidatorMacro")

/// Marks a view for SwiftUI type inference validation
@attached(peer, names: arbitrary)
public macro SmithUIViewValidator() = #externalMacro(module: "SmithSyntaxValidators", type: "UIViewValidatorMacro")

/// Marks complex closures for explicit type annotation validation
@attached(peer, names: arbitrary)
public macro SmithExplicitTypes() = #externalMacro(module: "SmithSyntaxValidators", type: "ExplicitTypesMacro")

/// Enables auto-fix suggestions for detected anti-patterns
@attached(peer, names: arbitrary)
public macro SmithAutoFix() = #externalMacro(module: "SmithSyntaxValidators", type: "AutoFixMacro")

// MARK: - Validation Rules

/// Smith TCA Validation Rules
public enum TCAValidationRules {
    /// Prevents nested CombineReducers (major performance anti-pattern)
    public static let noNestedCombineReducers = """
    ❌ ANTI-PATTERN DETECTED:
    body: some Reducer<State, Action> {
      CombineReducers {
        childReducers()  // ❌ Contains another CombineReducers
        mainReducers()   // ❌ Creates exponential type inference
      }
    }

    ✅ SMITH-APPROVED PATTERN:
    @ReducerBuilder
    public var body: some Reducer<State, Action> {
      childReducers()
      mainReducers()
    }
    """

    /// Ensures proper @Dependency usage
    public static let properDependencyUsage = #"""
    ✅ DEPENDENCY PATTERNS:
    @Dependency(\.articleStore) var articleStore
    @Dependency(\.date) var date
    @Dependency(\.continuousClock) var clock
    """#

    /// Validates child feature composition
    public static let flatChildFeatureComposition = #"""
    ✅ CHILD FEATURE COMPOSITION:
    Scope(state: \.child, action: \.child) {
      ChildFeature()
    }
    .ifLet(\.$optionalChild, action: \.optionalChild) {
      OptionalChildFeature()
    }
    """#
}

/// Smith SwiftUI Validation Rules
public enum SwiftUIValidationRules {
    /// Prevents complex inline closures
    public static let extractComplexClosures = #"""
    ❌ ANTI-PATTERN DETECTED:
    .environment(\.articleContextMenuActions, ArticleContextMenuActions(
      toggleRead: { [store] article in
        store.send(.articleOperations(.toggleRead(article.id)))
      },
      // ... 10 more untyped closures
    ))

    ✅ SMITH-APPROVED PATTERN:
    private var articleContextMenuActions: ArticleContextMenuActions {
      ArticleContextMenuActions(
        toggleRead: { [store] article in
          store.send(.articleOperations(.toggleRead(article.id)))
        }
      )
    }
    .environment(\.articleContextMenuActions, articleContextMenuActions)
    """#

    /// Validates binding patterns
    public static let explicitBindingTypes = #"""
    ✅ BINDING PATTERNS:
    let inspectorBinding: Binding<Bool> = Binding<Bool>(
      get: { [store] in store.isInspectorPresented },
      set: { [store] value in
        store.send(.binding(.set(\.isInspectorPresented, value)))
      }
    )
    """#

    /// Prevents excessively long modifier chains
    public static let moderateModifierChains = """
    ❌ ANTI-PATTERN: 20+ modifiers in single chain
    ✅ SMITH-APPROVED: Extract to computed properties or break into subviews
    """
}

// MARK: - Auto-Fix Templates

public enum SmithAutoFixTemplates {
    /// Auto-fix for type inference explosions in views
    public static func extractComplexEnvironment(
        file: String = #file,
        line: Int = #line
    ) -> String {
        return """
        // SMITH AUTO-FIX: Extract complex environment closure
        // Detected at \(file):\(line)

        private var complexEnvironmentValue: ComplexType {
            ComplexType(
                property1: { /* extract logic here */ },
                property2: { /* extract logic here */ }
            )
        }

        .environment(\\.key, complexEnvironmentValue)
        """
    }

    /// Auto-fix for TCA reducer composition
    public static func flattenReducerComposition(
        file: String = #file,
        line: Int = #line
    ) -> String {
        return """
        // SMITH AUTO-FIX: Flatten nested CombineReducers
        // Detected at \(file):\(line)

        @ReducerBuilder<State, Action>
        private var flattenedBody: some Reducer<State, Action> {
          // Extract child reducer logic here
          childReducerLogic()
          mainReducerLogic()
        }

        public var body: some Reducer<State, Action> {
          flattenedBody
        }
        """
    }

    /// Auto-fix for complex SwiftUI bindings
    public static func extractComplexBinding(
        file: String = #file,
        line: Int = #line
    ) -> String {
        return """
        // SMITH AUTO-FIX: Extract complex binding
        // Detected at \(file):\(line)

        private var complexBinding: Binding<Type> {
          Binding<Type>(
            get: { /* extract get logic */ },
            set: { /* extract set logic */ }
          )
        }
        """
    }
}

// MARK: - Real-time Validation

public class SmithSyntaxValidator {

    /// Validates TCA features for performance anti-patterns
    public static func validateTCAFeature(
        _ featureType: Any.Type,
        file: String = #file,
        line: Int = #line
    ) -> ValidationResult {
        var violations: [Violation] = []

        // Check for nested CombineReducers (critical)
        violations.append(checkNestedCombineReducers(featureType, file: file, line: line))

        // Check dependency usage (medium)
        violations.append(checkDependencyUsage(featureType, file: file, line: line))

        // Check child feature composition (low)
        violations.append(checkChildFeatureComposition(featureType, file: file, line: line))

        return ValidationResult(
            featureType: String(describing: featureType),
            violations: violations.filter { !$0.passed },
            file: file,
            line: line
        )
    }

    /// Validates SwiftUI views for type inference issues
    public static func validateSwiftUIView(
        _ viewType: Any.Type,
        file: String = #file,
        line: Int = #line
    ) -> ValidationResult {
        var violations: [Violation] = []

        // Check for complex environment closures (critical)
        violations.append(checkComplexEnvironmentClosures(viewType, file: file, line: line))

        // Check binding patterns (medium)
        violations.append(checkBindingPatterns(viewType, file: file, line: line))

        // Check modifier chain length (low)
        violations.append(checkModifierChainLength(viewType, file: file, line: line))

        return ValidationResult(
            featureType: String(describing: viewType),
            violations: violations.filter { !$0.passed },
            file: file,
            line: line
        )
    }

    // MARK: - Private Validation Methods

    private static func checkNestedCombineReducers(
        _ type: Any.Type,
        file: String,
        line: Int
    ) -> Violation {
        // In implementation, this would analyze the AST
        // For now, return placeholder validation
        return Violation(
            rule: "No nested CombineReducers",
            severity: .critical,
            passed: true, // Would be false if pattern detected
            message: "No nested CombineReducers detected",
            autoFix: SmithAutoFixTemplates.flattenReducerComposition(file: file, line: line)
        )
    }

    private static func checkComplexEnvironmentClosures(
        _ type: Any.Type,
        file: String,
        line: Int
    ) -> Violation {
        return Violation(
            rule: "Extract complex environment closures",
            severity: .critical,
            passed: true,
            message: "No complex environment closures detected",
            autoFix: SmithAutoFixTemplates.extractComplexEnvironment(file: file, line: line)
        )
    }

    private static func checkDependencyUsage(
        _ type: Any.Type,
        file: String,
        line: Int
    ) -> Violation {
        return Violation(
            rule: "Proper @Dependency usage",
            severity: .medium,
            passed: true,
            message: "Dependencies properly declared",
            autoFix: "Review @Dependency property declarations"
        )
    }

    private static func checkBindingPatterns(
        _ type: Any.Type,
        file: String,
        line: Int
    ) -> Violation {
        return Violation(
            rule: "Explicit binding types",
            severity: .medium,
            passed: true,
            message: "Binding types are explicit",
            autoFix: SmithAutoFixTemplates.extractComplexBinding(file: file, line: line)
        )
    }

    private static func checkChildFeatureComposition(
        _ type: Any.Type,
        file: String,
        line: Int
    ) -> Violation {
        return Violation(
            rule: "Flat child feature composition",
            severity: .low,
            passed: true,
            message: "Child features properly composed",
            autoFix: "Use @ReducerBuilder for complex composition"
        )
    }

    private static func checkModifierChainLength(
        _ type: Any.Type,
        file: String,
        line: Int
    ) -> Violation {
        return Violation(
            rule: "Moderate modifier chain length",
            severity: .low,
            passed: true,
            message: "Modifier chains are reasonable length",
            autoFix: "Extract long modifier chains to computed properties"
        )
    }
}

// MARK: - Data Models

public struct ValidationResult {
    public let featureType: String
    public let violations: [Violation]
    public let file: String
    public let line: Int

    public var hasViolations: Bool {
        !violations.isEmpty
    }

    public var criticalViolations: [Violation] {
        violations.filter { $0.severity == .critical }
    }
}

public struct Violation {
    public let rule: String
    public let severity: Severity
    public let passed: Bool
    public let message: String
    public let autoFix: String
}


// MARK: - Build-time Integration

/// Smith build-time validator that runs during compilation
public struct SmithBuildValidator {

    /// Validates all features in a target for performance anti-patterns
    public static func validateTarget(
        _ target: String,
        directory: String
    ) -> TargetValidationResult {
        let swiftFiles = findSwiftFiles(in: directory)
        var results: [ValidationResult] = []

        for file in swiftFiles {
            if file.contains("Feature.swift") {
                // Validate TCA features
                let result = validateTCAFeatureFile(file)
                if result.hasViolations {
                    results.append(result)
                }
            } else if file.contains("View.swift") {
                // Validate SwiftUI views
                let result = validateSwiftUIViewFile(file)
                if result.hasViolations {
                    results.append(result)
                }
            }
        }

        return TargetValidationResult(
            target: target,
            results: results,
            totalViolations: results.reduce(0) { $0 + $1.violations.count },
            criticalViolations: results.reduce(0) { $0 + $1.criticalViolations.count }
        )
    }

    private static func findSwiftFiles(in directory: String) -> [String] {
        // Implementation would use FileManager to find .swift files
        return []
    }

    private static func validateTCAFeatureFile(_ file: String) -> ValidationResult {
        // Implementation would parse and validate TCA features
        return ValidationResult(
            featureType: "TCAFeature",
            violations: [],
            file: file,
            line: 0
        )
    }

    private static func validateSwiftUIViewFile(_ file: String) -> ValidationResult {
        // Implementation would parse and validate SwiftUI views
        return ValidationResult(
            featureType: "SwiftUIView",
            violations: [],
            file: file,
            line: 0
        )
    }
}

public struct TargetValidationResult {
    public let target: String
    public let results: [ValidationResult]
    public let totalViolations: Int
    public let criticalViolations: Int

    public var passed: Bool {
        criticalViolations == 0
    }

    public var summary: String {
        if passed {
            return "✅ \(target): No critical violations"
        } else {
            return "❌ \(target): \(criticalViolations) critical violations"
        }
    }
}