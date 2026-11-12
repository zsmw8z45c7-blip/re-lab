# 第三方工具与许可证

RE Lab 本身只包含 PowerShell/批处理脚本和文档，**不包含、不再分发**下表中的第三方二进制文件。

部署脚本会从各项目的官方 GitHub Releases 或官方站点下载这些工具。下载和使用时，请遵守对应项目的许可证。

> 下表为整理时的版本和许可证信息，仅作参考；以各项目上游的最新 LICENSE 为准。

## 核心工具

| 工具 | 版本 | 许可证 | 官方来源 |
|---|---|---|---|
| Ghidra | 12.2 | Apache-2.0 | https://github.com/NationalSecurityAgency/ghidra |
| radare2 | 6.2.6 | LGPL-3.0 | https://github.com/radareorg/radare2 |
| Cutter | 2.5.0 | GPL-3.0 | https://github.com/rizinorg/cutter |
| x64dbg | 2026-05-27 | GPL-3.0 | https://github.com/x64dbg/x64dbg |
| ImHex | 1.38.1 | GPL-2.0 | https://github.com/WerWolv/ImHex |
| jadx | 1.5.6 | Apache-2.0 | https://github.com/skylot/jadx |
| Apktool | 3.0.3 | Apache-2.0 | https://github.com/iBotPeaches/Apktool |
| ILSpy | 11.2 | MIT | https://github.com/icsharpcode/ILSpy |
| dnSpyEx | 6.6.0 | GPL-3.0 | https://github.com/dnSpyEx/dnSpy |
| Kaitai Struct Compiler | 0.11 | GPL-3.0 | https://github.com/kaitai-io/kaitai_struct_compiler |
| Eclipse Temurin JDK | 25.0.5 | GPL-2.0 with Classpath Exception | https://adoptium.net/ |

## Python 运行时与包

| 组件 | 版本 | 许可证 | 官方来源 |
|---|---|---|---|
| Python | 3.12.10 | PSF-2.0 | https://www.python.org/ |
| mitmproxy | 12.3.1 | MIT | https://github.com/mitmproxy/mitmproxy |
| androguard | 4.1.4 | Apache-2.0 | https://github.com/androguard/androguard |
| frida / frida-tools | 17.26.2 / 14.13.1 | 见上游（Frida 使用 wxWindows Library Licence） | https://github.com/frida/frida |
| construct | 2.10.70 | MIT | https://github.com/construct/construct |
| blackboxprotobuf | 1.0.1 | MIT | https://github.com/nccgroup/blackboxprotobuf |
| scapy | 2.8.0 | GPL-2.0 | https://github.com/secdev/scapy |
| kaitaistruct | 0.11 | MIT | https://github.com/kaitai-io/kaitai_struct_python_runtime |
| LIEF | 1.0.0 | Apache-2.0 | https://github.com/lief-project/LIEF |

## Node.js 运行时与包

| 组件 | 版本 | 许可证 | 官方来源 |
|---|---|---|---|
| Node.js | 22.14.0 | MIT | https://nodejs.org/ |
| asar | 3.2.0 | MIT | https://github.com/electron/asar |
| webcrack | 2.16.0 | MIT | https://github.com/j4k0xb/webcrack |

## 未自动安装的工具

以下工具在 README 中作为可选方案提及，但不属于默认部署内容：

| 工具 | 许可证 | 官方来源 |
|---|---|---|
| Wireshark | GPL-2.0 | https://www.wireshark.org/ |
| Npcap | 自定义（Free/Commercial） | https://npcap.com/ |
| binwalk | MIT | https://github.com/ReFirmLabs/binwalk |
| unblob | MIT | https://github.com/onekey-sec/unblob |
| FirmAE | MIT | https://github.com/pr0v3rbs/FirmAE |
| OpenOCD | GPL-2.0 | https://github.com/openocd-org/openocd |
| flashrom | GPL-2.0 | https://github.com/flashrom/flashrom |
| Playwright | Apache-2.0 | https://github.com/microsoft/playwright |

## 许可证合规提示

- 如果你把本项目的脚本打包进自己的产品，请保留本项目的 MIT LICENSE。
- 如果你另行分发第三方工具，请同时保留它们的 LICENSE/NOTICE，并遵守 GPL/LGPL 等许可证的源码提供义务。
- 不要把第三方二进制直接提交到本仓库；使用部署脚本按需下载，或使用 GitHub Releases/对象存储单独分发。
