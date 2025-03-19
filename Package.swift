// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorAdyen",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "CapacitorAdyen",
            targets: ["AdyenPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "6.1.1")
    ],
    targets: [
        .target(
            name: "AdyenPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/AdyenPlugin"),
        .testTarget(
            name: "AdyenPluginTests",
            dependencies: ["AdyenPlugin"],
            path: "ios/Tests/AdyenPluginTests")
    ]
)
