# 常见问题

## 安装与网络

### 首次部署需要多久？

取决于网络。首次下载约 1.2 GB，解压后约 4 GB。使用默认多线程下载时，通常几分钟到十几分钟。

### 下载很慢或中断怎么办？

重新运行 `1-一键部署.cmd`。`downloads\` 中已完成的大文件会复用。

如果代理不可用，可以直连：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Deploy-RELab.ps1 -NoProxy
```

### 可以只装一部分工具吗？

目前提供：

```powershell
# 不装 Python 和 Node
.\Deploy-RELab.ps1 -SkipPython -SkipNode
```

其他工具按固定清单安装。需要更细粒度时可以修改 `Deploy-RELab.ps1`，参考 `docs/ARCHITECTURE.md` 的“新增一个工具”。

### 安装需要管理员权限吗？

不需要。工具安装在项目目录内，Python 使用 per-user 安装。

`x64dbg` 调试高完整性进程时需要管理员权限；右键 `2-一键启动.cmd` → 以管理员身份运行。

### 能把整个目录放到 D 盘或移动硬盘吗？

可以。移动后重新运行：

```powershell
.\Deploy-RELab.ps1
```

它会跳过已安装工具，只重建 `env.ps1` 和 `lab-manifest.json` 中的绝对路径。

---

## 启动与使用

### 双击后窗口一闪而过？

可能是 PowerShell 执行策略或文件被阻挡。右键 `1-一键部署.cmd` → 属性 → 勾选“解除锁定”，或者直接用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Deploy-RELab.ps1
```

### 提示“禁止运行脚本”？

启动器已经使用 `-ExecutionPolicy Bypass`。如果是手动执行 `. .\env.ps1`，请先打开：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass
```

### 菜单第 1 项 Ghidra 是英文的？

Ghidra 官方没有简体中文界面。新手建议先用第 2 项 **Cutter**，它自带简体中文。

社区有开发中的 Ghidra 汉化分支，但替换官方安装包可能带来兼容性和供应链风险，本项目不默认使用。

### Cutter 为什么是中文的？

Cutter 自带 `translations\cutter_zh_CN.qm`，在中文 Windows 上会自动加载。启动器把 Cutter 放在第 2 项。

### 看不懂 Ghidra/Cutter 的界面？

在启动菜单按 `H` 打开 `新手速查表.md`。里面按“我想做什么”给出了每个工具最短的操作路径。

### Ghidra 提示找不到 Java？

Ghidra 12.2 需要 JDK 25。确认：

```text
tools\jdk25\bin\java.exe
```

存在，并通过 `2-一键启动.cmd` 启动。启动器会设置 `JAVA_HOME`。

### x64dbg 打不开或不能调试？

- 确认 `tools\x64dbg\release\x64\x64dbg.exe` 存在。
- 调试高完整性进程时，以管理员身份运行启动器。
- 某些杀毒软件会拦截调试器，请核对来源，不要直接关闭防护。

### mitmweb 端口被占用？

默认端口是 8081。可以手动运行：

```powershell
. .\env.ps1
mitmweb --web-port 8082
```

### 能离线使用吗？

首次部署需要联网。部署完成后，工具本身可以离线运行；Python/Node 包也已安装在本地。

---

## 卸载

### 一键卸载会删除什么？

`3-一键卸载.cmd` 会删除：

- `tools\`
- `downloads\`
- `env.ps1`
- `lab-manifest.json`
- `install-report.json`
- `deploy.log`

它会先停止本项目启动的进程，并调用 Python 官方卸载程序。启动脚本和文档会保留。

### 会删除系统里的其他 Python 吗？

不会。卸载脚本只调用本项目 `downloads\python-3.12.10-amd64.exe` 的卸载程序，并只停止路径位于本项目 `tools\` 下的进程。

### 怎么彻底删除？

卸载完成后，直接删除整个 `RE-Lab` 文件夹。

### 卸载前想确认会删多少？

```powershell
.\Uninstall-RELab.ps1 -DryRun
```

---

## 安全与合规

### 杀毒软件报毒怎么办？

x64dbg、radare2、Frida 等工具常被启发式引擎误报。请：

1. 核对文件是否来自官方 Releases。
2. 核对 Ghidra 的 SHA-256。
3. 不要把整个目录加入信任区，除非你确认风险。

### 这些工具可以用来做什么？

仅用于对你拥有或已获授权分析的软件、恶意样本、CTF、互操作性研究。

不得用于绕过软件授权、DRM、他人系统的安全机制或实施攻击。

### 仓库里为什么不直接放工具二进制？

- 总体积约 4 GB，超过普通 Git 仓库的合理范围。
- GitHub 单文件限制 100 MB，很多工具文件超过限制。
- 第三方工具许可证不同，直接再分发需要额外的合规工作。
- 部署脚本从官方来源下载，更小、更透明、更容易更新。

---

## 开发与贡献

### 怎么新增一个工具？

参考 `docs/ARCHITECTURE.md` 第 10 节。

### 为什么提交后 `tools/` 和 `downloads/` 没上传？

它们在 `.gitignore` 中，属于本地生成内容，不应提交。

### 可以修改启动器菜单吗？

可以。中文说明在 `Start-RELab.ps1` 的 `$Descriptions` 哈希表中；菜单顺序来自 `lab-manifest.json` 的生成顺序。
