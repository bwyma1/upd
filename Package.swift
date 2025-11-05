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
		.package(url:"https://github.com/tannerdsilva/rawdog.git", "20.0.0"..<"21.0.0"),
		.package(url:"https://github.com/tannerdsilva/bedrock.git", "7.0.1"..<"8.0.0"),
		 .package(url:"https://github.com/tannerdsilva/wireguard-swift", revision:"06109227446adcaae47cb23758cdc1568087e945"),
//		.package(path: "../wireguard-swift"),
		.package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.2.0")),
		.package(url:"https://github.com/apple/swift-argument-parser.git", "1.6.1"..<"2.0.0"),
		.package(url:"https://github.com/tannerdsilva/QuickLMDB.git", "14.0.0"..<"14.1.0"),
//		.package(path: "../SwiftSlash")
		.package(url:"https://github.com/tannerdsilva/SwiftSlash.git", "4.0.1"..<"5.0.0")
	],
targets: [
		.executableTarget(
            name: "upd",
			dependencies: [.product(name:"wireguard-userspace-nio", package:"wireguard-swift"),
						   .product(name:"QuickLMDB", package:"QuickLMDB"),
						   .product(name:"bedrock", package:"bedrock"),
						   .product(name:"bedrock_fifo", package:"bedrock"),
						   .product(name:"RAW_base64", package:"rawdog"),
						   .product(name:"ArgumentParser", package:"swift-argument-parser"),
						   .product(name:"Configuration", package: "swift-configuration"),
						   //.product(name:"SwiftSlash", package:"SwiftSlash")
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
