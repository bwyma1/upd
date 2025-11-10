// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "upd",
	platforms:[
		.macOS(.v15)
	],
    products: [
        .executable(
            name: "upd",
            targets: ["upd"]
        ),
    ],
	dependencies:[
		.package(url:"https://github.com/apple/swift-argument-parser.git", "1.6.1"..<"2.0.0"),
		.package(url:"https://github.com/tannerdsilva/rawdog.git", "20.0.0"..<"21.0.0"),
		.package(url:"https://github.com/tannerdsilva/bedrock.git", "7.0.1"..<"8.0.0"),
		.package(url:"https://github.com/tannerdsilva/QuickLMDB.git", "14.0.0"..<"14.1.0"),
		.package(url:"https://github.com/tannerdsilva/wireguard-swift", revision:"b55e6613c6b9c1a8a2c4881b104334ce6e107740"),
//		.package(url:"https://github.com/tannerdsilva/SwiftSlash.git", revision:"d83d6fc6d54ffec2a631a96a095dee1861165844")
//		.package(path: "../Forks/SwiftSlash")
	],
targets: [
		.executableTarget(
            name: "upd",
			dependencies: [.product(name:"ArgumentParser", package:"swift-argument-parser"),
						   .product(name:"RAW_base64", package:"rawdog"),
						   .product(name:"bedrock", package:"bedrock"),
						   .product(name:"bedrock_fifo", package:"bedrock"),
						   .product(name:"QuickLMDB", package:"QuickLMDB"),
						   .product(name:"wireguard-userspace-nio", package:"wireguard-swift"),
//						   .product(name: "SwiftSlash", package: "SwiftSlash")
			],
			resources: [
				.process(".env")
			]
        ),
        .testTarget(
            name: "updTests",
            dependencies: ["upd"]
        ),
    ]
)
