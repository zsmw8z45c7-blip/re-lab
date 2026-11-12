# 安全说明

## 报告问题

如果你发现本项目脚本存在安全问题，请不要在公开 Issue 中贴出利用细节、Token 或个人信息。

优先使用 GitHub 的 **Private vulnerability reporting / Security advisory** 功能联系维护者。

## 范围

本项目的安全范围包括：

- `Deploy-RELab.ps1` 的下载、校验、解压逻辑
- `Start-RELab.ps1` 的启动参数与路径处理
- `Uninstall-RELab.ps1` 的进程匹配与删除范围
- `env.ps1` / `lab-manifest.json` 的生成逻辑

不在范围内：

- Ghidra、Cutter、x64dbg、Frida 等第三方工具本身的漏洞
- 用户使用这些工具分析的目标软件
- 用户自行修改后的脚本

第三方工具的问题请报告给对应上游项目。

## 安全设计

- 只从官方 GitHub Releases 或官方站点下载。
- Ghidra 校验官方 SHA-256。
- 不修改系统 `PATH`，不写入 `Program Files`。
- 不自动修改 Windows Defender 或安全策略。
- 卸载时只停止路径位于本项目 `tools\` 下的进程。
- 不在仓库中保存 Token、Cookie、证书或用户数据。

## 第三方代理

默认使用 `ghproxy.imciel.com` 加速 GitHub Releases 下载。该代理是第三方服务，可能记录请求元数据。

对供应链安全要求高的环境，请使用：

```powershell
.\Deploy-RELab.ps1 -NoProxy
```

并自行核对上游发布的哈希/签名。

## 依赖与供应链

本项目不锁定第三方工具的二进制哈希（Ghidra 除外）。上游发布新版本后，下载内容可能变化。生产环境建议：

1. 固定版本 URL。
2. 在内部镜像中缓存并校验哈希。
3. 使用 `-NoProxy` 直连官方源。
4. 审查 `Deploy-RELab.ps1` 中的下载地址。

## 不要提交的内容

- GitHub Token、SSH 私钥
- Cookie、会话文件
- 用户数据、样本文件
- `tools/`、`downloads/` 中的第三方二进制
- `env.ps1`、`lab-manifest.json`、`install-report.json`、`deploy.log`
