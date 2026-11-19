// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ApexText", platforms: [.macOS(.v14)], products: [.executable(name: "ApexText", targets: ["ApexText"])], dependencies: [.package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.9.0")], targets: [.executableTarget(name: "ApexText", dependencies: [.product(name: "Markdown", package: "swift-markdown")], resources: [.process("Resources")]), .testTarget(name: "ApexTextTests", dependencies: ["ApexText"])])
