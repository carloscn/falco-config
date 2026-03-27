# Falco 嵌入式健康检查指南（部署/运维版）

目标：让部署人员在板子上快速判断 **Falco 是否可用、为什么不可用、下一步该改哪里**。  
适用：TDA4/J721E 等嵌入式 Linux，当前仅支持 `kmod` 引擎。

---

## 0. 一句话判定标准

只有同时满足以下 4 条，才算“健康”：

1. 编译产物正确（`falco` 架构正确、`falco.ko` 与内核匹配）。
2. 板端文件部署完整（binary/config/rules/plugins/service 脚本齐全）。
3. 运行态正常（Falco 进程存活，驱动/引擎初始化成功，无关键报错）。
4. 冒烟事件可触发且可看到告警输出（stdout/journal/json 任一通道可观测）。

---

## 1) 编译后健康检查（主机侧）

> 在仓库根目录执行；建议每次发包前都跑一次。

### 1.1 检查 Falco 二进制

```bash
file cross_compile/install/bin/falco
cross_compile/install/bin/falco --version
```

通过标准：
- `file` 显示 `aarch64`。
- `--version` 可正常输出版本信息。

失败特征与处理：
- 若不是 `aarch64`：交叉编译链配置错误（`CROSS_COMPILE_*` / `SYSROOT`）。
- 若运行失败：产物不完整或依赖缺失，先重新 `./build_falco.sh all`。

### 1.2 检查 kmod 产物（仅 kmod 模式）

```bash
file cross_compile/install/share/falco/falco.ko
modinfo cross_compile/install/share/falco/falco.ko | egrep 'filename|vermagic|name|license'
```

通过标准：
- `.ko` 存在且为 `aarch64` 模块。
- `vermagic` 与板端 `uname -r` 对应（至少主版本和发行字符串一致）。

失败特征与处理：
- `Invalid module format`：通常是 `vermagic` 与板端内核不一致，必须用板端对应内核树重编 `.ko`。

### 1.3 检查内核配置前置条件（kmod）

内核配置详情见 `board_test/KERNEL_CONFIG_TDA4_FALCO.md`。最低建议：

- `kmod`：`CONFIG_MODULES=y`、`CONFIG_TRACEPOINTS=y`、`CONFIG_TRACING=y`

---

## 2) 安装部署完整性检查（板端）

建议先执行：

```bash
cd board_test
./deploy_to_board.sh
./check_board_env.sh
```

然后 SSH 到板子检查：

```bash
ssh root@<board-ip>
```

### 2.1 文件完整性

```bash
ls -l /usr/local/bin/falco
ls -l /etc/falco/falco.yaml
ls -l /etc/falco/config.d
ls -l /usr/share/falco
ls -l /opt/falco-test
```

通过标准：
- `falco`、`falco.yaml`、`config.d`、`rules`、`plugins`、`falco-start.sh` 都在。
- kmod 模式下 `falco.ko` 存在（通常在 `/usr/share/falco/falco.ko`）。

### 2.2 配置一致性（重点）

```bash
grep -nE 'engine:|kind:|load_plugins|rules_files' /etc/falco/falco.yaml
grep -R -nE 'engine:|kind:|load_plugins|rules_files|required_plugin_versions' /etc/falco/config.d /etc/falco/*.yaml
```

通过标准（示例）：
- `kmod` 路线：`engine.kind: kmod`，且 `.ko` 已部署。
- 仅使用 `kmod` 路线：`engine.kind: kmod`，并确保没有其他 config.d 文件覆盖该设置。
- 若关闭 container 插件：`load_plugins: []` 且规则不要依赖 `required_plugin_versions: container`。

常见坑：
- `config.d` 里还有 `falco.container_plugin.yaml`，会把 `load_plugins` 覆盖为 `[container]`。
- 默认 `falco_rules.yaml` 可能要求 container 插件，和“无 container 插件”配置冲突。

### 2.3 rootfs 全局不可写（只读根文件系统）检查

先确认根文件系统是否只读：

```bash
findmnt -no TARGET,OPTIONS /
touch /etc/.falco_rw_test 2>/dev/null && rm -f /etc/.falco_rw_test && echo "rootfs writable" || echo "rootfs readonly"
```

若显示 `ro`（readonly），需要额外确认：

```bash
findmnt -no TARGET,OPTIONS /tmp /run /var/log 2>/dev/null
```

通过标准（readonly 场景）：
- 你明确知道当前是“只读 rootfs”模式，不再把“无法写 /etc、/usr、/var”误判为 Falco 故障。
- 至少有一个可写目录用于运行时输出（推荐 `/run`、`/tmp`、`/var/log` 中的 tmpfs/overlay 挂载）。

部署注意（readonly 场景）：
- 不能直接覆盖 `/etc/falco`、`/usr/local/bin`、`/usr/share/falco` 时，需要先切到维护模式（临时 remount rw、overlay、A/B 升级分区、或镜像内预置）。
- 若 `systemctl restart falco` 失败，先检查是否因为 service 文件、配置文件更新写入失败，而不是 Falco 本身异常。

---

## 3) Linux Runtime 健康检查（板端）

## 3.1 内核与模块迹象

```bash
uname -r
zcat /proc/config.gz 2>/dev/null | egrep 'CONFIG_MODULES=|CONFIG_TRACEPOINTS=|CONFIG_TRACING='
```

若是 kmod，再检查：

```bash
insmod /usr/share/falco/falco.ko
lsmod | grep -E 'falco|scap'
ls -l /dev/falco0
dmesg | tail -n 80
```

通过标准（kmod）：
- `insmod` 成功。
- `lsmod` 能看到 `falco`/`scap`（依版本不同）。
- `/dev/falco0` 存在。

典型失败：
- `Invalid module format`：内核版本不匹配。
- `Unknown symbol tracepoint_*`：缺 `CONFIG_TRACEPOINTS` / `CONFIG_TRACING`。

### 3.2 Falco 进程/服务健康

systemd 场景：

```bash
systemctl daemon-reload
systemctl restart falco
systemctl status falco --no-pager -l
journalctl -u falco -n 120 --no-pager
```

非 systemd 场景：

```bash
/opt/falco-test/falco-start.sh
ps -ef | grep '[f]alco'
```

通过标准：
- 进程存活（不是反复 crash）。
- 日志出现 `Loaded event sources` / `Enabled event sources` / `Opening 'syscall' source ...`。
- 无关键错误：`error opening device /dev/falco0`、`PPM_IOCTL_GET_API_VERSION`、`Plugin requirement not satisfied`。

---

## 4) 最小冒烟测试（证明可检测）

目标：触发一条简单主机规则，确认 Falco 能产出检测事件。

### 4.1 启动 Falco（前台观察）

```bash
/usr/local/bin/falco -c /etc/falco/falco.yaml
```

另开一个终端执行触发动作（示例：写 `/etc`）：

```bash
echo "falco-smoke-$(date +%s)" >> /etc/falco_healthcheck_test
```

通过标准：
- Falco 输出中出现对应告警（例如 “Write to etc”）。

### 4.1-bis 只读 rootfs 场景的冒烟动作（推荐）

当 `/` 为只读时，不要用“写 `/etc`”做冒烟；改用可写临时目录触发 `Execution from /tmp` 规则：

```bash
cat > /tmp/falco_smoke_exec.sh <<'EOF'
#!/bin/sh
echo falco-smoke
EOF
chmod +x /tmp/falco_smoke_exec.sh
/tmp/falco_smoke_exec.sh
```

若 `/tmp` 不可执行或不可写，可改用 `/run` 或 `/dev/shm`（以板子挂载策略为准）。

通过标准：
- Falco 输出/日志中出现类似 `Execution from /tmp` 的告警事件。

### 4.2 后台服务 + 日志通道验证

若启用了 JSON 输出配置（例如 `falco.json_output.board.yaml`）：

```bash
test -f /var/log/falco/falco_events.json && tail -n 20 /var/log/falco/falco_events.json
```

或看 systemd 日志：

```bash
journalctl -u falco -n 200 --no-pager | grep -Ei 'Warning|Error|Write to etc|Execution from /tmp'
```

通过标准：
- 至少一个通道（stdout / journal / json）可看到触发事件。

---

## 5) 快速故障定位表（部署同事常用）

| 现象 | 优先怀疑 | 先做什么 |
|---|---|---|
| `Invalid module format` | `.ko` 与板端内核版本不一致 | 比对 `modinfo falco.ko` 的 `vermagic` 与 `uname -r` |
| `Unknown symbol tracepoint_*` | 内核没开 TRACEPOINTS/TRACING | 检查 `/proc/config.gz`，必要时重编内核 |
| `error opening device /dev/falco0` | kmod 未加载成功 | `insmod` + `lsmod` + `/dev/falco0` |
| `PPM_IOCTL_GET_API_VERSION` | 新旧 falco.ko / 用户态版本不一致 | `rmmod falco; rmmod scap; insmod 当前 falco.ko` |
| `Plugin requirement not satisfied: container` | 规则依赖 container，但插件未加载 | 对齐 `load_plugins` 与 `rules_files` |

---

## 6) 建议交付流程（每次发布都执行）

1. 主机侧执行“第 1 章”全部检查并截图/留档。  
2. 部署后执行“第 2 章 + 第 3 章”并保存日志。  
3. 跑“第 4 章冒烟测试”并留证据（告警日志）。  
4. 任一步失败，按“第 5 章”优先排查，不要盲目重装。

---

## 7) 关联文档

- `board_test/EMBEDDED_TEST_LOG.md`
- `board_test/KERNEL_CONFIG_TDA4_FALCO.md`
- `board_test/README.md`
- `board_test/KMOD_PAIN_POINTS_SUMMARY.md`
