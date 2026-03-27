# TDA4 内核配置：Falco 驱动（kmod）

当前项目仅使用 `kmod` 模式，本文档仅保留 kmod 相关内核配置与排查步骤。

---

## 一、必须启用（Falco kmod 依赖，仅在使用 kmod 时需要）

| 配置项 | 建议值 | 说明 |
|--------|--------|------|
| **CONFIG_MODULES** | =y | 可加载内核模块，否则无法 insmod falco.ko |
| **CONFIG_TRACEPOINTS** | =y | 内核 tracepoint 框架，Falco 驱动依赖 syscall tracepoint |
| **CONFIG_HAVE_SYSCALL_TRACEPOINTS** | =y | 架构需支持 syscall tracepoint（ARM64 一般已选，由 CONFIG_TRACEPOINTS 等带出） |

---

## 二、强烈建议（与 tracepoint / 调试相关）

| 配置项 | 建议值 | 说明 |
|--------|--------|------|
| **CONFIG_FTRACE** | =y | 内核函数追踪框架，常与 TRACEPOINTS 一起使用 |
| **CONFIG_KALLSYMS** | =y | 导出内核符号，部分驱动/调试会依赖 |
| **CONFIG_KALLSYMS_ALL** | =y 或 =n 皆可 | 若需完整符号可开 |
| **CONFIG_DEBUG_FS** | =y | 调试文件系统，部分驱动会挂节点到 /sys/kernel/debug |

---

## 三、当前范围说明

本项目不使用 modern eBPF；部署与排错均按 `engine.kind: kmod` 执行。

---

## 四、在 menuconfig 中的大致位置（kmod 相关）

- **CONFIG_MODULES**  
  `Enable loadable module support` → `[*] Enable loadable module support`

- **CONFIG_TRACEPOINTS**  
  `Kernel hacking` → `Tracers` → `[*] Kernel Function Tracer` 等会依赖；或  
  `General setup` → `Kernel Performance Events And Instrumentation` → `[*] Tracepoint support`

- **CONFIG_FTRACE**  
  `Kernel hacking` → `Tracers` → `[*] Enable kernel function tracer` 等

- **CONFIG_DEBUG_FS**  
  `Kernel hacking` → `[*] Debug Filesystem`

- **CONFIG_KALLSYMS**  
  `Kernel hacking` → `[*] Load all symbols for debugging/ksymoops`

（不同内核版本菜单路径可能略有差异，以实际 `make menuconfig` 为准。）

---

## 五、快速检查当前运行内核是否具备条件

在板子上执行：

```bash
# 是否有 /sys/kernel/debug（DEBUG_FS 未挂载时可能为空，但配置可已打开）
ls /sys/kernel/debug 2>/dev/null

# 是否有 tracepoint（TRACEPOINTS）
ls /sys/kernel/tracing/events/syscalls 2>/dev/null | head -5

# 当前内核版本（编译 falco.ko 需与此一致）
uname -r
```

若 `/sys/kernel/tracing/events/syscalls` 存在且下面有子目录，说明 tracepoint/syscall 支持在运行内核中已打开。

---

## 六、falco.ko 从哪里来？（重要）

**falco.ko 不在 Linux 内核源码里。**  
它是 Falco 项目自带的“外置”驱动，来自 [falcosecurity/libs](https://github.com/falcosecurity/libs) 的 driver 部分，需要用 **目标内核的头文件/源码** 单独编译。  
你编译的 TDA4 内核（`~/work/tda4-bsp/bsp/ti-linux-kernel`、`make linux`）只是**运行环境**，内核配置满足上文即可；**生成 falco.ko 要用下面两种方式之一**。

---

### 方式 A：用 Driverkit 构建（推荐）

[driverkit](https://github.com/falcosecurity/driverkit) 是 Falco 官方用来为指定内核版本构建 kmod 的工具（在 Docker 里下载内核头文件并编译）。

1. **在板子上看准内核版本**（例如 `6.1.80-ti-g2e423244f8c0`）：
   ```bash
   ssh root@192.168.1.3 uname -r
   ```

2. **准备 driverkit 配置**（例如 `tda4-falco.yaml`）：
   - `target: vanilla`（自定义/非标准内核用 vanilla）。
   - `kernelrelease`: 与板子 `uname -r` **完全一致**。
   - `kernelconfigdata`: 从你当前 TDA4 内核的 `.config` 生成（base64）：
     ```bash
     cd ~/work/tda4-bsp/bsp/ti-linux-kernel
     cat .config | base64 -w0
     ```
     把输出填到配置里的 `kernelconfigdata`。
   - 若 vanilla 无法自动拉到你用的内核头文件，可再用 `kernelurls` 指向你的内核或 headers 包（例如 TI 提供的 tarball 或你自打的包）的 URL。

3. **安装并执行 driverkit**（在能跑 Docker 的 x86 主机上，可交叉为 arm64）：
   ```bash
   driverkit docker -c tda4-falco.yaml --timeout=300
   ```
   输出会得到与 `kernelrelease` 对应的 `.ko`，重命名为 `falco.ko` 后拷到板子 `/usr/share/falco/` 或 `/lib/modules/$(uname -r)/extra/`。

4. **若 TI 内核 release 字符串不在 driverkit 的下载列表里**：  
   需要用 `kernelurls` 提供该内核（或 kernel-headers）的压缩包 URL，或使用方式 B 用本地内核树编译。

---

### 方式 B：用 falcosecurity/libs 驱动源码 + 你的内核树本地编译

用你本地的 TDA4 内核目录当作 KDIR，在 Falco 驱动源码里编译出内核模块。

1. **准备内核树**（你已有）：
   - 内核目录：`~/work/tda4-bsp/bsp/ti-linux-kernel`
   - 先在该目录执行一次完整构建（至少 `make modules_prepare`，推荐先 `make linux` 或等价命令），保证有 `.config`、`Module.symvers`、头文件等。

2. **取驱动源码**（与 Falco 使用的 libs 版本一致更稳妥）：
   - 克隆 falcosecurity/libs，或使用当前 Falco 构建所用的 libs 子模块/依赖版本。
   - 在 libs 里配置并构建 driver，生成 `driver/src/Makefile`（由 `Makefile.in` 生成）和所需头文件。  
     例如在 libs 的 build 目录：
     ```bash
     cd /path/to/libs && mkdir build && cd build
     cmake .. -DUSE_BUNDLED_DRIVER=ON
     make driver
     ```
     这样会得到 `build/driver/src/` 下的可编译源码。

3. **用你的 TDA4 内核树编译模块**：
   ```bash
   KDIR=~/work/tda4-bsp/bsp/ti-linux-kernel
   make -C "$KDIR" M=$(pwd)/path/to/libs/build/driver/src modules
   ```
   - 若编译出的是 `scap.ko`（设备名可能是 `/dev/scap0`），而 Falco 默认找的是 `falco`/`/dev/falco0`，可在板子上做符号链接或改 Falco 配置以使用该设备名（若 Falco 支持配置 driver 名称）。

4. **部署**：  
   将生成的 `.ko` 拷到板子，例如 `/usr/share/falco/falco.ko`，并用 `falco-start.sh` 或 `insmod` 加载。

---

### 小结

| 项目 | 说明 |
|------|------|
| **falco.ko 来源** | Falco 项目（falcosecurity/libs + driverkit），**不是**内核源码的一部分 |
| **内核目录作用** | 提供运行环境与编译时的 KDIR（头文件、.config、Module.symvers 等） |
| **版本一致** | 生成的 falco.ko 必须与板子当前运行的 `uname -r`（及内核 ABI）一致 |
| **部署位置** | 板子：`/usr/share/falco/` 或 `/lib/modules/$(uname -r)/extra/`，再由 `falco-start.sh` 或 `insmod` 加载 |

---

## 七、编译 falco.ko 与内核版本（对照）

- falco.ko 需针对 **与板子运行内核完全一致** 的版本与配置编译（`uname -r`，如 `6.1.80-ti-g2e423244f8c0`）。
- 内核源码与 `.config` 建议与 TI SDK 为 TDA4 提供的内核树一致（你的 `~/work/tda4-bsp/bsp/ti-linux-kernel`、`make linux`），并确认上文“一、二”中的配置已打开。
- 编译得到 falco.ko 后，放到板子 `/usr/share/falco/` 或 `/lib/modules/$(uname -r)/extra/`，用 `falco-start.sh` 或 `insmod` 加载。

---

## 七、简要清单（复制到你的配置或笔记）

```
# Falco kmod 所需内核配置（TDA4）
CONFIG_MODULES=y
CONFIG_TRACEPOINTS=y
CONFIG_HAVE_SYSCALL_TRACEPOINTS=y
CONFIG_FTRACE=y
CONFIG_KALLSYMS=y
CONFIG_DEBUG_FS=y
```

若你的 defconfig 或 SDK 默认已包含上述项，只需确认未在后续裁剪中被关掉即可。
