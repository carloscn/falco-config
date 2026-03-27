# Board-Level Test (TI-TDA4VM)

板级部署与远程测试，与 **cross_compile**（仅负责编译）分离。

## 依赖

- Falco 已通过 **cross_compile** 编译：`cross_compile/install/` 下存在 `bin/falco`、`etc/falco`、`share/falco`
- 测试脚本：`board_test/test_cases/`（嵌入式 SYS-*.sh，带 check_falco_embedded）→ 板子 `test_cases/`，**`./run_tests_remote.sh cases` 会跑这一套**；`test/examples/`→ 板子 `cases/`；`test/test_cases/`→ 板子 `idps/`
- 板子可 SSH：在 `board.cfg` 中配置 IP、用户、密码（或密钥）

## 配置

编辑 `board.cfg`：

- **BOARD_IP**：板子 IP（默认 `192.168.1.3`）
- **BOARD_USER**：SSH 用户（默认 `root`）
- **BOARD_PASSWORD**：密码（留空则用密钥或无密码）
- **FALCO_INSTALL_DIR**：相对仓库根目录的 Falco 安装路径（默认 `cross_compile/install`）
- 板端路径：Falco 装到 `/usr/local/bin`、`/etc/falco`、`/usr/share/falco`，测试脚本放到 **BOARD_TEST_DIR**（默认 `/opt/falco-test`）

## 部署

部署时会安装 **falco-start.sh** 到板子 `${BOARD_TEST_DIR}/falco-start.sh`（默认 `/opt/falco-test/falco-start.sh`），用于无 systemd 时手动启动 Falco（会尝试自动加载 falco.ko）。

- **配置逻辑**：若 `cross_compile/install` 中存在 aarch64 的 `libcontainer.so`，则部署 container 插件 + 完整规则；否则部署嵌入式配置（无 container 插件、仅主机规则）。部署时会修正板端 `falco.yaml` 中的 `library_path`，避免主机路径。
- **驱动选择**：当前仅使用 `kmod`。请在配置中保持 `engine.kind: kmod`，并部署 `falco.ko`。
- **falco.ko**：若使用 kmod，需用 `cross_compile` 的 BUILD_KMOD=ON 编出 `install/share/falco/falco.ko`，部署会拷到板子 `/usr/share/falco/`；板端需加载该模块后 Falco 才能采集 syscall。

```bash
cd board_test

# 部署 Falco + 服务脚本 + 测试脚本（会覆盖板子上已有文件）
./deploy_to_board.sh

# 仅部署 Falco
./deploy_to_board.sh --falco-only

# 仅部署测试脚本
./deploy_to_board.sh --tests-only

# 仅部署规则 + JSON 输出配置（告警写入 /var/log/falco/falco_events.json，便于合规）
./deploy_to_board.sh --rules-only
# 板端执行 systemctl restart falco 后，主机拉取 JSON 日志：
./collect_falco_json_log.sh [输出文件.jsonl]
```

## 远程运行测试

```bash
cd board_test

# 运行全部 idps + cases
./run_tests_remote.sh

# 仅 IDPS 用例
./run_tests_remote.sh idps

# 仅 cases 用例（嵌入式 test_cases，含 Falco 运行检测）
./run_tests_remote.sh cases

# 单条用例（优先用 test_cases 里的 SYS-*.sh）
./run_tests_remote.sh SYS-PROC-001
./run_tests_remote.sh case1_sensitive_file_opening

# 先在板子上启动 Falco，再跑全部
./run_tests_remote.sh --start-falco all
```

若使用密码登录，需安装 `sshpass`：`apt install sshpass`。

## OTA / readonly rootfs 部署

若部署环境为 readonly rootfs（不能 SSH/SCP 在线覆盖），请使用 OTA 流程：

- 部署手册：`board_test/DEPLOYMENT_OTA_READONLY.md`
- 产物打包：`board_test/prepare_ota_bundle.sh`

示例：

```bash
cd board_test
./prepare_ota_bundle.sh --tar
```

生成 `falco_bundle_for_ota/`（以及可选 `falco_bundle_for_ota.tar.gz`），将其内容集成到固件/OTA 包。
