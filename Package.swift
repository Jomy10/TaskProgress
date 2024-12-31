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
  dependencies: [
    //.package(url: "https://github.com/Jomy10/SwiftCurses.git", branch: "master")
    .package(path: "../SwiftCurses"),
    .package(url: "https://github.com/swift-server/swift-backtrace.git", branch: "main"),
  ],
  targets: [
    .target(
      name: "TaskProgress",
      dependencies: [
        .product(name: "SwiftCurses", package: "SwiftCurses"),
      ]
    ),
    .executableTarget(
      name: "Example",
      dependencies: [
        "TaskProgress",
        .product(name: "SwiftCurses", package: "SwiftCurses"),
        .product(name: "Backtrace", package: "swift-backtrace"),
      ]
    )
  ]
)
