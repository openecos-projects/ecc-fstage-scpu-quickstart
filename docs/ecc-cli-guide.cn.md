# ECC 指令列表与使用指南

本文面向使用 ECC（ECOS Chip Compiler）执行 RTL-to-GDS 流程的设计人员，命令以当前
`main` 分支的 `ecc` CLI 为准。

针对仓库中的 `RTL/ysyx-cores/Fstage-scpu/NPC.sv`，另有一份可直接照做的
[手把手教程](ecc-fstage-scpu-tutorial.cn.md)。

## 1. 安装与前置条件

本快速上手仓库使用官方安装脚本，一次装好 ECC、OSS CAD Suite 和 ICS55 PDK。要求
Linux x86_64、glibc ≥ 2.34：

```bash
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh | sh -s -- --with-toolchain
```

包装脚本位于 `~/.local/bin/ecc`。若不在 `PATH` 中：

```bash
export PATH="$HOME/.local/bin:$PATH"
ecc --version
```

默认先从 GitHub 下载，失败后自动改走 CNB：

- ECC：<https://cnb.cool/ecoslab/ecc>
- OSS CAD Suite：<https://cnb.cool/ecoslab/oss-cad-suite-build>
- ICS55 PDK：<https://cnb.cool/ecoslab/icsprout55-pdk>

两边都不可达时，再给 GitHub URL 加前缀：

```bash
export ECC_GITHUB_BASE_URL=https://ghfast.top/https://github.com
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh | sh -s -- --with-toolchain
```

`--with-toolchain` 会让 `ecc` 在运行时带上 `CHIPCOMPILER_OSS_CAD_DIR` 和
`CHIPCOMPILER_ICS55_PDK_ROOT`，一般不必再手动 `export`。

### PDK 路径

配置文件中的 `pdk.root` 可以写绝对路径，也可以写相对于项目目录的路径。若省略
该字段，ECC 依次读取以下环境变量：

```bash
export CHIPCOMPILER_ICS55_PDK_ROOT=/path/to/icsprout55-pdk
# 或
export ICS55_PDK_ROOT=/path/to/icsprout55-pdk
```

当前 CLI 支持的 PDK 名称为 `ics55`。

## 2. 命令总览

| 命令 | 用途 |
| --- | --- |
| `ecc --version` | 输出单行 ECC 版本 |
| `ecc --help` | 查看根命令帮助 |
| `ecc version [--json]` | 输出 ECC 及组件版本 |
| `ecc init NAME` | 创建项目目录、`ecc.toml` 和标准子目录 |
| `ecc check` | 检查项目配置、RTL/filelist、PDK 和 flow |
| `ecc run` | 创建运行目录并执行配置的 RTL-to-GDS 流程 |
| `ecc status` | 查看运行和各步骤状态 |
| `ecc log [STEP]` | 查看日志列表或指定步骤日志 |
| `ecc config [STEP] --resolved` | 查看解析后的项目/步骤配置 |
| `ecc param ...` | 查看和修改参数覆盖 |
| `ecc layout-image` | 将 GDS 渲染为图片 |
| `ecc rpc serve --stdio` | 启动内部 JSON-RPC sidecar |

项目命令默认把当前目录作为项目目录，也可以用 `--project PATH` 指定目录。

任意子命令都可以追加 `--help` 查看该命令的完整选项：

```bash
ecc --help
ecc run --help
ecc param --help
ecc param set --help
```

## 3. 最小可运行流程

### 3.1 创建项目

```bash
ecc init gcd
cp /path/to/gcd.v gcd/rtl/gcd.v
```

`ecc init gcd` 会生成：

```text
gcd/
├── ecc.toml
├── rtl/
├── constraints/
└── runs/
```

### 3.2 编辑 ecc.toml

```toml
[design]
name = "gcd"
top = "gcd"
rtl = ["rtl/gcd.v"]
clock_port = "clk"
frequency_mhz = 100.0

[pdk]
name = "ics55"
root = "/path/to/icsprout55-pdk"

[flow]
# rtl2gds | rcx | harden | syn_sta
preset = "rtl2gds"
run = "default"
```

字段含义：

- `design.name`：设计名称；`design.top`：顶层 RTL module 名称。
- `design.rtl`：必须包含一个 RTL 文件或一个 filelist；多个 RTL 源文件请放入
  filelist，而不是写多个数组元素。
- `design.clock_port`：时钟端口名称；`design.frequency_mhz`：目标频率，必须大于 0。
- `pdk.name`：当前为 `ics55`；`pdk.root`：PDK 根目录，可留空并使用环境变量。
- `flow.preset`：`rtl2gds` 为完整流程，`rcx` 追加 RCX/STA，`harden` 追加
  Harden，`syn_sta` 只执行综合并尽力生成网表级 STA 报告。
- `flow.run`：运行目录名；`default` 对应 `runs/default`。

### 3.3 校验和运行

```bash
ecc check --project gcd
ecc run --project gcd
ecc status --project gcd
ecc log --project gcd
```

进入项目目录后可省略 `--project gcd`：

```bash
cd gcd
ecc check
ecc run
ecc status
ecc log
```

已有项目切换 `flow.preset` 后，使用 `ecc run --overwrite` 重新创建该运行目录。

## 4. 命令详解

### ecc --version 与 ecc version

```bash
ecc --version
ecc version
ecc version --json
```

`--version` 适合脚本中的快速检查；`version --json` 输出可供程序解析的版本对象。

### ecc init NAME

```bash
ecc init my_design
ecc init my_design --plain
```

`NAME` 可以是相对或绝对路径。目标中的 `ecc.toml` 已存在时命令会失败，不会覆盖
现有项目。

### ecc check

```bash
ecc check
ecc check --project /path/to/my_design
ecc check --json
ecc check --plain
```

校验内容包括 `ecc.toml` 语法和必填字段、RTL/filelist 路径、PDK 目录及内容、流程
预设和参数类型。

### ecc run：项目模式

```bash
# 使用 ecc.toml 中的 flow.run（默认 runs/default）
ecc run

# 指定运行目录名
ecc run --run-id baseline

# 覆盖一个已有的 ECC 运行目录
ecc run --run-id baseline --overwrite

# 临时修改参数，仅对本次运行生效；可重复使用 --set
ecc run --set place.target_density=0.65 \
        --set design.frequency_mhz=200

# 机器可读输出
ecc run --json
ecc run --jsonl
ecc run --plain
```

运行会在 `runs/<run-id>/` 创建工作区，并按 flow preset 生成步骤。默认情况下，
已有运行目录不会被覆盖；`--overwrite` 只允许删除并重建被识别为 ECC 工作区的目标。
`--set` 不修改 `ecc.toml`，覆盖值会记录在运行目录的
`home/cli-param-overrides.json` 中。

### ecc run：已有工作区模式

使用 `--workspace` 可以在原工作区内继续或重跑。该模式不能和 `--project`、
`--run-id`、`--overwrite` 或 `--set` 同时使用。

```bash
# 从第一个未成功步骤继续
ecc run --workspace runs/default --resume

# 从指定步骤开始，连同其后的已持久化步骤一起重跑
ecc run --workspace runs/default --from CTS

# 只运行一个步骤
ecc run --workspace runs/default --only place

# 即使该步骤已经成功，也强制重新运行
ecc run --workspace runs/default --only place --force
```

`--resume`、`--from` 和 `--only` 互斥；`--force` 必须与 `--only` 一起使用。
步骤名和顺序以工作区 `home/flow.json` 中的记录为准。重跑步骤会使下游步骤回到未
完成状态并重新生成相应输出。

### ecc status

```bash
ecc status
ecc status --run-id baseline
ecc status --json
ecc status --jsonl
ecc status --plain
```

`--plain` 输出稳定键值行，适合 shell 脚本；`--json` 输出对象，`--jsonl` 输出逐行
记录。输出中通常包含用于进一步查看的 `inspect_cmd`、`log_cmd` 等字段。

### ecc log [STEP]

```bash
ecc log
ecc log synthesis
ecc log placement --plain
ecc log routing --json
```

`STEP` 可省略；步骤名以状态输出和工作区记录为准。`--run-id NAME` 可指定运行，
`--project PATH` 可指定项目。

### ecc config [STEP] --resolved

```bash
ecc config --resolved
ecc config placement --resolved
ecc config placement --resolved --json
```

当前实现要求显式提供 `--resolved`，用于查看实际传给步骤的解析配置。

### ecc param

参数命令操作项目 `ecc.toml` 中的 `[params]` 覆盖：

```bash
ecc param list
ecc param show place.target_density
ecc param set place.target_density 0.65
ecc param unset place.target_density
ecc param diff
```

`param set` 会直接修改 `ecc.toml`；`param unset` 删除该覆盖并恢复默认值。所有
参数命令都支持 `--project` 以及 `--json`、`--jsonl`、`--plain` 输出选项。

当前注册的参数如下（范围为闭区间）：

| 参数 | 类型/默认值 | 适用步骤 | 约束或单位 |
| --- | --- | --- | --- |
| `design.frequency_mhz` | float / `100.0` | synthesis | [0.000001, 10000] MHz |
| `floorplan.core_util` | float / `0.4` | floorplan | [0.01, 1.0] |
| `floorplan.core_margin` | list[int] / `[2, 2]` | floorplan | [横向, 纵向]，单位 um |
| `floorplan.aspect_ratio` | float / `1.0` | floorplan | [0.1, 10.0] |
| `synth.max_fanout` | int / `20` | fixfanout | [1, 200] |
| `place.target_density` | float / `0.2` | placement | [0.1, 0.95] |
| `place.target_overflow` | float / `0.1` | placement | [0.0, 1.0] |
| `place.global_right_padding` | int / `0` | placement | [0, 100] |
| `place.cell_padding_x` | int / `300` | placement | [0, 10000]，数据库单位 |
| `place.routability_opt` | int / `1` | placement | 0 或 1 |
| `route.bottom_layer` | str / `MET2` | routing | `MET1`...`MET5` |
| `route.top_layer` | str / `MET5` | routing | `MET2`...`MET6` |
| `sta.max_paths` | int / `1000` | sta | [1, 100000] |

TOML 写法示例：

```toml
[params]
[params.place]
target_density = 0.65
cell_padding_x = 400

[params.route]
bottom_layer = "MET2"
```

### ecc layout-image

将 GDS 文件渲染为图片，依赖 KLayout：

```bash
ecc layout-image --gds runs/default/output/result.gds \
  --image runs/default/report/layout.png \
  --width 1920 --height 1920
```

`--width` 和 `--height` 必须为正整数，默认均为 `1920`。

### ecc rpc serve --stdio

这是供 GUI 或自动化客户端使用的内部 JSON-RPC sidecar：

```bash
ecc rpc serve --stdio
ecc rpc serve --stdio --persistent-db
```

协议使用带 `Content-Length` 的 JSON-RPC 2.0 stdio 帧。客户端应先调用
`rpc.hello`，再调用 `workspace.open` 或 `workspace.create`。启用
`--persistent-db` 后才会提供 `db.ensure` 和 `db.release`。完整方法和报文格式见
[docs/workspace-cli.md](workspace-cli.md)。

## 5. RTL filelist

`design.rtl` 只能有一个数组元素；需要多个 Verilog/SystemVerilog 源文件时，指定
一个 `.f` filelist：

```toml
[design]
rtl = ["rtl/filelist.f"]
```

示例 `rtl/filelist.f`：

```text
rtl/gcd.v
rtl/gcd_pkg.v
+incdir+rtl/include
"rtl/special modules/module.v"
```

支持相对/绝对路径、单/双引号、`#`/`//`/反引号注释和 `+incdir+`。`-f`、`-v`、
`-y` 会被拒绝；其他未知的 `+` 或 `-` 选项会被忽略。

## 6. 输出与脚本化

项目类命令支持三种机器友好输出：

```bash
ecc status --plain
ecc status --json
ecc status --jsonl
```

同时指定多个模式时，优先级为 `--jsonl` > `--json` > `--plain`。脚本应优先使用
这些选项，不要解析默认的富文本排版。

## 7. 常见问题

### missing_config

在项目目录找不到 `ecc.toml`。先运行 `ecc init NAME`，或用
`--project /path/to/project` 指向包含该文件的目录。

### design.rtl 校验失败

确认路径相对于项目目录存在，且多个源文件已经收纳到单个 filelist 中。

### run_exists

目标运行已经存在。检查 `ecc status --run-id NAME`；确认需要重建后再使用
`ecc run --run-id NAME --overwrite`。

### 参数类型或范围错误

用 `ecc param show KEY` 查看类型、默认值、范围和可选值。命令行覆盖必须使用
`KEY=VALUE` 格式，例如 `--set place.target_density=0.65`。

### 定位失败步骤

```bash
ecc status --plain
ecc log <failed-step>
ecc config <failed-step> --resolved --json
ecc run --workspace runs/default --only <failed-step> --force
```

重跑单步前应确认上游输入和 PDK 配置没有变化。

## 8. Python API

需要在脚本中编排工作区或自定义流程时，可以使用 `chipcompiler` Python API，例如
`create_workspace`、`load_workspace` 和 `EngineFlow`。CLI 适合配置驱动和自动化
执行，Python API 适合需要自定义步骤、参数或集成其他系统的场景。
