// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NovaBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // 数据层：会话存储 + 用量接口
        .target(name: "NovaBarKit"),
        // 菜单栏应用
        .executableTarget(
            name: "NovaBar",
            dependencies: ["NovaBarKit"]
        ),
        // 命令行调试工具：只验证数据链路
        .executableTarget(
            name: "NovaBarCLI",
            dependencies: ["NovaBarKit"]
        ),
    ]
)
