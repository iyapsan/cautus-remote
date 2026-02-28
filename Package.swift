// swift-tools-version: 6.0
import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #file).deletingLastPathComponent().path

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
        .target(
            name: "CRDPBridge",
            path: "Sources/CRDPBridge",
            cSettings: [
                .unsafeFlags(["-Iout/include/freerdp3"]),
                .unsafeFlags(["-Iout/include/winpr3"]),
                .unsafeFlags(["-I/opt/homebrew/opt/openssl@3/include"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Lout/lib",
                    "-Lout/lib/freerdp3",
                    "-L/opt/homebrew/opt/openssl@3/lib",
                    "-L/opt/homebrew/opt/cjson/lib"
                ]),
                .linkedLibrary("freerdp-client3"),
                .linkedLibrary("freerdp3"),
                .linkedLibrary("winpr3"),
                .linkedLibrary("winpr-tools3"),
                .linkedLibrary("rdpsnd-common"),
                .linkedLibrary("remdesk-common"),
                .linkedLibrary("ssl"),
                .linkedLibrary("crypto"),
                .linkedLibrary("cjson"),
                .linkedLibrary("z"),
                .unsafeFlags([
                    "-framework", "CoreFoundation",
                    "-framework", "Foundation",
                    "-framework", "Cocoa",
                    "-framework", "Security",
                    "-framework", "SystemConfiguration",
                    "-framework", "IOKit"
                ])
            ]
        ),
        .target(
            name: "CautusRDP",
            dependencies: ["CRDPBridge"],
            path: "Sources/CautusRDP"
        ),
        .executableTarget(
            name: "CautusRDPTest",
            dependencies: ["CautusRDP"],
            path: "Sources/CautusRDPTest"
        ),
        .executableTarget(
            name: "CautusRemote",
            dependencies: [
                .product(name: "NIOSSH", package: "swift-nio-ssh"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ],
            path: "Sources/CautusRemote",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "CautusRemoteTests",
            dependencies: ["CautusRemote"],
            path: "Tests/CautusRemoteTests"
        ),
    ]
)
