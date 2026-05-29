import Foundation

/// One line's resolved prim-scope facts, produced by ``USDAPrimScopeTracker``.
public struct USDALineScope: Sendable, Equatable {
	/// Prim whose body directly contains this line's content (`nil` at top level),
	/// captured *before* this line's own braces are applied — so attribute lines
	/// resolve to their owning prim and a prim's closing `}` line resolves to that
	/// same prim (the insertion point).
	public let activePath: String?
	/// Full path of a prim declared on this line, if any.
	public let declaredPath: String?
	/// Indentation of a prim declared on this line, if any.
	public let declaredIndent: String?
	/// Type name (`def Cone "Cone"` → `Cone`) of a prim declared on this line, if any.
	public let declaredTypeName: String?
	/// Prim paths whose body closes on this line, in close order.
	public let closedPaths: [String]
}

/// Robust USDA prim-scope tracker shared across the text-based USDA readers and
/// authoring helpers.
///
/// Naive `{`/`}` counting desyncs the prim path stack because it also counts
/// braces that belong to `( … )` metadata blocks, dictionary values
/// (`customData = { … }`, `variants = { … }`), and string literals. When such a
/// dictionary precedes a sibling prim, every prim after it is assigned the wrong
/// path (e.g. `/Cone` instead of `/Root/Cone`), which surfaces as
/// "Target prim not found" or a mis-nested scene navigator. This tracker
/// classifies each brace as prim-scope vs. dictionary/metadata and only the
/// former moves the prim path stack.
///
/// Feed it one source line at a time, in order, and read the returned
/// ``USDALineScope``.
public struct USDAPrimScopeTracker: Sendable {
	private enum BraceKind { case prim, dict }
	private var primStack: [(path: String, indent: String)] = []
	private var braceStack: [BraceKind] = []
	private var parenDepth = 0
	private var pending: (path: String, indent: String, typeName: String?)?
	private var inString: Character?
	private var lastSignificant: Character = " "

	public init() {}

	public mutating func consume(_ line: String) -> USDALineScope {
		let activePath = primStack.last?.path
		var declaredPath: String?
		var declaredIndent: String?
		var declaredType: String?

		// Declarations only count at prim scope: not inside metadata parens, a
		// dictionary brace, or a string literal.
		let declarationRegex = /^(\s*)(?:def|over|class)\s+(?:([A-Za-z0-9_:]+)\s+)?"([^"]+)"/
		if parenDepth == 0, braceStack.last != .dict, inString == nil,
		   let match = line.firstMatch(of: declarationRegex) {
			let indent = String(match.output.1)
			let typeName = match.output.2.map(String.init)
			let primName = String(match.output.3)
			let path = primStack.last.map { "\($0.path)/\(primName)" } ?? "/\(primName)"
			pending = (path: path, indent: indent, typeName: typeName)
			declaredPath = path
			declaredIndent = indent
			declaredType = typeName
		}

		var closedPaths: [String] = []
		for ch in line {
			if let quote = inString {
				if ch == quote { inString = nil }
				continue
			}
			switch ch {
			case "\"", "'":
				inString = ch
				lastSignificant = ch
			case "#":
				// Comment to end of line; nothing past here affects scope.
				return USDALineScope(
					activePath: activePath,
					declaredPath: declaredPath,
					declaredIndent: declaredIndent,
					declaredTypeName: declaredType,
					closedPaths: closedPaths
				)
			case "(":
				parenDepth += 1
				lastSignificant = ch
			case ")":
				if parenDepth > 0 { parenDepth -= 1 }
				lastSignificant = ch
			case "{":
				if parenDepth > 0 || lastSignificant == "=" {
					braceStack.append(.dict)
				} else {
					braceStack.append(.prim)
					if let pendingPrim = pending {
						primStack.append((pendingPrim.path, pendingPrim.indent))
						pending = nil
					}
				}
				lastSignificant = ch
			case "}":
				if let kind = braceStack.popLast(), kind == .prim,
				   let closed = primStack.popLast() {
					closedPaths.append(closed.path)
				}
				lastSignificant = ch
			default:
				if !ch.isWhitespace { lastSignificant = ch }
			}
		}

		return USDALineScope(
			activePath: activePath,
			declaredPath: declaredPath,
			declaredIndent: declaredIndent,
			declaredTypeName: declaredType,
			closedPaths: closedPaths
		)
	}
}
