import Foundation



public enum ConfVariables {
	
	public static func resolveVariables(in string: String?, localVars: [String: Data], allowEnvVars: Bool = true, allowFileVars: Bool = true, allowEmbeddedVars: Bool = true) throws -> String? {
		guard let string else {return nil}
		return try resolveVariables(in: string, localVars: localVars, allowEnvVars: allowEnvVars, allowFileVars: allowFileVars, allowEmbeddedVars: allowEmbeddedVars) as String
	}
	
	public static func resolveVariables(in string: String, localVars: [String: Data], allowEnvVars: Bool = true, allowFileVars: Bool = true, allowEmbeddedVars: Bool = true) throws -> String {
		let data = try resolveVariables(in: string, localVars: localVars, allowEnvVars: allowEnvVars, allowFileVars: allowFileVars, allowEmbeddedVars: allowEmbeddedVars) as Data
		guard let ret = String(data: data, encoding: .utf8) else {
			throw Err.resolvedDataIsNotValidUTF8(data)
		}
		return ret
	}
	
	public static func resolveVariables(in string: String?, localVars: [String: Data], allowEnvVars: Bool = true, allowFileVars: Bool = true, allowEmbeddedVars: Bool = true) throws -> Data? {
		guard let string else {return nil}
		return try resolveVariables(in: string, localVars: localVars, allowEnvVars: allowEnvVars, allowFileVars: allowFileVars, allowEmbeddedVars: allowEmbeddedVars) as Data
	}
	
	public static func resolveVariables(in string: String, localVars: [String: Data], allowEnvVars: Bool = true, allowFileVars: Bool = true, allowEmbeddedVars: Bool = true) throws -> Data {
		let sourceData = Data(string.utf8)
		var iterator = sourceData.makeIterator()
		return try resolveVariables(in: &iterator, localVars: localVars, allowEnvVars: allowEnvVars, allowFileVars: allowFileVars, allowEmbeddedVars: allowEmbeddedVars, parsingEmbedded: false)
	}
	
	/* Variable resolution algorithm:
	 * - Retrieve the domain and name from the variable name:
	 *   - The domain is the value before the first semicolon;
	 *   - If there are no semicolon in the variable name, we use "local" for the domain.
	 * - Switch on the domain:
	 *   - "local": we try to retrieve the value from the localVars;
	 *   - "env":   we try to retrieve the value from environment if environment variables are enabled, otherwise we fail;
	 *   - "file":  we try to retrieve the value from a file if file variables are enabled, otherwise we fail;
	 *   - other value: we fail. */
	public static func resolveVariables(in dataIterator: inout Data.Iterator, localVars: [String: Data], allowEnvVars: Bool = true, allowFileVars: Bool = true, allowEmbeddedVars: Bool = true, parsingEmbedded: Bool) throws -> Data {
		enum State : Equatable {
			case waitingVarStart(escaped: Bool)
			case confirmingVarEntry
			case waitingVarEnd(escaped: Bool)
		}
		
		var result = Data()
		var curVar = Data()
		var state = State.waitingVarStart(escaped: false)
		while let c = dataIterator.next() {
			switch (state, Character(UnicodeScalar(c))) {
				case (.waitingVarStart(escaped: false), #"\"#):
					state = .waitingVarStart(escaped: true)
					
				case (.waitingVarStart(escaped: false), "$"):
					state = .confirmingVarEntry
					
				case (.waitingVarStart(escaped: true), _):
					state = .waitingVarStart(escaped: false)
					result.append(c)
					
				case (.waitingVarStart(escaped: false), "}") where parsingEmbedded:
					return try resolveVariable(result, localVars: localVars, allowEnvVars: allowEnvVars, allowFileVars: allowFileVars)
					
				case (.waitingVarStart(escaped: false), _):
					result.append(c)
					
				case (.confirmingVarEntry, "{"):
					assert(curVar.isEmpty)
					if allowEmbeddedVars {
						result.append(try resolveVariables(in: &dataIterator, localVars: localVars, allowEnvVars: allowEnvVars, allowFileVars: allowFileVars, allowEmbeddedVars: true, parsingEmbedded: true))
						state = .waitingVarStart(escaped: false)
					} else {
						state = .waitingVarEnd(escaped: false)
					}
					
				case (.confirmingVarEntry, #"\"#):
					throw Err.foundBackslashAfterDollar
					
				case (.confirmingVarEntry, _):
					result.append(Character("$").asciiValue!)
					result.append(c)
					state = .waitingVarStart(escaped: false)
					
				case (.waitingVarEnd(escaped: false), #"\"#):
					state = .waitingVarEnd(escaped: true)
					
				case (.waitingVarEnd(escaped: false), "}"):
					result.append(contentsOf: try resolveVariable(curVar, localVars: localVars, allowEnvVars: allowEnvVars, allowFileVars: allowFileVars))
					state = .waitingVarStart(escaped: false)
					curVar = Data()
					
				case (.waitingVarEnd(escaped: true), _):
					state = .waitingVarEnd(escaped: false)
					curVar.append(c)
					
				case (.waitingVarEnd(escaped: false), _):
					curVar.append(c)
			}
		}
		guard state == .waitingVarStart(escaped: false) else {
			throw Err.unfinishedString
		}
		return result
	}
	
	private static func resolveVariable(_ variableName: Data, localVars: [String: Data], allowEnvVars: Bool, allowFileVars: Bool) throws -> Data {
		guard !variableName.isEmpty else {throw Err.emptyVariableName}
		guard let varValue = String(data: variableName, encoding: .utf8) else {throw Err.variableNameIsNotUTF8(variableName)}
		return try {
			let rawSplit = varValue.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
			assert(rawSplit.count == 1 || rawSplit.count == 2)
			let split = rawSplit.count == 1 ? ["local"] + rawSplit : rawSplit
			assert(split.count == 2)
			let prefix = split[0]
			let varValue = String(split[1])
			switch prefix {
				case "local":
					guard let value = localVars[varValue] else {
						throw Err.unknownLocalVariable(varValue)
					}
					return value
					
				case "env":
					guard allowEnvVars else {
						throw Err.environmentVariableFoundButNotAllowed(varValue)
					}
					guard let value = ProcessInfo.processInfo.environment[varValue] else {
						throw Err.noValueForEnvironmentVariable(varValue)
					}
					return Data(value.utf8)
					
				case "file":
					guard allowFileVars else {
						throw Err.fileVariableFoundButNotAllowed(varValue)
					}
					do {
						return try Data(contentsOf: URL(fileURLWithPath: varValue))
					} catch {
						throw Err.couldNotReadFileVariableValue(varValue, error)
					}
					
				default:
					throw Err.unknownVariableKind(String(prefix), varName: varValue)
			}
		}()
	}
	
}
