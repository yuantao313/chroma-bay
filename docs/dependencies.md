# 依赖与版本锁定

所有构建依赖固定版本，禁止跟踪 main/master 漂移。本文件是版本真值源。

## 固件依赖（源码级）

| 依赖 | 版本 | 获取方式 | 说明 |
|---|---|---|---|
| pico-sdk | **2.3.1**（tag，commit `079c6f3`） | `git clone https://github.com/raspberrypi/pico-sdk.git <PICO_SDK_PATH> && git checkout 2.3.1 && git submodule update --init --recursive` | RP2040 驱动与 CMake 集成 |
| TinyUSB | `86ad6e5`（pico-sdk 2.3.1 子模块锁定） | 随 pico-sdk 子模块 | HID + CDC 复合设备栈 |

上游示例要求手动把 pico-sdk 内的 TinyUSB 切到 `master` 才能拿到 LampArray 支持；
pico-sdk 2.3.1 已经包含该支持，**不需要**再做这一步，也不要跟踪 `master` 漂移。

## 主机工具（Windows 预编译，禁止本地编译触发 MSVC 依赖）

| 工具 | 版本 | 来源 | 暴露给 CMake 的方式 |
|---|---|---|---|
| picotool | 2.3.1 | [pico-sdk-tools v2.3.1-0](https://github.com/raspberrypi/pico-sdk-tools/releases/tag/v2.3.1-0) `picotool-2.3.1-x64-win.zip`，解压后含 `picotool/picotool` | `-Dpicotool_DIR=<PICOTOOL_DIR>` |
| pioasm | 2.3.1 | 同 release `pico-sdk-tools-2.3.1-x64-win.zip`，解压后含 `pioasm/pioasm` | `-Dpioasm_DIR=<PIOASM_DIR>` |

两者由 `scripts/build-windows.ps1` 自动传入；SDK 若找不到会尝试在主机本地编译并要求主机 C++ 编译器，必须避免。

## 工具链

| 工具 | 版本 | 安装方式 |
|---|---|---|
| arm-none-eabi-gcc | 14.2.Rel1（Arm GNU Toolchain） | `winget install Arm.GnuArmEmbeddedToolchain` |
| CMake | 4.4.4 | `winget install Kitware.CMake`（便携包，PATH 由构建脚本注入） |
| Ninja | 1.13.2 | `winget install Ninja-build.Ninja`（同上） |
| Python | 3.14.5 | 系统已装（供 `scripts/` 下的探针脚本使用） |
| Git | 2.54.0 | scoop（`%USERPROFILE%\scoop\apps\git\current\cmd`，PATH 由构建脚本注入） |

## 目标硬件

- Raspberry Pi Pico（经典 RP2040，`PICO_BOARD=pico`）
- ARGB DATA 输出：GP28（8 灯，单路）
- 状态指示灯：GP25（板载心跳）
- 输出通道为反相逻辑，GPIO 侧输出反相波形补偿（`src/util.h` 的 `PHYSICAL_DATA_INVERTED`）

## 复现构建

```powershell
# 环境就绪后（上表），仓库根目录：
powershell -File scripts/build-windows.ps1
# 产物：build/chroma_bay.{elf,uf2,bin,map}
```

脚本按顺序解析 `<PICO_SDK_PATH>`、`<PICOTOOL_DIR>`、`<PIOASM_DIR>`：
先取同名环境变量，未设置时回落到下表默认路径。

| 变量 | 默认值 |
|---|---|
| `PICO_SDK_PATH` | `%USERPROFILE%\pico\pico-sdk` |
| `PICOTOOL_DIR` | `%USERPROFILE%\pico\picotool\picotool` |
| `PIOASM_DIR` | `%USERPROFILE%\pico\pico-sdk-tools\pioasm` |
