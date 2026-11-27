// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ScratchData",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ScratchData", targets: ["ScratchData"])],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.12.0")
    ],
    targets: [
        .target(name: "ScratchData", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "ScratchDataTests", dependencies: ["ScratchData"])
    ]
)
