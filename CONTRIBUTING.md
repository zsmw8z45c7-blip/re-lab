# 贡献指南

感谢你愿意改进 RE Lab。

## 开发环境

- Windows 10/11 x64
- Windows PowerShell 5.1
- 可选：PowerShell 7 用于本地语法检查

## 提交前检查

1. 不要提交以下本地生成内容：

```text
tools/
downloads/
env.ps1
lab-manifest.json
install-report.json
deploy.log
```

2. 检查 PowerShell 语法：

```powershell
$files = Get-ChildItem -Recurse -Filter *.ps1
foreach ($file in $files) {
    $errors = $null
    $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$errors
    ) | Out-Null
    if ($errors) {
        $errors | Format-List
        throw "Parse failed: $($file.Name)"
    }
}
```

3. 在 Windows PowerShell 5.1 下运行：

```powershell
.\Deploy-RELab.ps1 -DryRun
.\Deploy-RELab.ps1
.\Verify-RELab.ps1
```

4. 如果新增或升级了工具，同步更新：

- `README.md` 的工具表
- `THIRD_PARTY.md`
- `CHANGELOG.md`

## 新增工具

参考 `docs/ARCHITECTURE.md` 第 10 节。要点：

- 在 `Deploy-RELab.ps1` 中添加官方下载 URL。
- 用 `Invoke-ToolBlock` 隔离失败。
- 用 `Find-File` 递归定位可执行文件，避免硬编码 ZIP 内部目录。
- 在 `New-Manifest` 中添加启动项。
- 在 `Start-RELab.ps1` 的 `$Descriptions` 中添加中文说明。
- 只使用官方 Releases 或官方站点。
- 如工具需要管理员权限、驱动或 Linux，请在 README 中标注，不要强行安装。

## 代码风格

- PowerShell 5.1 兼容，不使用 `??`、三元运算符等 PowerShell 7 语法。
- 脚本使用 ASCII 英文标识符和英文控制流；中文只出现在用户可见菜单/文档中。
- 中文 `.ps1` 文件保存为 UTF-8 with BOM，避免 Windows PowerShell 5.1 乱码。
- 批处理文件保持 ASCII 内容。
- 不修改系统 `PATH`、注册表安全设置或 Windows Defender 配置。

## Pull Request

- 一个 PR 只做一件事。
- 写清楚测试环境（Windows 版本、PowerShell 版本）。
- 附上 `Deploy-RELab.ps1 -DryRun` 或 `Verify-RELab.ps1` 的输出。
- 如果涉及 UI 变化，附截图或文字说明。

## 许可证

提交代码即表示你同意以本项目的 MIT License 发布你的贡献。
