// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "TaskProgress",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(
      name: "TaskProgress",
      targets: ["TaskProgress"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "TaskProgress",
      dependencies: []
    ),
    .executableTarget(
      name: "Example",
      dependencies: [
        "TaskProgress",
      ]
    )
  ]
)
