# Changelog

## v1.0.0 — 2026-11-12

首个开源版本。

### 新增

- 一键部署：`1-一键部署.cmd` / `Deploy-RELab.ps1`
- 一键启动：`2-一键启动.cmd` / `Start-RELab.ps1`
- 一键卸载：`3-一键卸载.cmd` / `Uninstall-RELab.ps1`
- 简体中文启动菜单，带工具用途说明
- 新手速查表：`新手速查表.md`，菜单按 `H` 打开
- 安装校验：`Verify-RELab.ps1`
- 安装报告：`install-report.json`
- 部署日志：`deploy.log`

### 工具

- Ghidra 12.2
- radare2 6.2.6
- Cutter 2.5.0（自带简体中文）
- x64dbg 2026-05-27
- ImHex 1.38.1
- jadx 1.5.6（含 JRE）
- Apktool 3.0.3
- ILSpy 11.2
- dnSpyEx 6.6.0
- Kaitai Struct Compiler 0.11
- Temurin JDK 25.0.5
- Python 3.12.10 + mitmproxy、androguard、frida-tools、construct、blackboxprotobuf、scapy、kaitaistruct、LIEF
- Node.js 22.14.0 + asar、webcrack

### 下载

- GitHub Releases 多线程分段下载
- 下载缓存与失败重试
- 默认 GitHub 加速代理，可通过 `-NoProxy` 关闭
- Ghidra 官方 SHA-256 校验
- 代理失败自动回退单连接下载

### 卸载

- 只停止本项目 `tools\` 下的进程
- 调用 Python 官方卸载程序
- 删除工具、缓存和生成配置
- 保留启动脚本和文档

### 文档

- `README.md`：项目介绍、快速开始、工具表、FAQ
- `docs/ARCHITECTURE.md`：实现原理与扩展方式
- `docs/FAQ.md`：常见问题
- `THIRD_PARTY.md`：第三方工具许可证
- `SECURITY.md`：安全说明
- `CONTRIBUTING.md`：贡献指南

### 已知限制

- 仅支持 Windows 10/11 x64。
- Ghidra 官方无简体中文界面。
- 默认代理是第三方服务，可能不可用。
- Wireshark/Npcap、binwalk v3、unblob、FirmAE、OpenOCD/flashrom 未自动安装。
