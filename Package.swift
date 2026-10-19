// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "blankbar",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "blankbar", targets: ["blankbar"]),
    ],
    targets: [
        // Pure logic with no side effects, so it can be unit tested on any Mac.
        .target(name: "BlankBarCore"),
        // Everything that touches the system: private frameworks, launchd, the file system.
        .executableTarget(name: "blankbar", dependencies: ["BlankBarCore"]),
        .testTarget(name: "BlankBarCoreTests", dependencies: ["BlankBarCore"]),
    ]
)
