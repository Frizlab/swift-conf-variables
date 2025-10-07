// swift-tools-version:6.0
import PackageDescription


let package = Package(
	name: "swift-conf-variables",
	products: [.library(name: "ConfVariables", targets: ["ConfVariables"])],
	targets: [
		.target(name: "ConfVariables", path: "Sources"),
		.testTarget(name: "ConfVariablesTests", dependencies: ["ConfVariables"], path: "Tests"),
	]
)
