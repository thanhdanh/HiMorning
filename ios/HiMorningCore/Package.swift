// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HiMorningCore", platforms: [.iOS("26.0"), .macOS(.v13)], products: [.library(name: "HiMorningCore", targets: ["HiMorningCore"])], targets: [.target(name: "HiMorningCore"), .testTarget(name: "HiMorningCoreTests", dependencies: ["HiMorningCore"])])
