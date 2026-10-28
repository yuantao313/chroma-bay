# Contributing

这是一个个人项目的衍生 fork，不是 Microsoft 官方仓库，因此**不适用** Microsoft CLA。

## 上游

本仓库派生自 [microsoft/RP2040MacropadHidSample](https://github.com/microsoft/RP2040MacropadHidSample)（MIT）。
如果你想改进的是原始示例的通用部分（LampArray 协议实现、TinyUSB 用法等），
建议直接向上游提 PR，这样能惠及更多派生项目。

## 向本仓库提交

- 开 issue 描述问题或想法，或直接提 PR。
- 保持改动聚焦：本项目只做「RP2040 + 单路 ARGB + LampArray」这一条线，
  键盘/旋钮/OLED 等 macropad 功能已刻意移除，不接受重新引入。
- 改动涉及板级引脚、灯数或极性时，请同步更新 `src/util.h` 与 `README.md` 的硬件表。
- 提交前请确认 `scripts/build-windows.ps1` 能编译通过。

## Code of Conduct

本项目沿用 [Contributor Covenant](https://www.contributor-covenant.org/) 的精神：
保持友善、就事论事。上游仓库采用的 Microsoft Open Source Code of Conduct 见
<https://opensource.microsoft.com/codeofconduct/>。
