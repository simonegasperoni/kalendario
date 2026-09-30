// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Kalendario",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Kalendario", targets: ["Kalendario"])
    ],
    targets: [
        .executableTarget(name: "Kalendario", path: "Sources/Kalendario")
    ]
)