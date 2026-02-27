// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CautusRemote",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CautusRemote",
            targets: ["CautusRemote"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio-ssh.git", from: "0.12.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "CautusRemote",
            dependencies: [
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "src/cautus-remote",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "CautusRemoteTests",
            dependencies: ["CautusRemote"],
            path: "tests/unit-tests"
        ),
    ]
)
