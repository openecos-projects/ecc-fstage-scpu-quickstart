# ECC Fstage-scpu 快速上手

这是一个自包含的 ECC 入门项目，使用仓库中的
[`Fstage-scpu/NPC.sv`](rtl/NPC.sv) 作为顶层 RTL 设计。

## 目录结构

```text
ecc-fstage-scpu-quickstart/
├── README.cn.md
├── ecc.toml                 # 可直接运行的 ECC 项目配置
├── rtl/
│   ├── NPC.sv               # 顶层 module NPC
│   └── NPC.f                # RTL filelist
├── constraints/             # 约束扩展目录
├── docs/
│   ├── ecc-cli-guide.cn.md
│   └── ecc-fstage-scpu-tutorial.cn.md
└── runs/                    # ECC 生成的工作区，不纳入版本控制
```

## 1. 准备环境

在 ECC 主仓库中启用开发环境：

```bash
export ECC_ROOT=/path/to/ecc
cd "$ECC_ROOT"
direnv allow
ecc --version
```

如果没有自动加载 `ecc`，可以把后续命令中的 `ecc` 替换为：

```bash
direnv exec "$ECC_ROOT" ecc
```

确认 ICS55 PDK 可用。当前配置默认从环境变量读取 PDK 根目录：

```bash
export CHIPCOMPILER_ICS55_PDK_ROOT="$ECC_ROOT/pdk/icsprout55-pdk"
test -f "$CHIPCOMPILER_ICS55_PDK_ROOT/prtech/techLEF/N551P6M_ecos.lef"
```

## 2. 校验并运行

进入本目录后，项目路径可以省略：

```bash
cd "$ECC_ROOT/tutorials/ecc-fstage-scpu-quickstart"

ecc check --plain
ecc run --run-id first --plain
ecc status --run-id first --plain
ecc log --run-id first
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
ecc check --plain
ecc run --run-id full --plain
ecc status --run-id full --plain
```

## 3. 继续学习

- [ECC 指令列表与使用指南](docs/ecc-cli-guide.cn.md)：完整 CLI、参数、输出格式和故障排查。
- [NPC 手把手教程](docs/ecc-fstage-scpu-tutorial.cn.md)：从读 RTL、写 filelist 到参数实验、报告分析和后端扩展。
- [项目配置](ecc.toml)：查看顶层模块、时钟频率、PDK 和流程预设。

`runs/` 下的内容由 ECC 生成。每次实验建议使用不同的 `--run-id`，不要覆盖已有结果。
当前工作区的 ECC `0.1.0a8` 在 `--workspace --only` 重跑场景存在已知路径恢复问题，
详见手把手教程第 8 节。
