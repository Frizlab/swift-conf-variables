import Foundation



public enum ConfVariablesError : Error {
	
	case invalidBase64EncodedValue(String)
	
	case resolvedDataIsNotValidUTF8(Data)
	
	case foundBackslashAfterDollar
	case unfinishedString
	
	case emptyVariableName
	case variableNameIsNotUTF8(Data)
	
	case unknownLocalVariable(String)
	
	case environmentVariableFoundButNotAllowed(String)
	case noValueForEnvironmentVariable(String)
	
	case fileVariableFoundButNotAllowed(String)
	case couldNotReadFileVariableValue(String, Error)
	
	/** The value for this case is the full variable name. */
	case unknownVariableKind(String, varName: String)
	
}

typealias Err = ConfVariablesError
