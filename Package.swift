// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PasteFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PasteFlow", targets: ["PasteFlow"])
    ],
    targets: [
        .executableTarget(
            name: "PasteFlow",
            path: "Sources/PasteFlow"
        ),
        .testTarget(
            name: "PasteFlowTests",
            dependencies: ["PasteFlow"],
            path: "Tests/PasteFlowTests"
        )
    ]
)
