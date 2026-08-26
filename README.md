# ECC Fstage-scpu 快速上手

这是一个自包含的 ECC 入门项目，使用仓库中的
[`Fstage-scpu/NPC.sv`](rtl/NPC.sv) 作为顶层 RTL 设计。

## 目录结构

```text
ecc-fstage-scpu-quickstart/
├── README.md
├── ecc.toml                 # 可直接运行的 ECC 项目配置
├── rtl/
│   ├── NPC.sv               # 顶层 module NPC
│   └── NPC.f                # RTL filelist
├── constraints/             # 约束扩展目录
├── scripts/
│   └── install-release-deps.sh # 一键下载 ECC、Yosys 和 ICS55 PDK
├── docs/
│   ├── ecc-cli-guide.cn.md
│   └── ecc-fstage-scpu-tutorial.cn.md
└── runs/                    # ECC 生成的工作区，不纳入版本控制
```

## 使用流程

以下命令均在本仓库根目录执行。安装脚本会下载 ECC release、Yosys 和 ICS55 PDK，
并在当前终端准备好运行环境。安装脚本支持 Bash 和 Zsh。

```bash
source scripts/install-release-deps.sh

"$ECC_BIN" check --plain
"$ECC_BIN" run --run-id first
"$ECC_BIN" status --run-id first --plain
"$ECC_BIN" log --run-id first
```

默认从 GitHub 下载。GitHub 连接较慢时，可以让所有 GitHub 下载和 PDK 克隆通过
gh-proxy：

```bash
source scripts/install-release-deps.sh --download-source gh-proxy
```

切回直连时使用 `--download-source github`。自定义代理地址时追加
`--gh-proxy-url https://example.com/`。也可以通过 `ECC_DOWNLOAD_SOURCE` 和
`GH_PROXY_URL` 环境变量配置；命令行参数的优先级更高。

## 结果

运行结果保存在 `runs/first/`。成功时，综合、布局布线和 DRC 等步骤均为 `Success`，并
生成最终 GDS：

```text
runs/first/
├── Synthesis_yosys/output/*_Synthesis.v.gz
├── Floorplan_ecc/output/*_Floorplan.gds
├── route_ecc/output/*_route.gds
└── filler_ecc/output/*_filler.gds  # 最终 GDS
```

## 继续学习

- [ECC 指令列表与使用指南](docs/ecc-cli-guide.cn.md)：完整 CLI、参数、输出格式和故障排查。
- [NPC 手把手教程](docs/ecc-fstage-scpu-tutorial.cn.md)：从读 RTL、写 filelist 到参数实验、报告分析和后端扩展。
