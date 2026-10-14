// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pastely",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pastely", targets: ["Pastely"])
    ],
    targets: [
        .executableTarget(
            name: "Pastely",
            path: "Sources/Pastely",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "PastelyTests",
            dependencies: ["Pastely"],
            path: "Tests/PastelyTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
