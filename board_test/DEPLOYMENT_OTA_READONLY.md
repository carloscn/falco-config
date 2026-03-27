# Falco 部署手册（部署人员版，readonly rootfs / OTA）

本手册面向部署人员，适用于 **rootfs 不可写** 场景。  
原则：不使用 SSH/SCP 在线覆盖文件，统一通过 **固件构建/OTA** 更新 rootfs 内容。

---

## 1. 输入物与前提

你拿到的是一个部署压缩包，例如：`falco_bundle_for_ota.tar.gz`。

前提：
- 目标设备使用 systemd。
- 目标设备为 kmod 路径（需要 `falco.ko`）。
- rootfs 通过 OTA/固件方式更新，不做在线 SCP 覆盖。

> **重要声明（必须阅读）**  
> 本部署包中的 `falco`、`falcoctl`、`falco.ko` 仅为 **placeholder（占位文件）**，不作为最终可用交付物。  
> 部署前必须由公司指定的内核/编译负责人替换为本次版本对应的真实编译产物，否则会导致运行失败或与内核策略不一致。

---

## 2. 解包与文件落地
将压缩包解开后（假设目录名为 `falco_bundle_for_ota/`），把其中内容按同路径写入目标 rootfs：

- `/usr/local/bin/falco`（由内核/编译负责人提供并替换）
- `/usr/local/bin/falcoctl`（由内核/编译负责人提供并替换，若使用）
- `/usr/share/falco/falco.ko`（由内核/编译负责人提供并替换）
- `/usr/share/falco/plugins/*`（按需）
- `/etc/falco/*`
- `/etc/falco/config.d/falco.container_plugin.board.yaml`
- `/etc/falco/config.d/falco.json_output.board.yaml`
- `/etc/systemd/system/falco.service`
- `/opt/falco-test/falco-start.sh`
- `/opt/falco-test/load-falco-ko.sh`

注意：
- 当前项目是 **kmod-only**，必须包含 `falco.ko`。
- 不要混入 `modern_ebpf` 相关配置文件。
- 你拿到的部署包里不强制包含 `falco` / `falcoctl` / `falco.ko` 成品；这三个文件必须由公司指定的编译负责人按当前内核策略单独产出并替换到上述目标路径。
- `falco` / `falcoctl` / `falco.ko` 的编译流程请参考交叉编译文档：`cross_compile/README.md`（及配套说明文档）。

---

## 3. OTA 生效后目标机操作

```bash
systemctl daemon-reload
systemctl enable falco
systemctl restart falco
```

检查服务：

```bash
systemctl status falco --no-pager -l
journalctl -u falco -n 120 --no-pager
```

通过标准：
- `falco.service` 为 `active (running)`。
- 日志出现：`Opening 'syscall' source with Kernel module`。
- 无关键错误：`Invalid module format`、`Unknown symbol`、`PPM_IOCTL_GET_API_VERSION`、`error opening device /dev/falco0`。

---

## 4. 冒烟验证（部署后必须执行）

执行：

```bash
cat > /tmp/falco_smoke_exec.sh <<'EOF'
#!/bin/sh
echo falco-smoke
EOF
chmod +x /tmp/falco_smoke_exec.sh
/tmp/falco_smoke_exec.sh
```

查看告警：

```bash
journalctl -u falco -n 200 --no-pager | grep -E "IDPS|Warning|Exec from writable directory|Execution from /tmp"
```

通过标准：
- 能看到至少 1 条 Falco 告警日志。

---

## 5. 常见故障与处理

- `Invalid module format`  
  -> `falco.ko` 与运行内核版本不匹配，需使用对应内核重编 `falco.ko`。

- `Unknown symbol tracepoint_*`  
  -> 内核缺少 `CONFIG_TRACEPOINTS` / `CONFIG_TRACING`。

- `PPM_IOCTL_GET_API_VERSION`  
  -> 用户态 `falco` 与内核模块版本不一致，确认 OTA 中二者来自同一构建产物。

- `error opening device /dev/falco0`  
  -> 模块未加载成功，检查 `load-falco-ko.sh` 是否执行成功。

