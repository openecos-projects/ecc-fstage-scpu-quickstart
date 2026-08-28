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

## 使用流程

以下命令均在本仓库根目录执行。先安装 ECC、OSS CAD Suite 和 ICS55 PDK（Linux
x86_64，glibc ≥ 2.34）：

```bash
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh | sh -s -- --with-toolchain
```

安装脚本会把 `ecc` 写到 `~/.local/bin`。若该目录不在 `PATH` 中，按脚本提示加入后再执行：

```bash
ecc check --plain
ecc run --run-id first
ecc status --run-id first --plain
ecc log --run-id first
```

默认先从 GitHub 下载；失败后会自动改走 CNB 镜像：

- ECC：<https://cnb.cool/ecoslab/ecc>
- OSS CAD Suite：<https://cnb.cool/ecoslab/oss-cad-suite-build>
- ICS55 PDK：<https://cnb.cool/ecoslab/icsprout55-pdk>

GitHub 和 CNB 都不可达时，再给 GitHub URL 加前缀：

```bash
export ECC_GITHUB_BASE_URL=https://ghfast.top/https://github.com
curl -fsSL http://release.openecos.com/installers/ecc/latest/ecc-installer.sh | sh -s -- --with-toolchain
```

`--with-toolchain` 会让 `ecc` 包装脚本带上 OSS CAD Suite 和 ICS55 PDK 路径，无需再
`source` 环境文件。

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
