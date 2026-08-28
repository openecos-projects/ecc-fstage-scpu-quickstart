# ECC Fstage-scpu/NPC.sv 手把手教程

本教程只针对当前 `ecc-fstage-scpu-quickstart` 工程。所有命令默认在仓库根目录执行，
不需要切换到 ECC 源码仓库，也不需要配置 `.envrc` 或安装 `direnv`。

README 负责让用户快速跑通一次流程；本文负责解释这些命令背后的操作，并继续带读者
理解 RTL、`ecc.toml` 和 `runs/` 产物。

## 1. 工程结构

当前工程已经准备好 RTL、filelist 和 ECC 配置，不需要再复制或生成项目：

```text
ecc-fstage-scpu-quickstart/
├── ecc.toml
├── rtl/
│   ├── NPC.sv
│   └── NPC.f
├── constraints/
├── docs/
└── runs/
```

各文件的职责如下：

- `rtl/NPC.sv`：待综合的顶层 SystemVerilog，顶层模块名为 `NPC`。
- `rtl/NPC.f`：RTL filelist，目前只有一行 `NPC.sv`。
- `ecc.toml`：ECC 项目、PDK 和流程配置。
- `runs/`：ECC 生成的运行工作区，不是 RTL 源码目录。

## 2. README 命令流程详解

README 中的命令可以整段复制执行：

```bash
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh | sh -s -- --with-toolchain

ecc check --plain
ecc run --run-id first
ecc status --run-id first --plain
ecc log --run-id first
```

这不是四种不同的安装方式，而是一条有先后关系的流水线：

```text
安装依赖 -> 检查项目 -> 执行 RTL-to-GDS -> 查看状态和日志
```

### 2.1 安装 ECC、Yosys 和 ICS55 PDK

官方安装脚本会下载 ECC CLI、OSS CAD Suite（含 Yosys）和 ICS55 PDK，把包装脚本写到
`~/.local/bin/ecc`，数据放到 `~/.local/share/ecc/`。`--with-toolchain` 让包装脚本在
调用 `ecc` 时带上 PDK 和 OSS CAD Suite 路径，不必再 `source` 环境文件。

平台要求 Linux x86_64、glibc ≥ 2.34。若 `~/.local/bin` 不在 `PATH` 中，按安装脚本
提示加入后再运行 `ecc`。

默认先拉 GitHub，失败后自动改走 CNB。下载仓库：

- ECC：<https://cnb.cool/ecoslab/ecc>
- OSS CAD Suite：<https://cnb.cool/ecoslab/oss-cad-suite-build>
- ICS55 PDK：<https://cnb.cool/ecoslab/icsprout55-pdk>

GitHub 和 CNB 都失败时，再设前缀：

```bash
export ECC_GITHUB_BASE_URL=https://ghfast.top/https://github.com
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh | sh -s -- --with-toolchain
```

`ECC_GITHUB_BASE_URL` 只改写 `https://github.com/...`；CNB 地址不变。

安装完成后可以检查：

```bash
command -v ecc
ecc --version
```

该步骤只准备工具，不会创建 `runs/first/`。

### 2.2 `check`：验证项目输入

```bash
ecc check --plain
```


由于命令从仓库根目录执行，ECC 默认读取当前目录的 `ecc.toml`。检查过程会解析：

- `[design]`：顶层模块 `NPC`、时钟端口 `clock`、目标频率 `1000.0 MHz`；
- `rtl = ["rtl/NPC.f"]`：入口 filelist；
- `rtl/NPC.f`：其中的 `NPC.sv`，相对路径以 filelist 所在的 `rtl/` 目录为基准；
- `[pdk.overrides]`：technology LEF、标准单元 LEF 和 Liberty 文件；
- `[flow]`：当前使用的 `rtl2gds` 流程预设。

`check` 只检查配置、文件、PDK 和流程前置条件，不执行完整综合，也不会生成综合网表。
检查失败时先修复错误，再执行 `run`。`--plain` 只改变终端输出格式，不改变检查内容。

### 2.3 `run`：创建工作区并执行流程

```bash
ecc run --run-id first
```

不加 `--plain` 时，终端会实时显示当前步骤、日志摘要、完成状态和耗时；完整 RTL-to-GDS
流程通常需要等待一段时间，看到步骤名称持续变化即可确认流程仍在运行。

`--run-id first` 将本次实验命名为 `first`，结果写入 `runs/first/`。ECC 会：

1. 创建独立的运行目录；
2. 保存 `ecc.toml`、`NPC.f`、`NPC.sv` 等输入快照；
3. 写入解析后的设计参数、PDK 路径和流程状态；
4. 生成 Yosys 和后端步骤脚本，读取 RTL、展开顶层、执行综合、布局布线和 DRC；
5. 保存日志、脚本、综合网表、版图中间结果、GDS 和报告。

当前配置的 `flow.preset = "rtl2gds"` 会依次执行综合、布局布线、时钟树综合、DRC 和
填充单元等步骤。一次成功运行的主要目录如下：

```text
runs/first/
├── origin/                  # 本次运行使用的输入快照
├── home/                    # 参数和流程元数据
├── log/                     # ECC 总日志
├── Synthesis_yosys/         # Yosys 综合
├── Floorplan_ecc/           # Floorplan
├── fixFanout_ecc/           # 扇出修复
├── place_dreamplace/        # 布局
├── CTS_ecc/                 # 时钟树综合
├── legalization_dreamplace/ # 合法化
├── route_ecc/               # 布线
├── drc_ecc/                 # DRC
└── filler_ecc/              # 填充单元和最终 GDS
```

默认情况下，ECC 不会覆盖已经存在的 `runs/first/`。下一次实验使用新的 run id，能够
保留不同配置下的结果并进行比较。

### 2.4 `status`：读取步骤状态

```bash
ecc status --run-id first --plain
```

`status` 不会重新执行流程。它读取运行目录中的流程元数据，汇总运行是否完成，以及
`Synthesis` 等步骤的状态。运行时间较长时，可以重复执行此命令观察进度。

### 2.5 `log`：查看执行日志

```bash
ecc log --run-id first
```

`log` 读取已经生成的日志，不会修改工作区，也不会重新运行综合。遇到错误时，先用
`status` 找到失败步骤，再查看对应的 `runs/first/Synthesis_yosys/log/` 或顶层 `log/`。

## 3. 阅读 NPC.sv

打开 [rtl/NPC.sv](../rtl/NPC.sv)，先确认顶层模块和端口：

| 端口 | 方向 | 宽度 | 作用 |
| --- | --- | ---: | --- |
| `clock` | input | 1 | 时钟，触发时序逻辑 |
| `reset` | input | 1 | 复位条件 |
| `io_pc` | output | 8 | 当前 PC 值 |
| `io_inst` | input | 8 | 指令或控制输入 |
| `io_btn` | input | 8 | 按钮输入 |
| `io_sw` | input | 8 | 开关输入 |
| `io_led` | output | 8 | LED 数据 |
| `io_led_valid` | output | 1 | LED 输出有效标志 |
| `io_seg8` | output | 8 | 数码管数据 |
| `io_seg8_valid` | output | 1 | 数码管输出有效标志 |

建议按以下顺序阅读：

1. 搜索 `module NPC`，确认顶层名与 `ecc.toml` 的 `top = "NPC"` 一致。
2. 搜索 `always @(posedge clock)`，确认时钟端口确实是 `clock`。
3. 查看连续赋值和组合逻辑，了解输出如何由输入和内部寄存器产生。

这是 firtool 生成的 SystemVerilog，内部临时信号较多。第一次练习不需要重构 RTL，
先观察“RTL 输入 -> 综合 -> 布局布线 -> GDS”的完整闭环。

## 4. 理解 ecc.toml

当前配置的核心内容如下：

```toml
[design]
name = "fstage-scpu-quickstart"
top = "NPC"
rtl = ["rtl/NPC.f"]
clock_port = "clock"
frequency_mhz = 1000.0

[pdk]
name = "ics55"
root = ""

[flow]
preset = "rtl2gds"
run = "default"
```

字段和实际工程的关系：

- `top` 必须与 `NPC.sv` 的 `module NPC` 完全一致。
- `rtl` 使用 filelist 作为入口，后续可在 `NPC.f` 中加入更多 RTL 文件。
- `clock_port` 对应 RTL 的 `clock` 输入端口。
- `frequency_mhz` 是时序约束目标，不代表设计一定达到该频率。
- `pdk.root = ""` 表示使用安装脚本设置的 ICS55 PDK 环境。
- `rtl2gds` 会从 RTL 一直执行到布局布线和 GDS 输出。

`[pdk.overrides]` 进一步列出标准单元 LEF、Liberty 和 `dont_use` 单元。它们使用环境
变量拼接路径，因此不需要把某台机器上的绝对路径写入配置。

修改配置后，始终先运行：

```bash
ecc check --plain
```

## 5. 查看 RTL-to-GDS 结果

README 流程完成后，先确认状态：

```bash
ecc status --run-id first --plain
```

然后查看实际生成的 GDS 和其他产物：

```bash
find runs/first -type f \( -iname '*.gds' -o -iname '*.gds.gz' \) -print | sort
```

重点关注：

```text
runs/first/Synthesis_yosys/output/*_Synthesis.v.gz
runs/first/Synthesis_yosys/output/*_Synthesis_sim.v.gz
runs/first/Synthesis_yosys/report/Synthesis_check.rpt
runs/first/Synthesis_yosys/feature/Synthesis_stat.json
runs/first/filler_ecc/output/*_filler.gds
```

文件名会随 ECC 版本和配置细节变化；目录和后缀比完整文件名更稳定。若安装了 `jq`，
可以读取综合统计：

```bash
jq . runs/first/Synthesis_yosys/feature/Synthesis_stat.json
```

如果综合、布局、时钟树、布线、DRC 和填充步骤均显示 `Success`，并且最终输出目录中
存在非空 `.gds` 文件，说明 RTL-to-GDS 闭环已完成。最终 GDS 通常位于：

```text
runs/first/filler_ecc/output/*_filler.gds
```

`*_Synthesis_sim.v.gz` 仍然只是网表级仿真输入；GDS 是 `filler_ecc/output/` 中的版图文件。

## 6. 做一次独立实验

不要覆盖已经成功的 `first`。修改 `ecc.toml` 中的频率后，先检查，再使用新的 run id：

```bash
ecc check --plain
ecc run --run-id freq800 --plain
ecc status --run-id freq800 --plain
```

这样可以比较：

- `runs/first/` 与 `runs/freq800/` 中的参数快照；
- 两个运行的 `Synthesis_stat.json`；
- 两个运行的检查报告和日志。

每个 run 都保存自己的输入快照，因此后续修改 RTL 或配置不会改变已经完成的实验记录。

## 7. 常见问题

### `ecc: command not found`

包装脚本在 `~/.local/bin/ecc`。把它加入 `PATH` 后再试：

```bash
export PATH="$HOME/.local/bin:$PATH"
command -v ecc
ecc --version
```

若文件不存在，重新安装：

```bash
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh | sh -s -- --with-toolchain
```

### `check` 找不到 RTL

确认当前目录是仓库根目录，并检查 filelist：

```bash
pwd
cat rtl/NPC.f
test -f rtl/NPC.sv
```

`NPC.f` 中的 `NPC.sv` 是相对于 `rtl/` 目录解析的，不能改成依赖其他机器绝对路径的写法。

### PDK 文件不存在

`--with-toolchain` 安装后，包装脚本会设置 `CHIPCOMPILER_ICS55_PDK_ROOT`。


若缺少 PDK 文件，用同一条安装命令再跑一次。

### `Yosys executable not found`

确认安装时加了 `--with-toolchain`。包装脚本会在运行 `ecc` 时设置
`CHIPCOMPILER_OSS_CAD_DIR`，不要依赖当前 shell 里的 `YOSYS_ROOT`。

若仍缺少 Yosys，重新执行：

```bash
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh | sh -s -- --with-toolchain
```

### `runs/first` 已存在

不要直接删除已有结果。使用新的 run id，例如 `first-rerun`，保留两次实验的可比性：

```bash
ecc run --run-id first-rerun --plain
```

## 8. 后续阅读

- [ECC 指令列表与使用指南](ecc-cli-guide.cn.md)：查看更多 CLI 命令和输出格式。
- [README](../README.md)：只包含最短可复制流程。
- [ecc.toml](../ecc.toml)：查看当前项目的完整配置。
