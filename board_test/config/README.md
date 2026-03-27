# Board-specific Falco config (embedded / no container)

Used when deploying Falco to the TI-TDA4VM (or other aarch64 embedded) board.

- 当前项目仅使用 `kmod` 路径，不再使用 modern eBPF 配置。

- **falco.embedded.board.yaml** – `engine.kind: kmod`，使用内核模块（需 falco.ko）。

- **falco_rules_embedded.yaml** – 主机侧规则（无 `container.*`），用于嵌入式/无容器场景。

- **falco.container_plugin.board.yaml** – 当板上有 aarch64 `libcontainer.so` 时使用：启用 container 插件、完整规则；可与 kmod 搭配。

- **falco.nodriver.board.yaml** – `engine.kind: nodriver`，不加载内核驱动、不采集 syscall；用于 kmod 报 PPM_IOCTL_GET_API_VERSION 时临时验证 Falco 能否启动（部署后板上有 `/opt/falco-test/falco.nodriver.board.yaml`，可覆盖到 `config.d` 使用）。

- **falco.json_output.board.yaml** – 开启 `json_output: true` 并将告警写入 **`/var/log/falco/falco_events.json`**（JSONL，便于合规/审计）。部署时会一并放入 `config.d/`；板端需 `mkdir -p /var/log/falco` 并重启 Falco。主机拉取 JSON 日志：`./collect_falco_json_log.sh [output.jsonl]`。

**kmod 路径：** 若使用 `engine.kind: kmod`，需为板子内核编并部署 falco.ko（见 [falcosecurity/libs](https://github.com/falcosecurity/libs) driver 或 driverkit），并放到 `/usr/share/falco/` 等；`falco-start.sh` 会在存在时尝试加载。
