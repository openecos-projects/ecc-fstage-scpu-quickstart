# 用 Fstage-scpu/NPC.sv 完成第一次 ECC 流程

这是一份面向初学者的实操教程。我们把
[NPC.sv](../rtl/NPC.sv) 作为待综合设计，从环境检查开始，
创建一个独立 ECC 项目，完成配置校验和综合，再学习如何查看日志、配置和产物。

本文中的 `ECC_ROOT` 表示 ECC 仓库根目录，请先替换为你的实际路径：

```bash
export ECC_ROOT=/path/to/ecc
```

教程假设仓库路径为：

```text
$ECC_ROOT
```

当前工作区已经提供了同一设计的参考项目
`evaluations/fstage-scpu`；教程会复制输入和配置到新的练习目录，不会修改已有
评估结果。

如果你是从 `ecc-fstage-scpu-quickstart` 仓库开始，配置和 RTL 已经在仓库根目录中，
可以跳过第 3 节的复制步骤，直接从第 4 节检查 `ecc.toml`。

## 0. 你将完成什么

完成后应能做到：

1. 识别 RTL 顶层模块和时钟端口。
2. 用 filelist 把 `NPC.sv` 交给 ECC。
3. 写出最小可用的 `ecc.toml`。
4. 运行 `ecc check` 和 `ecc run`。
5. 查看运行状态、日志、解析配置和综合网表。
6. 修改一个参数并在独立 run 中比较结果。
7. 在已有工作区中只重跑一个步骤。

本教程默认使用 `syn_sta` 预设。它首先执行 Yosys 综合，并尽力生成网表级 STA
报告；要执行布局布线和 GDS 生成，见第 9 节。

## 1. 先读懂 NPC.sv

打开源文件：

```bash
cd "$ECC_ROOT"
vi RTL/ysyx-cores/Fstage-scpu/NPC.sv
```

文件是 CIRCT firtool 生成的 SystemVerilog，顶层模块为 `NPC`。接口如下：

| 端口 | 方向 | 宽度 | 作用 |
| --- | --- | ---: | --- |
| `clock` | input | 1 | 时钟，触发时序逻辑 |
| `reset` | input | 1 | 高电平复位条件 |
| `io_pc` | output | 8 | 当前 PC 值 |
| `io_inst` | input | 8 | 指令/控制输入 |
| `io_btn` | input | 8 | 按钮输入 |
| `io_sw` | input | 8 | 开关输入 |
| `io_led` | output | 8 | LED 数据 |
| `io_led_valid` | output | 1 | LED 输出有效标志 |
| `io_seg8` | output | 8 | 数码管数据 |
| `io_seg8_valid` | output | 1 | 数码管输出有效标志 |

阅读时先找三个位置：

- `module NPC(...)`：确认顶层端口和端口方向。
- `always @(posedge clock)`：确认时序逻辑使用的时钟。
- `assign io_pc = _GEN_3` 等连续赋值：确认顶层输出从哪些内部信号产生。

这个设计没有实例化其他模块，因此一个 RTL 文件就足够综合。`_GEN_3` 在时钟沿
更新并在 `reset` 条件下清零；LED 和数码管输出则由组合逻辑根据
`io_inst`、`io_btn` 和 `io_sw` 产生。由于文件是生成代码，不建议初学时直接
重构其中的内部临时信号；先把它作为 ECC 的输入，建立“配置--运行--检查结果”的
完整闭环。

## 2. 检查工具和 PDK

### 2.1 不使用 direnv（推荐）

快速上手仓库不包含 `.envrc`，也不要求安装 `direnv`。在 ECC 主仓库中同步依赖：

```bash
cd "$ECC_ROOT"
nix develop
uv sync --no-build-isolation-package ecc-dreamplace \
  --no-build-isolation-package ecc-tools-bin --verbose
uv run --project "$ECC_ROOT" ecc --version
```

如果没有 Nix，可以跳过 `nix develop`。后续命令把 `ecc` 替换为
`uv run --project "$ECC_ROOT" ecc` 即可。

### 2.2 可选：使用 ECC 主仓库的 release 环境

只有在 `ECC_ROOT` 指向包含 `.envrc` 的 ECC 主仓库时，才使用该方式：

```bash
cd "$ECC_ROOT"
test -f .envrc
direnv allow
direnv exec "$ECC_ROOT" ecc --version
```

如果没有 `.envrc`，回到 2.1 节使用 `uv run --project "$ECC_ROOT" ecc`。

### 2.3 检查 ICS55 PDK

```bash
export CHIPCOMPILER_ICS55_PDK_ROOT="$ECC_ROOT/pdk/icsprout55-pdk"

test -f "$CHIPCOMPILER_ICS55_PDK_ROOT/prtech/techLEF/N551P6M_ecos.lef"
test -d "$CHIPCOMPILER_ICS55_PDK_ROOT/IP/STD_cell"
```

两个 `test` 都没有输出且退出码为 0，表示基础路径存在。ECC 的内建
`ics55` PDK 会从该目录寻找 technology LEF、标准单元 LEF 和 Liberty 文件。

## 3. 从 ECC 主仓库创建一个干净的练习项目

不要直接在 `evaluations/fstage-scpu` 下运行教程，因为那里已经有历史
`runs` 和面积 sweep 结果。创建新目录并复制必要输入：

```bash
cd "$ECC_ROOT"

TUTORIAL_DIR="$PWD/tutorials/fstage-scpu"
mkdir -p "$TUTORIAL_DIR/rtl" "$TUTORIAL_DIR/constraints" "$TUTORIAL_DIR/runs"

cp RTL/ysyx-cores/Fstage-scpu/NPC.sv \
  "$TUTORIAL_DIR/rtl/NPC.sv"

printf '%s\n' 'NPC.sv' > "$TUTORIAL_DIR/rtl/NPC.f"

cp evaluations/fstage-scpu/ecc.toml "$TUTORIAL_DIR/ecc.toml"
sed -i 's/name = "fstage-scpu"/name = "fstage-scpu-tutorial"/' \
  "$TUTORIAL_DIR/ecc.toml"
```

此时目录应为：

```text
tutorials/fstage-scpu/
├── ecc.toml
├── constraints/
├── rtl/
│   ├── NPC.f
│   └── NPC.sv
└── runs/
```

`NPC.f` 只有一行，且路径相对于项目目录：

```text
NPC.sv
```

filelist 中的相对路径以 filelist 所在目录为基准。使用 filelist 的好处是以后可以逐行加入更多 RTL 文件或 `+incdir+...`；ECC
仍然把 `NPC` 作为顶层模块。

## 4. 理解并检查 ecc.toml

复制得到的配置与仓库中已验证的 Fstage-scpu 配置一致。打开它：

```bash
vi "$TUTORIAL_DIR/ecc.toml"
```

关键部分如下：

```toml
[design]
name = "fstage-scpu-tutorial"
top = "NPC"
rtl = ["rtl/NPC.f"]
clock_port = "clock"
frequency_mhz = 1000.0

[pdk]
name = "ics55"
root = ""

[flow]
preset = "syn_sta"
run = "default"
```

逐项理解：

- `top = "NPC"` 必须与源文件中的 `module NPC` 完全一致。
- `rtl` 只列出一个入口，这里入口是 filelist。
- `clock_port = "clock"` 对应 RTL 的时钟端口；拼写错误会导致校验或后续约束失败。
- `frequency_mhz = 1000.0` 是目标频率。它是时序约束输入，不代表设计一定能达到
  1 GHz。
- `pdk.root = ""` 表示使用环境变量 `CHIPCOMPILER_ICS55_PDK_ROOT` 或
  `ICS55_PDK_ROOT`。
- `flow.preset` 为 `syn_sta`，让第一次练习集中在综合和网表级检查。

配置后半段的 `[pdk.overrides]` 指定 ICS55 的 LEF、Liberty 和
`dont_use` 单元列表。不要随意删除这些路径；它们是参考项目能够稳定运行的关键。
如果 PDK 安装在其他位置，优先修改环境变量，而不是把每个路径改成绝对路径。

执行校验：

```bash
ecc check --project "$TUTORIAL_DIR" --plain
```

成功时应看到项目状态为 `checked`，并有一条 `check=rtl status=pass` 记录。常见
失败和处理方式：

| 输出 | 原因 | 处理 |
| --- | --- | --- |
| `missing_config` | 找不到 `ecc.toml` | 确认 `--project` 指向练习目录 |
| `rtl path does not exist` | filelist 或其中的文件路径错误 | 在项目目录执行 `cat rtl/NPC.f` 并检查文件存在 |
| `pdk.root is not a directory` | PDK 环境变量为空或路径错误 | 重新 export PDK 根目录 |
| `PDK has no LEF/liberty files` | PDK 未解压完整 | 检查 `IP/STD_cell` 和 `prtech/techLEF` |

## 5. 第一次运行：只做综合和 STA

为这次运行取一个独立的 run id：

```bash
ecc run \
  --project "$TUTORIAL_DIR" \
  --run-id first \
  --plain
```

ECC 会创建：

```text
tutorials/fstage-scpu/runs/first/
├── home/
├── origin/
├── config/
├── log/
└── Synthesis_yosys/
```

其中：

- `origin/NPC.sv` 和 `origin/NPC.f` 是复制进工作区的输入快照。
- `home/flow.json` 记录步骤状态、运行时间和内存峰值。
- `home/parameters.json` 记录 PDK、顶层、时钟和解析后的设计参数。
- `Synthesis_yosys/script/` 保存 Yosys 脚本。
- `Synthesis_yosys/log/` 保存综合日志。
- `Synthesis_yosys/output/` 保存压缩网表等输出。
- `Synthesis_yosys/report/` 保存综合检查和统计报告。

查看状态：

```bash
ecc status --project "$TUTORIAL_DIR" --run-id first --plain
ecc log --project "$TUTORIAL_DIR" --run-id first
```

查看解析配置：

```bash
ecc config --project "$TUTORIAL_DIR" --run-id first \
  --resolved --json
```

`syn_sta` 的最小成功标准是 `Synthesis` 步骤为 `Success`，并且
`Synthesis_yosys/output/` 下有非空网表。可以直接检查：

```bash
find "$TUTORIAL_DIR/runs/first/Synthesis_yosys" \
  -maxdepth 3 -type f -printf '%p\n' | sort
```

常见输出包括：

```text
fstage-scpu-tutorial_Synthesis.v.gz
fstage-scpu-tutorial_Synthesis_sim.v.gz
```

实际文件名以当前 ECC 版本和配置为准。STA 报告如果生成，通常位于
`Synthesis_yosys/feature/post_synthesis/` 或报告目录；用 `find` 查找比假设
固定文件名更稳妥。

## 6. 观察综合结果

### 6.1 读取 Yosys 统计

```bash
find "$TUTORIAL_DIR/runs/first/Synthesis_yosys" \
  -iname '*stat*' -o -iname '*qor*' -o -iname '*.rpt'
```

常见文件：

- `feature/Synthesis_stat.json`：单元数量、面积等统计。
- `feature/Synthesis.step.json`：步骤状态、运行时长和峰值内存。
- `report/Synthesis_stat.json`：可读的综合统计。
- `report/Synthesis_check.rpt`：网表检查报告。

如果安装了 jq：

```bash
jq . "$TUTORIAL_DIR/runs/first/Synthesis_yosys/feature/Synthesis_stat.json"
```

### 6.2 对照 RTL 规模

`NPC.sv` 只有一个顶层模块、若干 8 位寄存器和组合逻辑，因此它适合观察“RTL
变化如何影响综合统计”，但不代表一个完整 CPU 的物理实现规模。后续可以复制该项目
并尝试：

- 修改 `design.frequency_mhz`，观察时序报告变化。
- 在 `NPC.sv` 中增加一个寄存器或组合运算，比较 cell 数量和面积。
- 将更多阶段的 NPC filelist 作为独立项目，比较不同设计复杂度。

任何 RTL 修改后都应先重新执行 `ecc check`，再使用新的 `--run-id`，以保留
可比较的历史结果。

## 7. 做一次参数实验

参数有两种修改方式。

### 7.1 临时覆盖：推荐用于实验

不会改写 `ecc.toml`：

```bash
ecc run \
  --project "$TUTORIAL_DIR" \
  --run-id freq800 \
  --set design.frequency_mhz=800 \
  --plain

ecc status --project "$TUTORIAL_DIR" --run-id freq800 --plain
```

覆盖值会写入该 run 的 `home/cli-param-overrides.json`。比较两个 run 时，分别
查看它们的 `home/parameters.json` 和综合报告。

### 7.2 持久覆盖：用于确定项目默认值

```bash
ecc param set --project "$TUTORIAL_DIR" \
  design.frequency_mhz 800

ecc param show --project "$TUTORIAL_DIR" design.frequency_mhz
ecc param diff --project "$TUTORIAL_DIR"

# 恢复默认值
ecc param unset --project "$TUTORIAL_DIR" design.frequency_mhz
```

`param set` 会直接编辑 `ecc.toml`，因此教程建议在确认实验结果后再使用。

## 8. 重跑一个已有步骤

项目模式下已有 run 不会自动覆盖。对于支持工作区重跑的 ECC 版本，可以只重跑工作区
中的综合步骤：

```bash
ecc run \
  --workspace "$TUTORIAL_DIR/runs/first" \
  --only Synthesis \
  --force \
  --plain
```

说明：

- `--workspace` 模式直接复用已有工作区。
- `--only Synthesis` 只选择综合步骤；步骤名以 `home/flow.json` 为准。
- `--force` 允许重新执行已经成功的步骤。
- 重跑会更新该步骤的输出，并使依赖它的下游步骤回到未完成状态。

从第一个未完成步骤继续：

```bash
ecc run --workspace "$TUTORIAL_DIR/runs/first" --resume --plain
```

注意：当前工作区随附的 ECC `0.1.0a8` 已知可能在该命令中丢失原始 RTL/filelist
路径，并报出 `Neither RTL_FILE () nor filelist () exists`。这不是 `NPC.sv` 的
语法错误；在该版本中建议用新的 run id 重新执行项目模式：

```bash
ecc run --project "$TUTORIAL_DIR" --run-id first-rerun --plain
```

升级到包含 workspace rerun 修复的 ECC 版本后，再使用 `--workspace` 形式进行单步
重跑，并先用 `ecc --version` 记录版本。

## 9. 可选：扩展到完整 RTL-to-GDS

`syn_sta` 适合第一次建立闭环。若要尝试完整后端，可把练习项目的
`ecc.toml` 改为：

```toml
[flow]
preset = "rtl2gds"
run = "full"
```

先校验，再使用新的 run id：

```bash
ecc check --project "$TUTORIAL_DIR" --plain
ecc run --project "$TUTORIAL_DIR" --run-id full --plain
ecc status --project "$TUTORIAL_DIR" --run-id full --plain
```

完整流程可能需要更多内存和更长时间，并且对 PDK 的 LEF、Liberty、工具版本和输入
约束更敏感。不要用 `--overwrite` 覆盖前面成功的 `first` 或 `freq800` run。

只有在 run 产出 GDS 后才执行布局图渲染：

```bash
ecc layout-image \
  --gds "$TUTORIAL_DIR/runs/full/<path-to-result.gds>" \
  --image "$TUTORIAL_DIR/runs/full/layout.png"
```

`<path-to-result.gds>` 是占位符，先用下面的命令找到真实路径：

```bash
find "$TUTORIAL_DIR/runs/full" -type f \( -iname '*.gds' -o -iname '*.gds.gz' \) -print
```

## 10. 从这个例子迁移到自己的 RTL

把 NPC 示例换成自己的设计时，只需按以下顺序替换：

1. 把 RTL 源文件复制到项目的 `rtl/`。
2. 更新 `rtl/<design>.f`，列出所有源文件和必要的 `+incdir+`。
3. 将 `top` 改为真实顶层 module 名。
4. 将 `clock_port` 改为真实时钟端口名。
5. 按目标时钟设置 `frequency_mhz`，不要把它误当成保证值。
6. 运行 `ecc check`，修复所有配置、文件和 PDK 错误。
7. 每次实验使用新的 `--run-id`，保留可比较的输出。

如果 RTL 有多个时钟、异步复位、宏单元或 SRAM，不能直接照搬 NPC 的最小配置，
需要进一步补充时序约束、宏 LEF/Liberty 和 PDK override。

## 11. 版本和可重复性提醒

本教程按当前工作区的 ECC `0.1.0a8` 和已存在的 ICS55 文件布局验证过
`ecc check`。远端 `main` 可能包含更新的 CLI 或工具版本；开始一次新的实验前，
请记录：

```bash
ecc --version
git rev-parse --short HEAD 2>/dev/null || true
ecc status --project "$TUTORIAL_DIR" --run-id first --json
```

不要把生成的 `runs/` 当作 RTL 源码提交到设计仓库，除非你明确需要保存综合报告或
复现实验数据。
