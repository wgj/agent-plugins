// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ContactsCLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ContactsCore", targets: ["ContactsCore"]),
        .executable(name: "contacts-cli", targets: ["ContactsCLI"]),
        .executable(name: "contacts-cli-smoke-tests", targets: ["ContactsCLISmokeTests"])
    ],
    targets: [
        .target(name: "ContactsCore"),
        .executableTarget(
            name: "ContactsCLI",
            dependencies: ["ContactsCore"]
        ),
        .executableTarget(
            name: "ContactsCLISmokeTests",
            dependencies: ["ContactsCore"]
        )
    ]
)
