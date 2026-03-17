// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CPUDesktopWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CPUDesktopWidget",
            targets: ["CPUDesktopWidget"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CPUDesktopWidget",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
