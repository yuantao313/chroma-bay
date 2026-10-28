# Security

这是一个个人项目的衍生 fork，**并非** Microsoft 官方发布的产品。

## 报告问题

如果你在本仓库的代码里发现问题（例如灯效数据解析、USB 描述符），请直接在本仓库开 issue：

<https://github.com/yuantao313/chroma-bay/issues>

**请不要**向 Microsoft MSRC 报告本 fork 的问题 —— 本仓库的改动不由 Microsoft 维护，
MSRC 无法处理针对本 fork 的报告。

## 上游

上游项目为 [microsoft/RP2040MacropadHidSample](https://github.com/microsoft/RP2040MacropadHidSample)。
如果你发现的问题同样存在于上游原始代码中，请按上游的流程处理（见上游仓库的 `SECURITY.md`）。

## 范围说明

本固件没有网络栈，也不处理不可信输入：USB 报文由 TinyUSB 栈在固定长度的报告缓冲区内解析，
灯位数组的越界访问在 `NeopixelSetColor` / `NeopixelSetColorRange` 中做了上界检查。
