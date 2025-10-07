import Foundation



@propertyWrapper
public struct LocalVariablesParsing : Decodable, Sendable {
	
	public var wrappedValue: [String: Data]
	
	public init () {
		self.wrappedValue = [:]
	}
	
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		wrappedValue = [:]
		for key in container.allKeys {
			/* First let’s do the easiest and most likely case: the value is a String.
			 *
			 * Note:
			 * Theoretically we should check the error in case the String decoding fails is indeed because the value is not a String…
			 * In practice it doesn’t matter. */
			let dataValue: Data
			if let val = try? container.decode(String.self, forKey: key) {
				dataValue = try ConfVariables.resolveVariables(in: val, localVars: [:], allowEnvVars: true, allowFileVars: true) as Data
			} else {
				/* The value is not a String: it must be a container. */
				let fullVal = try container.decode(FullValueDeclaration.self, forKey: key)
				dataValue = try {
					let stringValue: String
					switch fullVal.encoding {
						case .utf8:
							stringValue = fullVal.value
							/* The string value is resolved if needed later (after the switch).
							 * We could do that here too,
							 *  but are reserving ourselves the right to have other encoding leading to a String value
							 *  (which are the only ones that can have variables resolution as of now),
							 *  so we do it this way. */
							
						case .base64:
							guard let data = Data(base64Encoded: fullVal.value) else {
								throw Err.invalidBase64EncodedValue(fullVal.value)
							}
							return data
					}
					return try ConfVariables.resolveVariables(in: stringValue, localVars: [:], allowEnvVars: fullVal.resolveEnvVariables, allowFileVars: fullVal.resolveFileVariables) as Data
				}()
			}
			wrappedValue[key.stringValue] = dataValue
		}
	}
	
	private struct CodingKeys : CodingKey {
		
		let stringValue: String
		init(stringValue: String) {
			self.stringValue = stringValue
		}
		
		let intValue: Int? = nil
		init?(intValue: Int) {
			return nil
		}
		
	}
	
	private struct FullValueDeclaration : Decodable, Sendable {
		
		enum Encoding : String, Decodable {
			
			case utf8
			case base64
			
		}
		
		var value: String
		var encoding: Encoding
		/* Never true (but ignored) for non-string encoding (e.g. base64). */
		var resolveEnvVariables: Bool = true
		var resolveFileVariables: Bool = true
		
		private enum CodingKeys : String, CodingKey {
			
			case value
			case encoding
			case resolveEnvVariables = "resolve_env_variables"
			case resolveFileVariables = "resolve_file_variables"
			
		}
		
	}
	
}


public extension KeyedDecodingContainer {
	
	func decode(_ type: LocalVariablesParsing.Type, forKey key: Key) throws -> LocalVariablesParsing {
		return try decodeIfPresent(LocalVariablesParsing.self, forKey: key) ?? LocalVariablesParsing()
	}
	
}
