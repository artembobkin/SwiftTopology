// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftTopology",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "Topology", targets: ["Topology"]),
    ],
    targets: [
        // A Swift port of the JTS Topology Suite 1.20.0 (EDL-1.0), behaving
        // bit for bit as GEOS 3.13 (Docs/PortingParity.md).
        .target(name: "Topology", path: "Sources/Topology"),
        // The port against GEOS 3.13's answers, stored when GEOS left (Tests/TopologyTests/.oracle).
        .testTarget(name: "TopologyTests", dependencies: ["Topology"], path: "Tests/TopologyTests"),
    ],
    swiftLanguageModes: [.v5]
)
