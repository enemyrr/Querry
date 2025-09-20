// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConvexMobile",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ConvexMobile",
            targets: ["ConvexMobile"]
        )
    ],
    targets: [
        .target(
            name: "ConvexMobile",
            path: "Sources/ConvexMobile"
        )
    ]
)


