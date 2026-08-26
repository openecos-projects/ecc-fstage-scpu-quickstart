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

## 1. 基于 ECC release 的最短流程

如果只是想运行 ECC，不需要编译源码。当前推荐的 Linux x86_64 release 是
`v0.1.0-alpha.10`。release 包本身只提供 ECC CLI，本教程提供脚本自动下载匹配的
Yosys 和 ICS55 PDK。

### 1.1 一键下载全部依赖

在本目录执行下面一条命令。默认下载约 1.5 GB 文件，依赖会放在 `.ecc-deps/`，不会写入
Git；脚本可以重复执行，已完成的下载会复用。

```bash
source scripts/install-release-deps.sh
```

脚本完成后会自动设置 `ECC_BIN`、`YOSYS_ROOT`、`CHIPCOMPILER_OSS_CAD_DIR`、
`YOSYS_PLUGINPATH` 和 `CHIPCOMPILER_ICS55_PDK_ROOT`。如果脚本是直接执行而不是
`source`，请按提示加载 `.ecc-release-env`。

如需更换版本，可以在执行前覆盖脚本变量，例如：

```bash
ECC_VERSION=v0.1.0-alpha.10 \
YOSYS_RELEASE_TAG=2026-08-08 \
YOSYS_RELEASE_DATE=20260808 \
PDK_VERSION=v1.10.102 \
source scripts/install-release-deps.sh
```

更换 ECC 版本时，请同时设置该版本 release 页面提供的 `ECC_SHA256`；否则脚本会提示
并跳过 ECC 压缩包校验。

### 1.2 准备本教程项目

`QUICKSTART_ROOT` 是本快速上手仓库的路径，不是 ECC 源码路径：

```bash
QUICKSTART_ROOT=/path/to/ecc-fstage-scpu-quickstart
cd "$QUICKSTART_ROOT"
```

下一节会运行设计并检查结果。

更多命令和输出格式见 [ECC 指令列表与使用指南](docs/ecc-cli-guide.cn.md)。

## 2. 校验并运行

完成上面的 release 配置后，可以继续使用同一个 `ECC_BIN` 变量运行项目：

```bash
cd "$QUICKSTART_ROOT"

"$ECC_BIN" check --plain
"$ECC_BIN" run --run-id first --plain
"$ECC_BIN" status --run-id first --plain
"$ECC_BIN" log --run-id first
```

预期结果是 `Synthesis` 步骤成功，并在以下目录生成综合网表和报告：

```text
runs/first/Synthesis_yosys/
├── output/*_Synthesis.v.gz
├── output/*_Synthesis_sim.v.gz
├── report/Synthesis_check.rpt
└── feature/Synthesis_stat.json
```

配置使用 `syn_sta` 预设，第一次练习重点是综合和网表级检查。需要尝试完整后端时，
将 `ecc.toml` 的 `[flow]` 改为：

```toml
[flow]
preset = "rtl2gds"
run = "full"
```

然后使用新的运行名：

```bash
"$ECC_BIN" check --plain
"$ECC_BIN" run --run-id full --plain
"$ECC_BIN" status --run-id full --plain
```

## 3. 继续学习

- [ECC 指令列表与使用指南](docs/ecc-cli-guide.cn.md)：完整 CLI、参数、输出格式和故障排查。
- [NPC 手把手教程](docs/ecc-fstage-scpu-tutorial.cn.md)：从读 RTL、写 filelist 到参数实验、报告分析和后端扩展。
- [项目配置](ecc.toml)：查看顶层模块、时钟频率、PDK 和流程预设。

`runs/` 下的内容由 ECC 生成。每次实验建议使用不同的 `--run-id`，不要覆盖已有结果。
当前工作区的 ECC `0.1.0a8` 在 `--workspace --only` 重跑场景存在已知路径恢复问题，
详见手把手教程第 8 节。
