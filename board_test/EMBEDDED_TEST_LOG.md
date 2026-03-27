# TDA4VM 嵌入式板端测试记录

> 说明：本文含历史排查记录（包含已废弃的 modern eBPF 尝试）。当前项目以 **kmod-only** 为准，请以 `board_test/FALCO_HEALTHCHECK_GUIDE.md` 与 `board_test/README.md` 的现行流程执行。

板子首次跑 Falco + IDPS 测试的问题与解决方案记录。若内核不支持 Falco 所需特性，会在此说明并建议你重新编译内核。

---

## 板子环境（请先运行 `./check_board_env.sh` 填到此处）

| 项目 | 值 |
|------|-----|
| 内核版本 | 6.1.80-ti-g2e423244f8c0 (J721E EVM) |
| 架构 | aarch64 |
| Falco 二进制 | /usr/local/bin/falco (已部署) |
| Falco 运行方式 | 待测（依赖 driver/plugin 配置） |
| /proc/sys/kernel 存在 | 是（bpf_stats_enabled 等存在，说明部分 BPF 可能可用） |
| 内核 config 文件 | 未在 /boot 或 /proc/config.gz 找到，无法直接确认 CONFIG_BPF_* 等 |

---

## 测试执行记录

### 1. 环境检查（首次必做）

```bash
cd board_test
./check_board_env.sh
```

- 若输出里提示缺少 `CONFIG_DEBUG_INFO`、`CONFIG_BPF_*`、`CONFIG_TRACING` 等，且 Falco 报错，则需要**重新编译内核**并打开对应选项。

### 2. 运行测试

```bash
# 启动 Falco 并跑全部测试
./run_tests_remote.sh --start-falco all

# 跑嵌入式 cases（推荐：board_test/test_cases，含 Falco 运行检测）
./run_tests_remote.sh cases

# 或只跑 IDPS（test/test_cases 的 SYS-*.sh，需 Docker 的用例在板子上会跳过）
./run_tests_remote.sh idps
```

**说明**：`cases` 模式现在跑的是 **board_test/test_cases** 下的嵌入式用例（`run_all_embedded_cases.sh` + SYS-*.sh），使用 `check_falco_embedded` 检测 Falco 是否运行，避免“Falco 已运行但脚本误报未运行”的问题；不再依赖 Docker，适合板端。

---

## 问题与解决方案

_（下面按时间顺序记录：现象 → 原因 → 解决/待办。同事可按问题 1～9 及文末「falco.ko 从编译到加载」流程复现与排错。）_

---

### 问题 1：部署时提示 test/examples 或 test/test_cases not found

**现象**  
`[WARN] test/examples not found: .../test/cases` 或 `test/test_cases not found: .../test/idps`

**原因**  
脚本里测试用例路径仍为旧目录 `test/cases`、`test/idps`，而 master 已改为 `test/examples`、`test/test_cases`。

**解决**  
已在 `deploy_to_board.sh` 中改为：
- `TEST_CASES_DIR="${REPO_ROOT}/test/examples"`
- `TEST_IDPS_DIR="${REPO_ROOT}/test/test_cases"`
- 成功/失败日志统一为 "test/examples"、"test/test_cases"。

---

### 问题 2：Plugin requirement not satisfied, must load one of: container (>= 0.4.0)

**现象**  
直接运行 `falco -c /etc/falco/falco.yaml` 报错：必须加载 container 插件。

**原因**  
- 默认配置启用了 container 插件，且规则文件里有 `required_plugin_versions: container`。
- 交叉编译产出的 `libcontainer.so` 为 **x86_64**，板子是 **aarch64**，无法加载。

**解决**  
- 在 `board_test/config/` 下增加嵌入式用配置与规则：
  - `falco.embedded.board.yaml`：`load_plugins: []`、`engine.kind: kmod`、`rules_files: [falco_rules_embedded.yaml]`。
  - `falco_rules_embedded.yaml`：仅主机侧规则，不引用 `container.*`。
- 部署时删除 `config.d/falco.container_plugin.yaml`，并部署上述两个文件；部署脚本会改写板端 `falco.yaml` 的 `rules_files`，只加载嵌入式规则文件。

---

### 问题 3：MODERN_BPF engine is not supported in this build

**现象**  
不加载 container 后，Falco 报 modern_ebpf 在此构建中不支持。

**原因**  
当前 Falco 交叉编译未启用或未包含 modern_ebpf 驱动（build.cfg 中 BUILD_MODERN_BPF=OFF）。

**解决**  
- **短期**：在 `falco.embedded.board.yaml` 中设置 `engine.kind: kmod`，使用内核模块驱动（需单独编 falco.ko）。
- **推荐**：在 `cross_compile/build.cfg` 中设 `BUILD_MODERN_BPF=ON` 后重新编译 Falco，板端使用 `engine.kind: modern_ebpf`，无需 .ko，性能与兼容性更好（Falco 0.32+ 默认推荐）。

---

### 问题 4：error opening device /dev/falco0 ... falco module is loaded

**现象**  
使用 kmod 后报错：无法打开 `/dev/falco0`，提示需加载 falco 内核模块。

**原因**  
板端未加载 Falco 内核模块（falco.ko），/dev/falco0 不存在。

**解决**  
- 需为当前板子内核编译并部署 Falco 内核模块（与 `uname -r` 一致），或**改用 modern eBPF**（推荐）：在 cross_compile 中设 `BUILD_MODERN_BPF=ON` 重新编译，板端配置 `engine.kind: modern_ebpf`，无需 .ko。
- `falco-start.sh` 已增加：若存在 `falco.ko` 则自动 `insmod`。
- 若 cross_compile 流程中会产出 kmod，需在 `deploy_to_board.sh` 中增加对 falco.ko 的拷贝与加载步骤。
- **TDA4 内核需开启的配置**：见 [KERNEL_CONFIG_TDA4_FALCO.md](KERNEL_CONFIG_TDA4_FALCO.md)。

---

### 问题 5：配置了 engine.kind: modern_ebpf 仍然报错 /dev/falco0、Events detected: 0

**现象**  
板端已放入 `falco.modern_bpf.board.yaml`（或手动设置了 `engine.kind: modern_ebpf`），但 Falco 仍报：`error opening device /dev/falco0 ... No such file or directory`，且 Events detected: 0。

**原因**  
- **/dev/falco0 是 kmod 驱动用的设备**；modern eBPF 根本不用这个设备，用的是内核 BPF 子系统。
- 若仍出现 /dev/falco0 报错，说明**当前运行的 Falco 二进制里没有 modern_ebpf 引擎**，实际用的还是 kmod，所以会去打开 /dev/falco0。
- 当前交叉编译为了在没有 clang 的环境下通过，在 `build.cfg` 中使用了 `BUILD_MODERN_BPF=OFF`，且 `MINIMAL_BUILD=ON` 时构建脚本会强制关闭 modern BPF。因此**当前部署的 Falco 二进制不包含 modern_ebpf**，配置里写 `engine.kind: modern_ebpf` 会被忽略或回退到 kmod。

**解决**  
二选一：

1. **真正启用 modern eBPF（推荐，无需 .ko）**  
   - 在**编译主机**上安装 **clang**（及可选 llvm），例如：`apt install clang llvm`.  
   - 在 `cross_compile/build.cfg` 中：`BUILD_MODERN_BPF=ON`，且 **MINIMAL_BUILD=OFF**（否则现有 patch 会强制关掉 modern BPF）。  
   - 重新执行 `./build_falco.sh all`，再部署到板子。  
   - 板端确保使用 `engine.kind: modern_ebpf` 的配置（如把 `config/falco.modern_bpf.board.yaml` 拷到板子 `/etc/falco/config.d/`，并去掉或覆盖掉指定 `kmod` 的 config.d 文件）。  
   - 板端内核需支持 BTF（通常 5.8+），见 [KERNEL_CONFIG_TDA4_FALCO.md](KERNEL_CONFIG_TDA4_FALCO.md)。

2. **继续用 kmod**  
   - 保持 `engine.kind: kmod`，为板子内核编译并加载 falco.ko，使 `/dev/falco0` 存在后再运行 Falco。

---

### 问题 6：交叉编译 modern eBPF 完整步骤（从零到二进制）

**目标**：在主机上交叉编译出带 modern eBPF 的 Falco 二进制，部署到板端后使用 `engine.kind: modern_ebpf`，无需 falco.ko。

**步骤**：

1. **主机依赖**（编译机需安装）  
   - 基础：cmake, git, make, wget  
   - **Modern BPF 必须**：clang、llvm（用于编译 BPF 程序）  
     ```bash
     sudo apt-get install -y clang llvm
     ```  
   - bpftool / libelf：若需脚本自建 bpftool，则需 `libelf-dev zlib1g-dev`；或直接安装 bpftool：  
     ```bash
     sudo apt-get install -y libelf-dev zlib1g-dev
     # 或（若发行版提供）
     sudo apt-get install -y bpftool
     ```

2. **build.cfg 配置**  
   - `BUILD_MODERN_BPF=ON`  
   - `MINIMAL_BUILD=OFF`  
   - `BUILD_KMOD=OFF`（modern eBPF 不需要 .ko）  
   - 正确设置 `SYSROOT`、`CROSS_COMPILE_PREFIX`、`CROSS_COMPILE_TRIPLE`（以及可选 `LINUX_KERNEL_SRC` 若需单独编 .ko）

3. **执行编译**  
   ```bash
   cd cross_compile
   ./build_falco.sh all
   ```  
   成功后在 `install/bin/falco` 得到 aarch64 二进制，且构建时已启用 modern_ebpf。

4. **部署与板端配置**  
   - 使用 `board_test/deploy_to_board.sh` 部署；  
   - 板端 Falco 配置使用 `engine.kind: modern_ebpf`（例如 `board_test/config/falco.modern_bpf.board.yaml` 拷入 `config.d/`）；  
   - 板端内核需支持 BTF（通常 5.8+），见 [KERNEL_CONFIG_TDA4_FALCO.md](KERNEL_CONFIG_TDA4_FALCO.md)。

5. **验证**  
   - 板端运行 `falco --dry-run -c /etc/falco/falco.yaml` 不应再报「MODERN_BPF engine is not supported」或「error opening device /dev/falco0」（modern eBPF 不使用 /dev/falco0）。

**若曾报 `[MODERN BPF] unable to find clang`**：按上面安装 clang/llvm 后重新执行 `./build_falco.sh all`（建议先 `./build_falco.sh clean` 再 `all`）。

**当前交叉编译状态（2026-02-23）**  
- **已可产出 aarch64 二进制**：在 `build.cfg` 中设 `BUILD_MODERN_BPF=OFF`、`MINIMAL_BUILD=ON`，执行 `./build_falco.sh all` 可得到 `install/bin/falco`（ELF aarch64，约 5.6MB stripped）。板端可用 `engine.kind: kmod`（需单独编 falco.ko）或 `nodriver` 做基础验证。  
- **OpenSSL 交叉编译**：已通过 patch 使用 OpenSSL `Configure linux-aarch64 --cross-compile-prefix=...`，并在配置时用 `env -u CC -u AR ...` 避免与 toolchain 的 CC 冲突。  
- **Modern eBPF 交叉编译**：`BUILD_MODERN_BPF=ON` 时构建会依赖主机工具 `events_dimensions_generator` 等（falcosecurity-libs 内）。若报错 `events_dimensions_generator: not found`，可暂时设 `BUILD_MODERN_BPF=OFF` 先产出二进制，或等待/贡献 falcosecurity-libs 对交叉编译时 host 工具路径的修复。

---

### 问题 7：falco.ko 随部署一起拷到板子并在启动时加载

**现象**  
使用 `engine.kind: kmod` 时，需要把 falco.ko 拷到板子并执行 `insmod`，希望部署脚本一次完成。

**解决**  
- 在 `deploy_to_board.sh` 中增加对 **falco.ko** 的显式拷贝：若存在 `cross_compile/install/share/falco/falco.ko`，则 scp 到板子 `BOARD_FALCO_SHARE_DIR`（默认 `/usr/share/falco/falco.ko`），并打日志。  
- `services/falco-start.sh` 已支持：启动前从 `/usr/share/falco/falco.ko`（或 `/lib/modules/$(uname -r)/extra/falco.ko`、`/opt/falco-test/falco.ko`）自动 `insmod`。  
- 编 falco.ko：在 `cross_compile/build.cfg` 中设 `BUILD_KMOD=ON`、`LINUX_KERNEL_SRC` 指向**与板子运行内核一致**的源码树，执行 `./build_falco.sh all` 或 `./build_falco.sh kmod`，产物在 `install/share/falco/falco.ko`。

---

### 问题 8：insmod falco.ko 报 Invalid module format（version magic 不匹配）

**现象**  
板端执行 `insmod /usr/share/falco/falco.ko` 报错：  
`version magic '6.1.119 SMP preempt mod_unload aarch64' should be '6.1.80-ti-g2e423244f8c0 SMP preempt mod_unload aarch64'`  
`insmod: ERROR: could not insert module falco.ko: Invalid module format`

**原因**  
内核模块必须针对**板子当前运行的内核版本**（含 version magic 字串）编译。falco.ko 是用 6.1.119 的内核树编的，而板子运行的是 6.1.80-ti-g2e423244f8c0，二者不一致，内核拒绝加载。

**解决**  
二选一：  
1. **用板子内核编 falco.ko**：将 `LINUX_KERNEL_SRC` 指向会编出 **6.1.80-ti-g2e423244f8c0** 的内核源码（如 TI J721E SDK 对应内核），在该树内执行 `make modules_prepare` 或完整编内核后，再执行 `./build_falco.sh kmod`，得到与板子 version magic 一致的 falco.ko。  
2. **统一内核版本**：重新烧录板子，使板子运行的内核与当前编 falco.ko 用的内核版本一致（例如都改为 6.1.119），再部署并 insmod。

---

### 问题 9：insmod falco.ko 报 Unknown symbol（tracepoint_probe_register 等）

**现象**  
version magic 已一致、能开始加载，但报：  
`falco: Unknown symbol tracepoint_probe_unregister (err -2)`  
`falco: Unknown symbol for_each_kernel_tracepoint (err -2)`  
`falco: Unknown symbol tracepoint_probe_register (err -2)`  
`insmod: ERROR: could not insert module falco.ko: Unknown symbol in module`

**原因**  
这些符号来自内核的 **tracepoint 机制**（`kernel/tracepoint.c` 等），只有在内核配置中打开 **CONFIG_TRACEPOINTS**（及 **CONFIG_TRACING**）时才会编进内核并导出。板子上 `zcat /proc/config.gz | grep -E 'TRACEPOINT|TRACING'` 若只有 `CONFIG_HAVE_SYSCALL_TRACEPOINTS=y`、`CONFIG_TRACING_SUPPORT=y`，而**没有** `CONFIG_TRACEPOINTS=y` 和 `CONFIG_TRACING=y`，则这些符号不存在，insmod 会报 Unknown symbol。  
falco.ko 的 license 为 **Dual MIT/GPL**，可正常使用 GPL 导出的符号，问题不在 license。

**解决**  
在**烧录到板子的那份内核**的源码树中，打开 tracepoint/tracing 并重新编内核、烧录：  
- 在 `.config` 中设置 `CONFIG_TRACEPOINTS=y`、`CONFIG_TRACING=y`（若为 `=n` 或 `# CONFIG_TRACEPOINTS is not set` 则改为 `=y`）。  
- 执行 `make olddefconfig` 补全依赖，再按现有流程编内核并烧录板子。  
- 板子用新内核启动后，再执行 `insmod /usr/share/falco/falco.ko` 即可。

**验证**  
板子上执行：  
`zcat /proc/config.gz | grep -E 'CONFIG_TRACEPOINTS|CONFIG_TRACING'`  
应能看到 `CONFIG_TRACEPOINTS=y` 和 `CONFIG_TRACING=y`。

---

### falco.ko 从编译到加载（流程小结，供同事参考）

1. **编 falco.ko**  
   - 内核树：与板子 `uname -r` **完全一致**（如 6.1.80-ti-g2e423244f8c0 或你烧录的 6.1.119）。  
   - 内核配置：至少 **CONFIG_TRACEPOINTS=y**、**CONFIG_TRACING=y**（否则 insmod 会报 Unknown symbol）。  
   - `cross_compile/build.cfg`：`BUILD_KMOD=ON`，`LINUX_KERNEL_SRC` 指向上述内核树；内核树内先 `make ARCH=arm64 CROSS_COMPILE=... olddefconfig` 与 `make ... prepare`（或完整编内核）。  
   - 执行：`cd cross_compile && ./build_falco.sh kmod`（或 `./build_falco.sh all`），得到 `install/share/falco/falco.ko`。

2. **部署**  
   - `cd board_test && ./deploy_to_board.sh`：会把 `falco.ko` 拷到板子 `/usr/share/falco/`。

3. **板端加载**  
   - 手动：`insmod /usr/share/falco/falco.ko`。  
   - 或通过 `./run_tests_remote.sh --start-falco embedded` 等启动 Falco 时，`falco-start.sh` 会自动从 `/usr/share/falco/falco.ko` insmod。

4. **若遇 Invalid module format**  
   - 检查 falco.ko 的 vermagic（`modinfo falco.ko`）与板子 `uname -r` 是否一致；不一致则用板子内核树重新编 falco.ko 或重烧与编模块一致的内核。

5. **若遇 Unknown symbol tracepoint_***  
   - 在内核 .config 中打开 CONFIG_TRACEPOINTS=y、CONFIG_TRACING=y，重新编内核并烧录。

6. **若遇 Kernel module does not support PPM_IOCTL_GET_API_VERSION**  
   - 见下方「问题 10」。

---

### 问题 10：Falco 报 Kernel module does not support PPM_IOCTL_GET_API_VERSION: Invalid argument

**现象**  
Falco 能启动，但很快报错退出：  
`An error occurred in an event source, forcing termination...`  
`Error: Kernel module does not support PPM_IOCTL_GET_API_VERSION: Invalid argument`

**原因**  
用户态 Falco（libscap）通过 ioctl `PPM_IOCTL_GET_API_VERSION` 与内核模块协商 API 版本。报错说明**当前已加载的内核模块**与 Falco 二进制不匹配。常见情况：  
- 板子上**已经加载了旧版** falco/scap 模块（例如上次启动残留，或来自 `/lib/modules/.../extra/`）；Falco 自动 “inject” 新模块时因“模块名已占用”而失败（“Unable to load the driver”），随后打开 `/dev/falco0` 时连上的是**旧模块**，旧模块不支持该 ioctl → Invalid argument。  
- 即使同一次编译，若**不先卸掉旧模块**就启动 Falco，也会出现上述情况。

**解决**  
1. **启动 Falco 前必须先卸掉旧模块，再加载本次部署的 falco.ko**：  
   ```bash
   rmmod falco 2>/dev/null || true
   rmmod scap 2>/dev/null || true
   insmod /usr/share/falco/falco.ko
   # 然后再 systemctl start falco 或 /opt/falco-test/falco-start.sh
   ```  
2. **使用脚本或 systemd**：  
   - **falco-start.sh**（`/opt/falco-test/falco-start.sh`）：先 rmmod 再 insmod，然后启动 Falco。  
   - **systemd**：`falco.service` 的 `ExecStartPre` 会执行 **`/opt/falco-test/load-falco-ko.sh`**（该脚本用 **绝对路径** `/sbin/rmmod`、`/sbin/insmod` 和 `/usr/share/falco/falco.ko`，避免 systemd 环境下 PATH 导致 insmod 找不到而失败）。部署会把 `load-falco-ko.sh` 和 `falco.service` 放到 `/opt/falco-test/`；需把 `falco.service` 拷到 `/etc/systemd/system/` 并 `systemctl daemon-reload` 后，**直接 `systemctl start falco` 即可，无需手动先 insmod**。  
3. **保证同一套构建**：falco.ko 与 Falco 二进制需来自同一次 `./build_falco.sh all`；部署用 `./deploy_to_board.sh` 把 `install/share/falco/falco.ko` 拷到板子 `/usr/share/falco/`。  
4. 若仍报错：主机完整重编并部署后，板端**先** `rmmod falco; insmod /usr/share/falco/falco.ko`，再启动 Falco。

**验证**  
板子上执行：  
`lsmod | grep falco` 应能看到 falco；且该模块应来自本次部署的 `/usr/share/falco/falco.ko`（无其他路径的旧 ko 被优先加载）。

**若仍报 PPM_IOCTL_GET_API_VERSION（已确认同一次编译、且已先 rmmod 再 insmod）**  
可能原因与对应措施：  

1. **板子实际加载的不是我们部署的 ko**  
   - 在板子上执行：`rmmod falco 2>/dev/null; rmmod scap 2>/dev/null; /sbin/insmod /usr/share/falco/falco.ko`，然后**不要**再执行其他会加载模块的操作，直接 `systemctl start falco`。若仍报错，继续下一条。  

2. **驱动与用户态 API 不一致（构建缓存/不同 libs）**  
   - 主机上**完全清空后重编**，确保 falco.ko 与 Falco 二进制来自同一份 falcosecurity-libs：  
     `cd cross_compile && ./build_falco.sh clean && ./build_falco.sh all`  
   - 再部署到板子，板端先 `rmmod falco; insmod /usr/share/falco/falco.ko`，再 `systemctl start falco`。  

3. **临时验证 Falco 能否启动（不采集 syscall）**  
   - 使用 **nodriver** 引擎，不依赖内核模块。部署后板上有 `/opt/falco-test/falco.nodriver.board.yaml`，在板子上执行：  
     ```bash
     cp /opt/falco-test/falco.nodriver.board.yaml /etc/falco/config.d/falco.container_plugin.board.yaml
     systemctl restart falco
     ```  
   - 若用 nodriver 后 Falco 能正常启动，说明问题在 **kmod 与当前内核/架构的兼容性**；可考虑改用 **modern eBPF**（主机 `BUILD_MODERN_BPF=ON` 且板端内核支持 BTF），或向 Falco/libs 反馈 kmod 在 ARM64/该内核上的兼容性问题。恢复 kmod 时把原来的 config.d 再拷回即可。

---

### 交叉编译 + 部署 + 启动测试（2026-01-10）

**执行**：`./build_falco.sh all`（未改 BUILD_MODERN_BPF）→ `./deploy_to_board.sh` → 板端 `falco -c /etc/falco/falco.yaml`。

**结果**：
- 部署成功：二进制、配置、libcontainer.so、falco-start.sh、测试脚本均就绪。
- Falco 能启动并完成配置与插件加载（container@0.6.1），规则加载正常。
- **无法打开 syscall 源**：`Opening 'syscall' source with Kernel module` → `Unable to load the driver` → `error opening device /dev/falco0`（板端未加载 falco.ko）。

**结论**：当前缺的是**驱动**二选一：
1. **kmod**：为板子内核编译并部署 `falco.ko`，在板端 `insmod` 后 Falco 即可用。
2. **modern eBPF**：在交叉编译环境安装 **clang/LLVM**（用于 BPF 编译），在 `build.cfg` 中设 `BUILD_MODERN_BPF=ON` 后重新编译 Falco，板端配置 `engine.kind: modern_ebpf`（无需 .ko）。尝试 `BUILD_MODERN_BPF=ON` 时曾报错：`[MODERN BPF] unable to find clang`，需先安装 clang 再打开该选项。

---

### 内核相关说明（TDA4 / Falco）

- **Falco 依赖**（按常见用法）：
  - 若用 **eBPF**：需内核支持 BPF、BTF、tracepoint；部分发行版需 `CONFIG_DEBUG_INFO_BTF=y`。
  - 若用 **kmod**：需能加载内核模块，且版本与当前内核一致。
  - **nodriver**：仅读 capture 文件，不依赖内核驱动，适合先做基础功能验证。
- **TDA4 内核**：TI SDK 内核可能未打开上述选项。若 Falco 报 “driver not found”“BPF not supported” 或 “Plugin requirement not satisfied (must load one of: ...)”，请：
  1. 运行 `./check_board_env.sh` 保存输出；
  2. 在本文件“问题 N”中记录完整报错；
  3. 若确认为内核缺选项，会在此写明需要**重新编译内核**并打开哪些 `CONFIG_*`。

---

## 建议下一步（首次板端测试）

1. **重新部署**（含路径修复与 container 插件禁用）：  
   `./deploy_to_board.sh`  
   确认无 `test/examples` / `test/test_cases` 的 WARN，且 Falco 配置已覆盖。

2. **板子上验证 Falco**：  
   `ssh root@192.168.1.3 '/usr/local/bin/falco --dry-run -c /etc/falco/falco.yaml'`  
   若仍报 driver/plugin 相关错误，把完整输出记入本 log。

3. **跑测试**：  
   `./run_tests_remote.sh --start-falco idps` 或 `./run_tests_remote.sh --start-falco all`  
   把失败用例与报错贴到本文件“问题 N”。

---

_（后续问题继续按“问题 N”追加到本文件即可）_
