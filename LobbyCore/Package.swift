// swift-tools-version: 5.9
import PackageDescription

// Plain Swift with no UI, so it builds and tests on Mac, iPhone, iPad and Linux.
// Everything that can be worked out without a screen lives here.
let package = Package(
    name: "LobbyCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "LobbyCore", targets: ["LobbyCore"]),
    ],
    targets: [
        .target(name: "LobbyCore"),
        .testTarget(name: "LobbyCoreTests", dependencies: ["LobbyCore"]),
    ]
)
