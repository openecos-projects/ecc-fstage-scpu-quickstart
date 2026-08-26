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
并在当前终端准备好运行环境。

```bash
source scripts/install-release-deps.sh

"$ECC_BIN" check --plain
"$ECC_BIN" run --run-id first --plain
"$ECC_BIN" status --run-id first --plain
"$ECC_BIN" log --run-id first
```

## 结果

运行结果保存在 `runs/first/`。成功时，`Synthesis` 步骤为 `Success`，并生成综合网表
和报告：

```text
runs/first/Synthesis_yosys/
├── output/*_Synthesis.v.gz
├── output/*_Synthesis_sim.v.gz
├── report/Synthesis_check.rpt
└── feature/Synthesis_stat.json
```

## 继续学习

- [ECC 指令列表与使用指南](docs/ecc-cli-guide.cn.md)：完整 CLI、参数、输出格式和故障排查。
- [NPC 手把手教程](docs/ecc-fstage-scpu-tutorial.cn.md)：从读 RTL、写 filelist 到参数实验、报告分析和后端扩展。
