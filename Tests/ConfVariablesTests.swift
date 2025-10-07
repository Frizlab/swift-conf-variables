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
		#expect(try ConfVariables.resolveVariables(in: #"yolo${yolo}yolo"#, localVars: ["yolo": Data("hey!".utf8)]) == Data("yolohey!yolo".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"yolo${env:YOLO}\$"#, localVars: ["YOLO": Data("hey!".utf8)]) == Data("yoloyolenv$".utf8))
		#expect(try ConfVariables.resolveVariables(in: #"yolo${env:YOLO}\$${YOLO}"#, localVars: ["YOLO": Data("hey!".utf8)]) == Data("yoloyolenv$hey!".utf8))
	}
	
	@Test
	func ensureFailures() throws {
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"$"#, localVars: [:]) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"${}"#, localVars: [:]) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"$\{abc}"#, localVars: ["abc": Data("yolo".utf8)]) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"${env:NOTEXISTING}"#, localVars: [:]) as Data })
		#expect(throws: Err.self, performing: { try ConfVariables.resolveVariables(in: #"${env:YOLO}"#, localVars: [:], allowEnvVars: false) as Data })
	}
	
}
