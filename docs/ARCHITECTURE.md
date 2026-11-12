# 实现原理

本文说明 RE Lab 的脚本结构、部署流程、下载策略和扩展方式。面向想修改脚本或新增工具的贡献者。

## 1. 设计目标

1. **便携**：所有工具、Python、Node 都放在项目目录内，不写 `Program Files`，不修改系统 `PATH`。
2. **可重复**：重复运行部署脚本不会重复下载或破坏已有安装。
3. **可迁移**：整个目录移动到新位置后，重新运行部署脚本即可重建绝对路径。
4. **可卸载**：卸载脚本只处理本项目目录内的进程和文件。
5. **可审计**：安装结果写入 `install-report.json`，部署过程写入 `deploy.log`。
6. **中文优先**：启动器、说明、速查表使用简体中文；第三方工具保持官方原版。

## 2. 文件与职责

| 文件 | 职责 |
|---|---|
| `Deploy-RELab.ps1` | 下载、解压、安装 Python/Node 包、生成环境和清单 |
| `Start-RELab.ps1` | 读取清单，显示中文菜单，启动 GUI/命令行工具 |
| `Uninstall-RELab.ps1` | 停止本项目进程、卸载 Python、删除工具和缓存 |
| `Verify-RELab.ps1` | 检查清单中的路径是否存在，输出工具版本 |
| `1-一键部署.cmd` | 双击入口，调用 `Deploy-RELab.ps1` |
| `2-一键启动.cmd` | 双击入口，调用 `Start-RELab.ps1` |
| `3-一键卸载.cmd` | 双击入口，调用 `Uninstall-RELab.ps1` |
| `env.ps1` | 部署后生成：`RELAB_HOME`、`JAVA_HOME`、`PATH` |
| `lab-manifest.json` | 部署后生成：启动器菜单数据 |
| `install-report.json` | 部署后生成：每个组件的状态、版本、路径 |
| `deploy.log` | 部署过程 transcript |
| `downloads/` | 下载缓存，支持重复运行复用 |
| `tools/` | 解压后的工具目录 |

## 3. 部署流程

```text
Deploy-RELab.ps1
  ├─ 检查磁盘空间（至少 6 GB）
  ├─ 安装 JDK 25
  ├─ 安装核心工具
  │   ├─ Ghidra
  │   ├─ radare2
  │   ├─ Cutter
  │   ├─ x64dbg
  │   ├─ ImHex
  │   ├─ jadx
  │   ├─ ILSpy
  │   └─ dnSpyEx
  ├─ 安装 Apktool（依赖 JDK）
  ├─ 安装 Kaitai Struct Compiler（依赖 JDK）
  ├─ 安装 Python + pip 包（可选）
  ├─ 安装 Node.js + npm 包（可选）
  ├─ 生成 env.ps1
  ├─ 生成 lab-manifest.json
  ├─ 生成 install-report.json
  └─ 调用 Verify-RELab.ps1
```

每个核心工具都包在 `Invoke-ToolBlock` 中，单个工具失败不会中断后续工具。失败项会记录到安装报告，最终退出码为 1。

## 4. 下载策略

### 4.1 普通下载

`Get-RemoteFile`：

- 如果目标文件已存在且大于 1 MB，直接复用缓存。
- 使用 `curl.exe` 下载到 `.part`，成功后原子移动到目标文件。
- 支持主 URL + 一个 fallback URL。
- 失败会重试 3 次；支持 `-Force` 强制重新下载。

### 4.2 GitHub 多线程下载

`Get-RemoteFileFast`：

1. `HEAD` 请求获取 `Content-Length`。
2. 发送 `Range: bytes=0-0` 探测服务器是否支持 206。
3. 把文件分成 4 段，用 4 个 `curl.exe` 进程并发下载。
4. 每段校验字节数；失败段单独重试。
5. 按顺序拼接为 `.parallel` 文件。
6. 校验总大小；如果提供 SHA-256，再校验哈希。
7. 任一步失败，回退到 `Get-RemoteFile` 单连接下载。

`Get-GitHubAsset` 会在启用代理时，把 `https://github.com/...` 改写成：

```text
https://ghproxy.imciel.com/https://github.com/...
```

`-NoProxy` 时直接使用原 URL。

### 4.3 完整性校验

- **Ghidra**：下载后校验官方 SHA-256。
- **其他 ZIP**：校验下载大小，并通过 `System.IO.Compression.ZipFile` 解压验证归档可读。
- **Python/Node 安装包**：来自官方站点或清华镜像，校验下载大小。

> 第三方代理只用于加速下载。对安全要求高的环境建议使用 `-NoProxy`，并自行核对上游哈希。

## 5. 解压与目录扁平化

`Expand-ArchiveFlat`：

1. 解压到 `<目标>.__extract`。
2. 如果归档只有一个顶层目录，把该目录内容上移为目标目录。
3. 否则直接把解压结果作为目标目录。
4. 解压前删除旧目标目录，保证干净安装。

工具可执行文件不是硬编码到固定层级，而是通过 `Find-File -Root <工具目录> -Name <文件名>` 递归查找。这样上游改变 ZIP 内部目录结构时，脚本仍能定位。

## 6. 环境与清单

### `env.ps1`

```powershell
$env:RELAB_HOME = '<项目目录>'
$env:JAVA_HOME  = '<项目目录>\tools\jdk25'
$env:PATH       = '<各工具路径>;' + $env:PATH
```

使用绝对路径，因此目录移动后必须重新运行 `Deploy-RELab.ps1` 重新生成。

### `lab-manifest.json`

数组，每项：

```json
{
  "name": "Ghidra",
  "path": "<项目目录>\\tools\\ghidra\\ghidraRun.bat",
  "kind": "gui",
  "args": ""
}
```

`kind`：

- `gui`：`Start-Process` 直接启动，工作目录为可执行文件所在目录。
- `shell`：打开一个新的 PowerShell 窗口，先加载 `env.ps1`，再执行工具。

启动器的中文说明维护在 `Start-RELab.ps1` 的 `$Descriptions` 哈希表中。

## 7. 启动器

`Start-RELab.ps1`：

1. 加载 `env.ps1`。
2. 读取 `lab-manifest.json`。
3. `-List`：输出编号、工具、类型、中文说明。
4. `-Tool <名称>`：按名称或模糊匹配直接启动。
5. 无参数：进入中文菜单循环。
6. `H`：用记事本打开 `新手速查表.md`。
7. `0`：退出。

GUI 工具使用自身目录作为工作目录，避免找不到 `jre/`、`lib/`、`translations/` 等相对资源。

## 8. 卸载流程

`Uninstall-RELab.ps1`：

1. 计算 `tools\` 和 `downloads\` 大小。
2. 非 `-Yes` 时要求输入 `YES`。
3. 枚举进程：
   - 可执行文件路径位于 `tools\` 下，或
   - 命令行包含项目根目录。
4. 跳过当前进程和父进程，避免卸载脚本自杀。
5. 停止匹配进程。
6. 调用 `downloads\python-3.12.10-amd64.exe /uninstall /quiet` 清理 Python per-user 安装项。
7. 删除 `tools\`、`downloads\`。
8. 删除 `env.ps1`、`lab-manifest.json`、`install-report.json`、`deploy.log`。
9. 保留启动脚本和文档，方便重新部署。

`-DryRun` 只打印将删除的内容和大小，不执行删除。

## 9. 安全不变量

- 不调用 `setx`，不修改系统环境变量。
- 不写入 `Program Files`。
- 不自动修改 Windows Defender 排除项。
- 不下载来源不明的可执行文件；所有 URL 固定为官方 Releases 或官方站点。
- 不把第三方二进制提交到 Git；`.gitignore` 排除 `tools/` 和 `downloads/`。
- 卸载只停止路径位于本项目内的进程。

## 10. 新增一个工具

以新增 `example.exe` 为例：

1. 在 `Deploy-RELab.ps1` 顶部添加下载 URL 变量。
2. 在 `Install-CoreTools` 中添加 `Invoke-ToolBlock`：

```powershell
Invoke-ToolBlock 'Example' {
    Write-Step 'Example'
    $e = Ensure-ZipTool -Name 'Example 1.0' `
        -Url $ExampleUrl `
        -ZipFile 'example.zip' `
        -Folder 'example' `
        -ExeName 'example.exe'
    Add-Report 'Example' 'ok' $e.Exe '1.0'
    Write-Ok $e.Exe
}
```

3. 在 `New-Manifest` 中添加：

```powershell
Add-Entry 'Example' (Find-File (Join-Path $ToolsDir 'example') 'example.exe') 'gui'
```

4. 在 `Start-RELab.ps1` 的 `$Descriptions` 中添加中文说明。
5. 更新 `README.md` 和 `THIRD_PARTY.md`。
6. 在 Windows PowerShell 5.1 下运行：

```powershell
.\Deploy-RELab.ps1 -DryRun
.\Deploy-RELab.ps1
.\Verify-RELab.ps1
```

## 11. 目录迁移

把整个目录移动到新位置后：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Deploy-RELab.ps1
```

部署脚本会检测到工具已存在，跳过下载/解压，只重新生成 `env.ps1` 和 `lab-manifest.json` 中的绝对路径。

## 12. 已知限制

- 仅支持 Windows 10/11 x64。
- Ghidra 需要 JDK 25；脚本会下载 Temurin JDK 25。
- Cutter 的中文界面依赖其自带 `zh_CN` 翻译文件。
- Ghidra 官方没有简体中文界面。
- 默认代理 `ghproxy.imciel.com` 是第三方服务，可能不可用；可用 `-NoProxy`。
- 大型 GUI 工具首次启动可能较慢，尤其是 Ghidra。
- 卸载后保留脚本和文档；如需彻底删除，手动删除整个目录。
