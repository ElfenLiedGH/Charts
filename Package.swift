// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "ChartsEL",
    platforms: [
          .iOS(.v9),
          .tvOS(.v9),
          .macOS(.v10_11),
    ],
    products: [
        .library(
            name: "ChartsEL",
            targets: ["ChartsEL"]),
    ],
    targets: [
        .target(name: "ChartsEL")
    ],
    swiftLanguageVersions: [.v5]
)
