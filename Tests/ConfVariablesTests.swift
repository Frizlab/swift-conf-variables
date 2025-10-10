import Foundation
import Testing

@testable import ConfVariables



struct ConfVariablesTests {
	
	@Test
	func testBasicUsage() throws {
		setenv("YOLO", "yolenv", 1)
		#expect(try ConfVariables.resolveVariables(in: #""#, localVars: [:]) == Data("".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"\$"#, localVars: [:]) == Data("$".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"yolo"#, localVars: [:]) == Data("yolo".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"\${yolo}"#, localVars: ["yolo": Data("hey!".utf8)]) == Data("${yolo}".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"\$\{yolo}"#, localVars: ["yolo": Data("hey!".utf8)]) == Data(#"${yolo}"#.utf8))
		#expect(try ConfVariables.resolveVariables(in: #"yolo${yolo}yolo"#, localVars: ["yolo": Data("hey!".utf8)]) == Data("yolohey!yolo".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"yolo${env:YOLO}\$"#, localVars: ["YOLO": Data("hey!".utf8)]) == Data("yoloyolenv$".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"yolo${env:YOLO}\$${YOLO}"#, localVars: ["YOLO": Data("hey!".utf8)]) == Data("yoloyolenv$hey!".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"${local:${env:YOLO}}"#, localVars: ["yolenv": Data("hey!".utf8)]) == Data("hey!".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"${${YOLO}}"#, localVars: ["YOLO": Data("subyolo".utf8), "subyolo": Data("hey!".utf8)]) == Data("hey!".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"${${YOLO}}"#, localVars: ["YOLO": Data("local:subyolo".utf8), "subyolo": Data("hey!".utf8)]) == Data("hey!".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"${local:sub${YOLO}}"#, localVars: ["YOLO": Data("yolo".utf8), "subyolo": Data("hey!".utf8)]) == Data("hey!".utf8))
	}
	
	@Test
	func ensureFailures() throws {
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"$"#, localVars: [:]) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"${}"#, localVars: [:]) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"$\{abc}"#, localVars: ["abc": Data("yolo".utf8)]) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"${env:NOTEXISTING}"#, localVars: [:]) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"${env:YOLO}"#, localVars: [:], allowEnvVars: false) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"${invalid-domain:YOLO}"#, localVars: [:], allowEnvVars: false) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"${${YOLO}}"#, localVars: ["YOLO": Data("invalid-domain:subyolo".utf8), "subyolo": Data("hey!".utf8)]) as Data })
	}
	
}
