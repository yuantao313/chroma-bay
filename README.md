# ChromaBay

机箱 **2.5" 硬盘位 ARGB 灯控固件** —— 基于 Raspberry Pi Pico（RP2040），由 Windows 11 动态照明直接驱动。

本仓库是 [microsoft/RP2040MacropadHidSample](https://github.com/microsoft/RP2040MacropadHidSample) 的 fork，
去掉了 macropad 的键盘矩阵 / 旋钮编码器 / OLED / 扬声器部分，只保留 **HID LampArray 灯控** 这一条主线，
并把板级配置改到本项目的 ARGB 控制器上。

## 这是什么

一块用两颗 2.5 英寸硬盘位螺丝固定在机箱内的 ARGB 控制器。RP2040 驱动机箱灯条，对外是一个 USB 复合设备：

- **HID LampArray** —— 供 Windows 11「动态照明」识别，在系统设置里直接调光效。
- **CDC ACM** —— 串口维护通道，用于查询运行状态和免按键进入 BOOTSEL。

板载 GP25 心跳灯用于观察运行状态；看门狗复位后前 3 秒快闪，便于识别异常重启。

## 相对上游的改动

| 改动 | 说明 |
|---|---|
| 移除 `src/Keys/`、`src/Encoder/` | 无键盘、无旋钮，设备不再暴露 HID 键盘集合 |
| 移除灯泡/OLED 相关引脚与代码 | 上游 `macropad.c` 中的键盘轮询定时器、`keyboardTimerCallback` 全部删除 |
| `macropad.c` → `main.c` | 仅保留灯控主循环，并加入看门狗、hardfault 钩子、CDC 维护通道 |
| USB 报告描述符 | 去掉 `TUD_HID_REPORT_DESC_KEYBOARD`，只留 `TUD_HID_REPORT_DESC_LIGHTING` |
| VID/PID | 由上游的 `0xCafe` 派生 PID 改为 pid.codes 的 `1209:A16C` |
| LampArray 属性 | `LAMPARRAY_KIND` 由 Keyboard(1) 改为 Chassis(7)；灯位改为单排线性网格 |
| PIO 程序 | 新增 `ws2812_inverted` 变体，补偿本板输出级的反相 |

## 硬件

| 项目 | 说明 |
|---|---|
| 主控 | Raspberry Pi Pico（经典 RP2040，`PICO_BOARD=pico`） |
| ARGB 输出 | **GP28**，单路，8 灯（WS2812 / SK6812 类 800 kHz 灯珠） |
| 状态指示灯 | **GP25**（板载 LED，心跳） |
| 固定方式 | 机箱 2.5" 硬盘位螺丝孔 |
| USB 标识 | `1209:A16C`（pid.codes 社区 VID + 实验性 PID） |

**数据极性**：本板输出级对数据线做了反相，因此固件通过 `PHYSICAL_DATA_INVERTED` 输出反相波形补偿，
灯珠端仍得到标准 WS2812 极性。若改为直接驱动（无反相级），把该宏置 0 即可。

引脚、灯数等产品参数集中在 [`src/util.h`](src/util.h)。

## 构建

```powershell
powershell -File scripts/build-windows.ps1
```

依赖版本与获取方式见 [`docs/dependencies.md`](docs/dependencies.md)。产物：`build/chroma_bay.{elf,uf2,bin,map}`。

也可以手动构建：

```powershell
cmake -S src -B build -G Ninja -DPICO_BOARD=pico -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

## 烧录

1. 按住 Pico 的 **BOOTSEL** 键插入 USB（或按住后短按 RESET）。
2. 把 `build/chroma_bay.uf2` 复制到出现的 `RPI-RP2` 磁盘。
3. 设备自动重启并运行新固件。

也可以连上 CDC 串口（115200）发送 `B`，让固件直接跳进 BOOTSEL。

## 调试

CDC 维护通道：

| 输入 | 行为 |
|---|---|
| `?` | 打印一行状态：挂载状态、HID get/set 计数、启动次数、是否看门狗复位 |
| `B` | 重启进入 BOOTSEL 模式 |

`scripts/` 下另有主机侧探针脚本（Windows PowerShell），用于校验枚举出来的 HID 集合与 LampArray 属性。

## 目录结构

```text
├── src/
│   ├── CMakeLists.txt          # 固件构建入口，目标 chroma_bay
│   ├── main.c                  # 主循环、看门狗、HID/CDC 回调
│   ├── util.h                  # 产品配置：引脚、灯数、极性、LampArray 属性
│   ├── usb_descriptors.c/.h    # VID/PID、LampArray 报告描述符
│   ├── tusb_config.h           # TinyUSB 配置
│   └── Lighting/
│       ├── Neopixel.c/.h       # PIO 灯珠驱动与本地灯效
│       ├── neopixel.pio        # WS2812 时序程序（含反相变体）
│       ├── LampArray.c/.h      # HID LampArray 请求处理
│       └── LampArrayHidStructs.h
├── scripts/                    # 构建与调试脚本
├── docs/dependencies.md        # 依赖与版本锁定
├── LICENSE                     # MIT（Microsoft Corporation）
└── NOTICE.md                   # 第三方组件许可（TinyUSB / Raspberry Pi PIO）
```

## 功能

| 功能 | 代码位置 |
|---|---|
| Windows 原生交叉构建（无 MSVC） | `scripts/build-windows.ps1` |
| PIO 单路 WS2812 输出（GP28 × 8，含反相变体） | `src/Lighting/Neopixel.c`、`neopixel.pio` |
| HID LampArray 全部 6 个 report | `src/main.c`（GET 2 / SET 4）、`src/Lighting/LampArray.c` |
| 本地灯效（常亮 / 正弦呼吸） | `src/Lighting/Neopixel.c` |
| GP25 心跳 + 看门狗 + hardfault 捕获 | `src/main.c` |
| CDC 维护通道（`?` 查状态、`B` 进 BOOTSEL） | `src/main.c` |
| 启动计数与看门狗复位识别 | `src/main.c` |

## 范围

本固件的控制通道是 **HID LampArray**，面向 Windows 11 动态照明。
串口通道用于维护，不承载灯效数据；Adalight / OpenRGB 与配置文件持久化不在当前范围内。

## 许可与署名

本仓库派生自 Microsoft 的 RP2040 Macropad LampArray 示例，沿用 **MIT** 许可，
原始版权归 Microsoft Corporation，见 [`LICENSE`](LICENSE)。
`src/usb_descriptors.c/.h` 源自 TinyUSB（Copyright (c) 2019 Ha Thach），
`src/Lighting/neopixel.pio` 源自 Raspberry Pi pico-examples，
第三方组件的完整许可见 [`NOTICE.md`](NOTICE.md)，**这些声明必须随衍生作品保留**。

上游示例可作其他 RP2040 + NeoPixel 设备的模板，`Lighting/` 目录也可作为任何 TinyUSB 项目的起点：
<https://github.com/microsoft/RP2040MacropadHidSample>

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
