// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Orbitile",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "OrbitileCore"),
        .executableTarget(name: "Orbitile", dependencies: ["OrbitileCore"]),
        .executableTarget(name: "OrbitileChecks", dependencies: ["OrbitileCore"]),
        .testTarget(name: "OrbitileCoreTests", dependencies: ["OrbitileCore"]),
    ]
)
