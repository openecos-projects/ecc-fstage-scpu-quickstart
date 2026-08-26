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
├── docs/
│   ├── ecc-cli-guide.cn.md
│   └── ecc-fstage-scpu-tutorial.cn.md
└── runs/                    # ECC 生成的工作区，不纳入版本控制
```

## 1. 安装 ECC

ECC 要求 Python 3.11 或更高版本。推荐使用 `uv` 安装依赖；Nix 是可选的环境管理工具。
`ECC_ROOT` 必须指向 ECC 主仓库，而不是本快速上手仓库。先准备 ECC 主仓库并设置路径：

```bash
export ECC_ROOT=/path/to/ecc
cd "$ECC_ROOT"
```

如果还没有 ECC 主仓库，可以先克隆：

```bash
git clone https://github.com/openecos-projects/ecc.git "$ECC_ROOT"
cd "$ECC_ROOT"
```

### 方式 A：使用仓库开发环境

如果系统安装了 Nix，可以先进入开发 shell：

```bash
nix develop
```

没有 Nix 也可以跳过这一步，直接执行依赖同步：

```bash
uv sync --no-build-isolation-package ecc-dreamplace \
  --no-build-isolation-package ecc-tools-bin --verbose
```

同步完成后，用虚拟环境中的 ECC 验证安装：

```bash
uv run --project "$ECC_ROOT" ecc --version
```

如果希望激活虚拟环境后直接使用 `ecc`：

```bash
source .venv/bin/activate
ecc --version
```

### 方式 B（可选）：使用 ECC 主仓库的 release 环境

快速上手仓库本身不包含 `.envrc`。只有在 `ECC_ROOT` 指向 ECC 主仓库、且该主仓库
提供 `.envrc` 时，才需要安装 `direnv`：

```bash
cd "$ECC_ROOT"
test -f .envrc
direnv allow
direnv exec "$ECC_ROOT" ecc --version
```

如果没有 `.envrc` 或不想安装 `direnv`，跳过方式 B，使用方式 A 的
`uv run --project "$ECC_ROOT" ecc`。

### 不使用 direnv 的运行方式

方式 A 安装完成后，直接用 `uv run --project "$ECC_ROOT" ecc`，不需要 `direnv`：

```bash
cd "$ECC_ROOT/tutorials/ecc-fstage-scpu-quickstart"
uv run --project "$ECC_ROOT" ecc check --plain
uv run --project "$ECC_ROOT" ecc run --run-id first --plain
uv run --project "$ECC_ROOT" ecc status --run-id first --plain
```

### PDK

ECC 的 RTL 综合和后端流程需要 ICS55 PDK。设置 PDK 根目录：

```bash
export CHIPCOMPILER_ICS55_PDK_ROOT="$ECC_ROOT/pdk/icsprout55-pdk"
test -f "$CHIPCOMPILER_ICS55_PDK_ROOT/prtech/techLEF/N551P6M_ecos.lef"
```

完整依赖、PDK 和故障排查说明见
[ECC 指令列表与使用指南](docs/ecc-cli-guide.cn.md#1-安装与前置条件)。

## 2. 校验并运行

进入本目录后，项目路径可以省略。下面使用不依赖 `direnv` 的
`uv run --project "$ECC_ROOT" ecc`：

```bash
cd "$ECC_ROOT/tutorials/ecc-fstage-scpu-quickstart"

uv run --project "$ECC_ROOT" ecc check --plain
uv run --project "$ECC_ROOT" ecc run --run-id first --plain
uv run --project "$ECC_ROOT" ecc status --run-id first --plain
uv run --project "$ECC_ROOT" ecc log --run-id first
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
uv run --project "$ECC_ROOT" ecc check --plain
uv run --project "$ECC_ROOT" ecc run --run-id full --plain
uv run --project "$ECC_ROOT" ecc status --run-id full --plain
```

## 3. 继续学习

- [ECC 指令列表与使用指南](docs/ecc-cli-guide.cn.md)：完整 CLI、参数、输出格式和故障排查。
- [NPC 手把手教程](docs/ecc-fstage-scpu-tutorial.cn.md)：从读 RTL、写 filelist 到参数实验、报告分析和后端扩展。
- [项目配置](ecc.toml)：查看顶层模块、时钟频率、PDK 和流程预设。

`runs/` 下的内容由 ECC 生成。每次实验建议使用不同的 `--run-id`，不要覆盖已有结果。
当前工作区的 ECC `0.1.0a8` 在 `--workspace --only` 重跑场景存在已知路径恢复问题，
详见手把手教程第 8 节。
