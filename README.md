# MatePad 11 (DBY-W09) → Kubuntu 24.04 移植实战指南

<p align="center">
  <b>华为 MatePad 11 (DBY-W09 / SM8250) 从 HarmonyOS 4.2 到可日常使用的 Kubuntu 平板</b><br>
  基于社区移植项目的完整实机部署记录 · 补充上游文档缺失的 20+ 处问题
</p>

<p align="center">
  <img alt="device" src="https://img.shields.io/badge/device-DBY--W09%20%2F%20SM8250-blue">
  <img alt="os" src="https://img.shields.io/badge/OS-Kubuntu%2024.04.5%20LTS-orange">
  <img alt="kernel" src="https://img.shields.io/badge/kernel-7.0.14--dby--w09-green">
  <img alt="status" src="https://img.shields.io/badge/status-daily%20driver-brightgreen">
</p>

---

## ⚡ 本项目与上游教程最大的区别

> ### 彻底放弃 HarmonyOS，把平板**真正变成一台 Ubuntu 平板**
>
> 上游移植项目走的是**双系统路线**：Linux 装在 microSD 卡上，开机先进鸿蒙，
> 再由鸿蒙里的 App 或桌面图标"重启到 Linux"。鸿蒙始终占着内部 256 GB 存储，
> Ubuntu 只能挤在 SD 卡上，而且每次开机都要过一道鸿蒙。
>
> **本项目做的是彻底替换：**
>
> - **删除鸿蒙的所有入口** —— 桌面图标、应用菜单项、`/usr/local/sbin/matepad-boot-harmonyos`、
>   内置的鸿蒙引导镜像目录，全部清除
> - **接管内部 256 GB 存储** —— 把鸿蒙的 `userdata`（225.8 GB）格式化为 ext4，
>   挂载为 `/data`，成为 Ubuntu 的数据盘
> - **开机直接进 Ubuntu** —— 按下电源键 → ABL → 内核 → Plasma 桌面，
>   中间**不经过鸿蒙、不需要任何选择菜单**，12.5 秒到桌面
> - **鸿蒙镜像仅作冷备份** —— 完整备份在 PC 上（`firmware/tablet-harmonyos-images/`，
>   SHA256 与出厂一致），只在需要彻底回退时才用得上
>
> ### 这意味着什么
>
> | 维度 | 上游双系统方案 | **本项目（彻底替换）** |
> |---|---|---|
> | 开机流程 | 鸿蒙 → 选单/App → 重启 → Linux | **电源键 → Ubuntu 桌面** |
> | 可用存储 | SD 卡 58 GB | **SD 58 GB + UFS 222 GB = 280 GB** |
> | 存储速度 | SD 卡（UHS-I，~90 MB/s） | **应用与数据在 UFS 3.1（~800 MB/s）** |
> | 鸿蒙残留 | 完整系统占 7.2 GB + 用户数据 | **全部清除，仅 PC 侧冷备份** |
> | 系统复杂度 | 两套系统、两套引导、两套数据 | **单一系统，无双重引导** |
> | 使用心智 | "我在用一台刷了 Linux 的鸿蒙平板" | **"我在用一台 Ubuntu 平板"** |
>
> ### 代价与前提
>
> - **鸿蒙用户数据不可恢复**（格式化 `userdata` 是单向的）。除非事先做了 LUN0 的
>   完整 EDL 备份（约 226 GB），否则原鸿蒙里的照片、文档、应用数据全部丢失
> - 回退只能"刷回鸿蒙系统"，得到的是**出厂状态**的鸿蒙，不是原来的鸿蒙
> - 需要接受"这台平板以后就是 Linux 设备"这个前提
>
> > 如果你还想保留鸿蒙可随时切换，请按上游的双系统教程做，不要用本手册的
> > [第 10 章](#10-阶段九内部存储接入-上游无此章节)。两者的分岔点就在这里。
>
> ### 一句话总结
>
> 上游解决的是"**让 Linux 能在这台平板上跑起来**"；
> 本项目解决的是"**让这台平板变成一台 Linux 平板**"。
> 差别不在技术难度，而在**是否愿意放弃鸿蒙**。

---

## 目录

- [0. 概览](#0-概览)
  - [0.1 这份文档是什么](#01-这份文档是什么)
  - [0.2 功能支持矩阵](#02-功能支持矩阵)
  - [0.3 ★ 相对上游教程的改动清单](#03--相对上游教程的改动清单)
  - [0.4 实测环境](#04-实测环境)
- [1. 前置准备](#1-前置准备)
- [2. 阶段一：降级到 HarmonyOS 2.0](#2-阶段一降级到-harmonyos-20)
- [3. 阶段二：EDL 全盘备份](#3-阶段二edl-全盘备份)
- [4. 阶段三：写入解锁 ABL](#4-阶段三写入解锁-abl)
- [5. 阶段四：回刷 HarmonyOS 4.2](#5-阶段四回刷-harmonyos-42)
- [6. 阶段五：制作 microSD 启动盘](#6-阶段五制作-microsd-启动盘)
- [7. 阶段六：构造引导镜像（核心）](#7-阶段六构造引导镜像核心)
- [8. 阶段七：首次启动](#8-阶段七首次启动)
- [9. 阶段八：外设适配](#9-阶段八外设适配)
- [10. 阶段九：内部存储接入（★ 上游无此章节）](#10-阶段九内部存储接入-上游无此章节)
- [11. 阶段十：系统调优（★ 上游无此章节）](#11-阶段十系统调优-上游无此章节)
- [12. 阶段十一：应用生态（★ 上游无此章节）](#12-阶段十一应用生态-上游无此章节)
- [13. 故障排查手册](#13-故障排查手册)
- [14. 回退与救援](#14-回退与救援)
- [15. 已知限制](#15-已知限制)
- [16. 附录：速查表](#16-附录速查表)
- [17. 参考与致谢](#17-参考与致谢)

---

## 0. 概览

### 0.1 这份文档是什么

官方/上游社区已经提供了 MatePad 11 的 Linux 移植（内核、设备树、Kubuntu 镜像）。但**上游文档只覆盖到"能开机"**，从"能开机"到"能当平板用"之间还有大量空白：背光芯片型号对不上、键盘打不出字、触摸坐标镜像、内部 256 GB 存储完全用不了……

这份文档记录了一次**完整的实机部署**（2026-11-05 → 2026-11-08），内容包括：

- 上游教程的完整流程（整理、校验、补全）
- **上游没有写、但会卡住你的 20+ 处问题**及解决方案
- 我们做的**适配性改造**与**性能优化**，每项都标注了回退方式
- 一个可日常使用的最终形态：显示/触摸/笔/键盘/Wi-Fi/蓝牙/222 GB 数据盘/中文输入法/开发环境

> **阅读建议**：如果你只是照着上游教程刷机，请**先读 [0.3 改动清单](#03--相对上游教程的改动清单)**，那里列出的每一项都是实机上会真实卡住你的点。

### 0.2 功能支持矩阵

图例：✅ 完全可用 · ⚠️ 可用但有缺陷 · ❌ 不可用

| 功能 | 状态 | 说明 | 来源 |
|---|---|---|---|
| 启动 | ✅ | microSD 引导，冷启动 ~12.5 s | 上游 |
| 显示 | ✅ | 1600×2560，LP8556 背光，硬件加速 | 上游 + **本手册修复** |
| 触摸 | ✅ | 已校准 | 上游 + **本手册校准** |
| M-Pencil | ✅ | 配对、压感、校准 | 上游 + **本手册校准** |
| Wi-Fi | ✅ | QCA6390，开机自动连接 | 上游 |
| 蓝牙 | ✅ | 键盘/鼠标/笔 | 上游 + **本手册补丁** |
| 键盘快捷键 | ✅ | Fn 键、音量键、亮度键 | **本手册实现** |
| 亮度调节 | ✅ | Fn+1/Fn+2、随息屏自动关背光 | **本手册实现** |
| 内部存储 | ✅ | UFS 222 GB 挂载为 `/data` | **本手册突破** |
| 声音 | ✅ | 扬声器、耳机、HDMI | 上游 |
| 摄像头 | ✅ | 前后摄像头 | 上游 |
| 外接显示器 | ✅ | USB-C DP | 上游 |
| 硬件视频解码 | ✅ | Venus | 上游 |
| **深度睡眠** | ❌ | 只有 s2idle，SoC 进不了 CX 塌陷 | 内核空白，未解决 |
| **待机功耗** | ⚠️ | 息屏已优化，亮屏仍高于鸿蒙 | 部分优化 |
| Office 文档转换 | ⚠️ | 需 LibreOffice（第三方应用） | 应用层 |

### 0.3 ★ 相对上游教程的改动清单

> 这是本文档的核心价值。**每一项都是实机上真实踩到的坑**，不是理论推测。

#### A. 会导致「刷完开不了机」的问题

| # | 问题 | 上游文档 | 本手册 |
|---|---|---|---|
| A1 | boot header `extra_cmdline` 偏移写错（`0x2C0` vs 实际 `0x260`），导致 `dtb_size`/`dtb_addr` 被清零 | ❌ 未提及 | ✅ [7.1](#71-boot-分区) 给出完整字段表 |
| A2 | DTB `qcom,board-id` 必须为 `<0x206a 0x0>`，否则 `Unable to find the Board Dtb` | ❌ 未提及 | ✅ [7.2](#72-dtb-改造三项) |
| A3 | 原厂 dtbo 覆盖层引用 **166 个**下游专有符号，必须补桩节点并**全部重定向** | ⚠️ 只提到"可能缺符号" | ✅ [7.2](#72-dtb-改造三项) 给出完整做法与副作用 |
| A4 | 符号不重定向 → PMIC 节点重复 → **SD 卡不识别** | ❌ 未提及 | ✅ 关键副作用说明 |
| A5 | dtbo 根 `compatible` 必须是 `qcom,sm8250\0huawei,dby-w09`（**NUL 分隔，不能用逗号**） | ❌ 未提及 | ✅ [7.3](#73-dtbo-分区) |

#### B. 会导致「能开机但没法用」的问题

| # | 问题 | 上游文档 | 本手册 |
|---|---|---|---|
| B1 | **背光芯片型号有硬件变体**：部分机器是 RT8555@0x31，本机是 **LP8556@0x2C** | ❌ 只说 RT8555 | ✅ [9.1](#91-背光最关键的一步) 给出判别方法与两套方案 |
| B2 | 蓝牙适配器 DOWN（`local-bd-address` 全 0） | ❌ 未提及 | ✅ [9.3](#93-蓝牙适配器) |
| B3 | 蓝牙键盘「已连接但打不出字」（bluez 需打 `hog-ccc-read-error` 补丁） | ⚠️ 有补丁包但没说明症状 | ✅ [9.4](#94-蓝牙键盘) |
| B4 | 触摸坐标 180° 镜像 | ❌ 未提及 | ✅ [9.2](#92-触摸校准) |
| B5 | M-Pencil **不会出现在"添加设备"里**，必须按地址配对 | ❌ 未提及 | ✅ [9.5](#95-m-pencil-触控笔) |
| B6 | 笔与触摸屏是**两个独立设备**，需要各自的校准规则 | ❌ 未提及 | ✅ [9.5](#95-m-pencil-触控笔) |

#### C. 上游完全没有的章节

| # | 内容 | 本手册 |
|---|---|---|
| C1 | **内部 256 GB UFS 接入**（首次探测失败，二次绑定成功） | ✅ [10](#10-阶段九内部存储接入-上游无此章节) |
| C2 | UFS 分区改造为 ext4 `/data` | ✅ [10.2](#102-格式化-userdata-为-data) |
| C3 | **systemd 排序环**导致 Wi-Fi/SSH 静默丢失 | ✅ [10.3](#103-开机自动挂载的坑排序环) |
| C4 | zram 配置（内核原本没编 `CONFIG_ZRAM`） | ✅ [11.1](#111-内存zram) |
| C5 | 背光随 DPMS 自动关闭（省电最大项） | ✅ [11.2](#112-背光随息屏关闭) |
| C6 | SD 卡写入策略调优 | ✅ [11.3](#113-sd-卡写入策略) |
| C7 | **Docker 不可用** → 改用 Podman | ✅ [12.3](#123-容器docker-不可用改用-podman) |
| C8 | 中文输入法（fcitx5 + Ctrl+空格） | ✅ [12.1](#121-中文输入法) |
| C9 | Flutter 应用中文方块字修复 | ✅ [12.5](#125-flutter-应用中文方块字) |
| C10 | 系统监视器磁盘显示 `0B/0B` 的源码级修复 | ✅ [11.4](#114-系统监视器磁盘显示-0b0b) |
| C11 | 软件与数据统一放 `/data` 的存储策略 | ✅ [10.4](#104-存储策略) |
| C12 | 键盘按键完整映射表与验证方法 | ✅ [9.6](#96-键盘按键映射) |

#### D. 我们做的性能优化

| # | 优化 | 效果 | 回退 |
|---|---|---|---|
| D1 | 背光随 DPMS 关闭 | 息屏不再满功率烧背光（**最大收益**） | 停用 `matepad-panelbacklightd` |
| D2 | zram 2 GB (lzo-rle) | 交换走内存压缩，不卡 SD 卡 | `rollback-optimizations.sh zram` |
| D3 | `/data` noatime | 减少 UFS 元数据写入 | `... data-noatime` |
| D4 | 脏页比例 20/10 → 10/5 | 减少 SD 卡一次性回写卡顿 | `... writeback` |
| D5 | 精简自启（Discover/geoclue） | 省 ~40 MB 常驻内存 | `... autostart` |
| D6 | 内核补丁 1097/1098（camcc/dsi_phy XO 投票） | 释放一个永久时钟投票 | 刷回 `boot-bt.img` |
| D7 | 软件/数据迁移到 `/data` | SD 卡从 17 GB 降到 15 GB | 见 [10.4](#104-存储策略) |

#### E. 我们**尝试但放弃**的方案（避免你重复踩坑）

| 尝试 | 结果 | 结论 |
|---|---|---|
| 重编内核补 netfilter NAT 让 Docker 能用 | 触发 `nft_socket`/`ip_tunnel`/`sit` 等模块连锁缺符号 | ❌ 放弃，改用 Podman |
| 打 pocknix PR #161 补丁进深睡 | `bi_tcxo` 投票 19→18，但 `cxsd` 仍为 0 | ⚠️ 部分生效，cluster cpuidle 缺失是内核空白 |
| 静态 IP | 平板需移动使用，换网络即失效 | ❌ 已回滚，保持 DHCP |
| 换 LXQt/XFCE 轻量化 | 只省 200-300 MB，丢失触屏/键盘/背光联动 | ❌ 不划算 |
| 找回"丢失的 2 GB 内存" | 实为 XBL/SBL1 层 DDR 配置，改动即变砖 | ❌ 不做 |
| 修改 GPT 分区表扩大 boot 分区 | 风险高收益低 | ❌ 不做 |

### 0.4 实测环境

```
设备        Huawei MatePad 11 (DBY-W09)
SoC         Qualcomm SM8250 (kona) / Adreno 650
内存        6 GB DDR（bootloader 报告 ddr_total_size=6144，非标称 8 GB）
存储        256 GB UFS 3.1 + 64 GB microSD (U3/A2)
屏幕        10.95" 1600×2560 IPS，120 Hz
笔          HUAWEI M-Pencil (第二代)
键盘        HUAWEI MatePad Keyboard (蓝牙)
起始系统    HarmonyOS 4.2.0.213(C00E100R2P5)
目标系统    Kubuntu 24.04.5 LTS
内核        Linux 7.0.14-dby-w09
```

---

## 1. 前置准备

### 1.1 风险声明

> ⚠️ **刷机有变砖风险。请先完整读完本节再动手。**

| 操作 | 风险 | 后果 |
|---|---|---|
| 降级到 HarmonyOS 2.0 | 中 | 清空用户数据 |
| EDL 写 ABL | **高** | 写错会变砖，只能靠 EDL 救 |
| 刷入第三方引导镜像 | 中 | 失败停在 FASTBOOT，可回退 |
| **解锁后升级鸿蒙** | **禁区** | 会写回官方 ABL 并重新上锁，可能永久失去 EDL |

**三条红线（任何一条都会让机器变砖或失去救援能力）**

1. **绝不刷固件包里的原版 `ABL_0.img`**（上锁版；解锁版 SHA256 不同）
2. **解锁后不 OTA、不让 HiSuite 升级**（会写回官方 ABL）
3. **没做完 EDL 全盘备份，不许改 GPT**

### 1.2 必须备份的东西

- **全盘 6 个 LUN 的 EDL 备份**（约 12.5 GB）—— 没有它不要进行任何后续操作
- 原厂三个分区镜像：`boot.img` / `ramdisk.img` / `dtbo.img`
- 解锁 ABL 的 SHA256（用于校验）

### 1.3 硬件清单

| 项目 | 要求 | 说明 |
|---|---|---|
| MatePad 11 | DBY-W09 | 其他型号不适用 |
| microSD 卡 | ≥ 32 GB，推荐 64 GB U3/A2 | 系统盘，**会被整卡擦除** |
| 读卡器 | — | 写镜像用 |
| USB 数据线 | 支持数据传输 | 不是充电线 |
| 外接键盘（可选） | USB 或蓝牙 | 首次启动调试用 |
| PC | Windows 10/11 | 刷机主机 |

### 1.4 软件清单（PC 侧）

| 软件 | 用途 | 备注 |
|---|---|---|
| HiSuite 14.x | 逐级降级 | 华为官方 |
| MatePad 11 综合工具箱 1.3.0 | 解锁 loader、ABL | 内含 `kptools`、`APatch.apk` |
| `bkerler/edl` | EDL 读写 | Python，需 `libusb-1.0.dll` |
| adb / fastboot | 刷机 | platform-tools |
| Zadig | 给 EDL 设备绑 WinUSB 驱动 | ⚠️ 见 [3.1](#31-进入-edl) |
| Python 3.8+ | 跑脚本 | — |

### 1.5 固件清单

| 文件 | 大小 | 说明 |
|---|---|---|
| HarmonyOS 2.0.0.265 | ~5 GB | HiSuite 提供，用于取得 EDL 权限 |
| HarmonyOS 4.2.0.208 **Fastboot UBL FlashROM** | ~5 GB | 分分区镜像包，**不含 abl** |
| `kubuntu-dby-w09-*.img.xz` | ~3 GB | Kubuntu 镜像 |
| `linux-boot-7.0.14-dby-w09.tar` | ~20 MB | 内核包（`Image.gz`、DTB、DTBO、cmdline、initramfs） |

> 💡 **获取提示**：`.dbk` 文件其实就是 ZIP（头四字节 `50 4b 03 04`），改后缀即可解压。
> HiSuite 下载的包在 `C:\Users\<你>\Documents\HiSuite\ROM\`。

---

## 2. 阶段一：降级到 HarmonyOS 2.0

> **为什么必须降级**：只有 2.0 允许 `adb reboot edl`，这是打通 EDL 的前提。
> 4.2 上执行这条命令会被 ABL 拒绝。

### 2.1 操作步骤

1. PC 安装 HiSuite，平板开启「USB 调试」，连接。
2. HiSuite → 系统更新 → **切换到其他版本** → 更多版本。
3. 逐级降级（**每级完成后再点一次「切换到其他版本」**）：

| 级 | 目标版本 | 包大小 | 备注 |
|---|---|---|---|
| 1 | `4.0.0.136(C00E125R1P5)` | ~5.15 GB | 第一次可能失败（包被推到外置卡）→ 确认卡已拔后重试 |
| 2 | `3.0.0.301(C00E200R1P12)` | ~4.89 GB | |
| 3 | `2.0.0.265(C00E210R1P13)` | ~5.06 GB | 到这一级停手 |

4. 每级完成后验证：

```bash
adb shell getprop ro.build.display.id
adb shell getprop ro.build.version.release    # 每级递减
```

### 2.2 ★ 上游未提及的坑

| 现象 | 原因 | 解决 |
|---|---|---|
| `adb devices` 变空 | HiSuite 走 HDB 通道 | 正常，别慌 |
| HiSuite 窗口自动化点不了 | DuiLib 自绘界面 | 必须手点 |
| 降级失败，日志显示 push 到 `/storage/XXXX-XXXX/` | 包被推到外置卡 | **拔出 SD 卡**后重试 |
| HiSuite 返回「已是最新正式版」 | 服务器下架该链路 | 不要继续，先确认还能否拿到 2.0 包 |

> 💡 **顺便记录固件直链**：HiSuite 日志里会出现 `update.dbankcdn.com/...` 的完整 URL，
> 阶段四刷机要用 4.2.0.208 的包，就在这个 CDN 上。

---

## 3. 阶段二：EDL 全盘备份

> **这是唯一的安全网。没有它，任何一步失败都可能无法挽回。**

### 3.1 进入 EDL

```bash
adb reboot edl          # 仅 2.0 上可用
```

设备管理器会出现 `QUSB_BULK_CID:0412`（`VID_05C6&PID_9008`），屏幕全黑但**没有关机**，不要拔线。

**驱动安装（两段式）**

```powershell
# 1) 先装高通串口驱动
pnputil /add-driver qcser.inf /install
#    → 认成 "Qualcomm HS-USB QDLoader 9008 (COM3)"

# 2) 再用 Zadig 把该设备换成 WinUSB
#    列表里显示为 QUSB_BULK_CID:xxxx_SN:<SN>
#    → Class=USBDevice，COM3 消失（这是对的）
```

> 💡 **备选路径**：工具箱里带了高通官方 `QSaharaServer.exe` + `fh_loader.exe` 和
> 6 个 `rawprogram{0..5}.xml`，这套走**标准 QDLoader 9008 串口驱动**，
> **不需要 Zadig**。如果 `edl.py` 因 libusb/WinUSB 折腾不通，直接改用 fh_loader。

### 3.2 握手验证

```bash
python edl.py printgpt --memory=ufs --loader=Huawei865870_devprg.elf
```

期望输出：

```
HWID      0x000c30e10015006e
CPU       SM8250:CD90-PH805-1A
分区数     74
容量       127.95 GB
```

**卡在 `Mode detected: sahara` 不动怎么办：**

1. 先让工具进入等待状态，**再**插线（顺序很重要）
2. 或 `电源键 + 音量上 + 音量下` 按住 20 秒强制重启，重新 `adb reboot edl`

### 3.3 全量读取

```powershell
foreach ($L in 0..5) {
    & $EDL rl "backup\lun$L" --memory=ufs --lun=$L --skip=userdata --loader=$LOADER
}
```

**关键文件大小核对**

| 文件 | 大小（字节） |
|---|---|
| `lun4/abl.bin` | 4,194,304 |
| `lun4/boot.bin` | 100,663,296 |
| `lun0/oeminfo.bin` | 100,663,296 |
| `lun1/xbl.bin` | 4,018,176 |
| `lun4/vbmeta.bin` | 1,048,576 |
| `lun4/dtbo.bin` | 25,165,824 |

生成 `SHA256SUMS.txt`，并**回读校验一次**（重新 `r boot`，SHA256 必须与备份一致）。

---

## 4. 阶段三：写入解锁 ABL

> 官方 ABL 会校验镜像签名；解锁 ABL 已 patch 掉该检查。

### 4.1 抢救 GPT

先用 6 条 `rs` 命令备份 GPT 六块（LUN0 条目 LBA 30692864、LUN4 条目 524283）。

### 4.2 生成新 GPT

```powershell
& $PY $SC\gptmake.py "img\base\EFI_0.img" 0 "$BK\lun0\gpt_main0.bin" "gpt\lun0" --backup-entries-lba=30692864
& $PY $SC\gptmake.py "img\base\EFI_0.img" 4 "$BK\lun4\gpt_main4.bin" "gpt\lun4" --backup-entries-lba=524283
```

写 GPT 六处 → 回读比对 → `printgpt` 复核 → 擦残留：

```bash
python edl.py es 255488 4096 --lun=0 --memory=ufs --loader=...
python edl.py es 2733568 16384 --lun=0 --memory=ufs --loader=...
```

### 4.3 写 unlock ABL

```powershell
& $EDL w abl abl_hw865870unlock.elf --memory=ufs --lun=4 --loader=$LOADER   # → sector 49670
& $EDL reset    # 注意：不带 --memory
```

### 4.4 验收

```bash
fastboot getvar unlocked        # unlocked: yes
fastboot getvar is-userspace    # no（必须是真 bootloader）
adb shell getprop ro.boot.flash.locked        # 0
adb shell getprop ro.boot.verifiedbootstate   # orange
```

---

## 5. 阶段四：回刷 HarmonyOS 4.2

使用 **Fastboot UBL FlashROM** 包（专为已解锁 BL 准备，**不含 abl**）。

### 5.1 刷写

```bash
fastboot flash boot    images/boot.img
fastboot flash ramdisk images/ramdisk.img
fastboot flash dtbo    images/dtbo.img
# ... 共 44 个分区，顺序见包内脚本 ...
fastboot --disable-verity --disable-verification flash vbmeta images/vbmeta.img
fastboot -w
fastboot reboot
```

### 5.2 ★ 关键：ABL 必须在 SKIP 列表里

跳过清单：`abl`、`EFI`、`FI`、`PTABLE`、`CRC`、`SHA256RSA`、`PACKAGE_TYPE`、`*_VER`

**每条 fastboot 命令前都要确认 `getvar is-userspace` = `no`**（`yes` = 在 fastbootd 里，行为不同）。

### 5.3 验收

```bash
adb shell getprop ro.build.display.id      # DBY-W09 4.2.0.208(C00E100)
adb shell getprop ro.boot.flash.locked     # 0
```

刷完 `fastboot reboot recovery` → 恢复出厂设置 → 重开 USB 调试。

### 5.4 ★ 最关键的一次验收（决定还有没有退路）

```bash
adb reboot bootloader
fastboot getvar is-userspace     # no
fastboot oem edl                 # OKAY，3 秒内出现 VID_05C6&PID_9008
```

**这一步通过，说明你随时能回到 EDL 救援。**

---

## 6. 阶段五：制作 microSD 启动盘

### 6.1 写卡

```bash
xz -d kubuntu-dby-w09-YYYYMMDD.img.xz
# 直接把镜像 dd 到卡上（镜像自带 MBR，分区起点 4 MiB）
sudo dd if=kubuntu-dby-w09-YYYYMMDD.img of=/dev/sdX bs=4M status=progress conv=fsync
```

> ⚠️ **根分区标签必须是 `LINUX70ROOT`**（initramfs 靠它找根）。写完后检查：
> ```bash
> sudo e2label /dev/sdX1        # 应输出 LINUX70ROOT
> ```

### 6.2 首次配置

在首次启动时完成：

| 项目 | 值 |
|---|---|
| 用户名 / 密码 | `matepad` / `matepad` |
| 主机名 | `matepad` |
| 时区 | `Asia/Shanghai` |
| 语言 | `zh_CN.UTF-8` |
| 键盘布局 | `us` |
| swap | 4096 MB（后续会用 zram 替代，见 [11.1](#111-内存zram)） |
| 自动登录 | 开 |

---

## 7. 阶段六：构造引导镜像（核心）

> **这一步决定能不能启动。** 上游文档在这里最简略，也最容易出错。

### 7.1 boot 分区

必须按移植项目 `deb/matepad-kernel-install` 里的 `boot_with()` **逐字段构造**，
不能只复制原厂头部。

Huawei 的 header v2 在 AOSP 标准之外还有扩展字段：

```
0x000  magic "ANDROID!"
0x008  kernel_size
0x010  ramdisk_size          ← 保留原厂内嵌 ramdisk（4.2 为 519986 B）
0x024  page_size
0x028  header_version = 2
0x040  cmdline[512]          ← 命令行写在这里，不是 DTB
0x240  id[32]                ← SHA1(kernel|ramdisk|second|recovery|dtb)
0x260  extra_cmdline[1024]   ← ★ 注意是 0x260，不是 0x2C0
0x630  recovery_dtbo_size / offset
0x66C  header_size = 1660
0x670  dtb_size              ← ★ 必须是新 DTB 的真实长度
0x674  dtb_addr
```

> 🔴 **最容易踩的坑（A1）**：`extra_cmdline` 从 `0x260` 开始。
> 写错成 `0x2C0` 会把 `header_size`、`dtb_size`、`dtb_addr` 全部清零，
> ABL 报 `Dtb overlay failed` 直接跳 fastboot，**而且没有任何提示**。

**boot 分区命令行**（来自 `linux-boot-*/cmdline.txt`）：

```
clk_ignore_unused pd_ignore_unused console=tty0 fbcon=font:TER16x32 \
loglevel=7 ignore_loglevel panic=0 rdinit=/init
```

### 7.2 DTB 改造（三项）

以 `linux-boot-7.0.14-dby-w09/sm8250-huawei-dby-w09.dtb` 为基准，需要三处改造：

#### (1) `qcom,board-id` 改成 `<0x206a 0x0>`

原值 `<0 0>` 会让 ABL 在 DTBO 表里找不到板级条目：

```
Unable to find the Board Dtb
```

```bash
python3 tools/dtb_set_prop.py src.dtb dst.dtb / "qcom,board-id" 0x206a 0x0
```

#### (2) 为原厂覆盖层补 166 个符号（桩节点）

原厂 dtbo 覆盖层引用了 166 个**下游内核专有标签**
（`clock_rpmh`、`thermal_zones`、`pm8150_l9` …）。

做法：在 DTB 的 `__symbols__` 里为每个标签建独立桩节点 `/dby-stub/stub@N`（各带唯一 `phandle`），
并**把主线原有的同名符号也改指向桩**。

```bash
python3 tools/dtb_add_stubs.py src.dtb stock_dtbo.img dst.dtb
# 输出：stock overlay needs 166 symbols; redirecting ALL of them to stubs
#        10 existing symbols redirected, 156 added
```

> 🔴 **关键副作用（A4）**：不重定向的后果不是报错，而是——
> 覆盖层把重复的 PMIC 子节点塞进真实节点 →
> `spmi_pmic_arb_probe: kobject_add_internal failed -EEXIST` →
> PM8150 供电（`pm8150l_l9`/`l6` = SD 的 `vmmc`/`vqmmc`）起不来 →
> **SD 卡完全不识别**。
>
> 这个症状极具迷惑性：你会以为 SD 卡坏了或驱动缺失，实际是 DTB 符号没重定向。

重定向后 SPMI 干净，SD 以 **UHS-I SDR104** 识别（`mmcblk0` / `mmcblk0p1`）。

#### (3) 蓝牙地址

`&uart6/bluetooth` 节点的 `local-bd-address` 原值是全 0，
QCA6390 会停在未配置状态（适配器 DOWN、无法配对）。

写入 **WiFi MAC + 1**（小端序）：

```
WiFi: 28:54:71:7c:12:d4
BT  : 28:54:71:7c:12:d5   →  DTB 字节 d5 12 7c 71 54 28
```

```bash
python3 tools/dtb_set_bdaddr.py src.dtb dst.dtb 28:54:71:7c:12:d5
```

> 💡 WiFi MAC 可以在 HarmonyOS 的「设置 → 关于手机 → 状态信息」里看到，
> 或者刷回鸿蒙后 `adb shell ip link show wlan0`。

### 7.3 dtbo 分区

原厂 **9 条目表全部保留**，只把每条的根 `compatible` 改写为：

```
qcom,sm8250
huawei,dby-w09
```

**两条独立字符串，用 `\0`（NUL）分隔。绝对不能用逗号！**

```bash
python3 tools/dtbo_set_compat_all.py stock_dtbo.img dtbo-fixed.img
```

> 🔴 **A5 详解**：为什么必须改？
>
> `msm-mdss` 通过 `qcom_ubwc_config_get_data()` → `of_machine_get_match_data()`
> 按**根节点 compatible** 查 UBWC 配置表，而 ABL 会把所应用覆盖层的根属性覆盖到 DTB 上。
>
> compatible 里没有 `qcom,sm8250` 就会报：
> ```
> Couldn't find UBWC config data for this platform!
> msm-mdss: probe with driver msm-mdss failed with error -22
> ```
>
> 而如果误用**逗号**分隔，`qcom,sm8250` 会被拆成 `qcom` 和 `sm8250` 两个独立字符串，
> 匹配依然失败 —— 且报错信息完全一样，极难排查。

### 7.4 ramdisk 分区

直接把官方 `ramdisk-payload.img` 铺到原厂 ramdisk 镜像长度上，保留尾部 AVB footer。
initramfs 会 `findfs LABEL=LINUX70ROOT` 挂载 SD 根。

### 7.5 完整构造流程

```bash
# 1) 解包内核
tar -xf linux-boot-7.0.14-dby-w09.tar

# 2) DTB 三项改造
python3 tools/dtb_set_prop.py       sm8250-huawei-dby-w09.dtb step1.dtb / "qcom,board-id" 0x206a 0x0
python3 tools/dtb_add_stubs.py      step1.dtb stock_dtbo.img step2.dtb
python3 tools/dtb_set_bdaddr.py     step2.dtb dtb-final.dtb 28:54:71:7c:12:d5

# 3) dtbo 改造
python3 tools/dtbo_set_compat_all.py stock_dtbo.img dtbo-final.img

# 4) 构造 boot（按 boot_with() 逐字段）
python3 tools/build_boot_patch.py   boot.img Image.gz dtb-final.dtb boot-final.img

# 5) 校验
python3 tools/audit_headers.py      boot-final.img
#   kernel_size / ramdisk_size / dtb_size / header_size 全部非 0 才算通过
```

---

## 8. 阶段七：首次启动

### 8.1 刷入

```bash
fastboot flash boot    boot-final.img
fastboot flash dtbo    dtbo-final.img
fastboot flash ramdisk ramdisk.img
fastboot reboot
```

### 8.2 首次启动现象

- **屏幕可能仍黑**（见 [9.1 背光](#91-背光最关键的一步)）
- USB 会出现串口设备：`ttyGS0`，115200，用户名同系统账号
- 用 `screen /dev/ttyUSB0 115200` 或 PuTTY 登录

> 💡 **进 fastboot 不用按键**（Linux 已启动的情况下）：
> ```bash
> sudo touch /var/lib/linux70/fastboot-next-boot && sudo reboot
> ```

---

## 9. 阶段八：外设适配

### 9.1 背光（最关键的一步）

#### ⚠️ 硬件变体警告

**这台机器有两个硬件版本，背光芯片不同：**

| 型号 | 芯片 | I2C 地址 | 现象 |
|---|---|---|---|
| 部分批次 | RT8555 | `0x31` | 移植仓库默认驱动 |
| **本机实测** | **LP8556** | **`0x2C`** | RT8555 驱动永远 `-ENXIO` |

**判别方法**：

```bash
dmesg | grep -i backlight
# 出现 "failed to enable backlight: -6" → ENXIO
i2cget -y -f 11 0x31 0x00    # 读失败 → 不是 RT8555
i2cget -y -f 11 0x2c 0x00    # 能读 → 是 LP8556
```

#### 方案 A：RT8555 机型（原厂方案）

无需改动，上游驱动直接工作。

#### 方案 B：LP8556 机型（本机，无需重编内核）

**核心思路**：内核里没有 lp855x 驱动，但可以**用 DTB + 用户态脚本**绕过。

**步骤 1：改 DTB**

```bash
python3 tools/dtb_lp8556_bl.py src.dtb dst.dtb
```

这个脚本做三件事：

1. 把 `backlight@31`（rt8555）节点 `status = "disabled"`
2. 新增固定调节器，开机自动拉高使能脚（TLMM GPIO 10）
3. 删掉面板节点的 `backlight` 属性（否则面板 enable 会因背光失败中止）

新增的 regulator 节点：

```dts
bl-en-regulator {
    compatible = "regulator-fixed";
    regulator-name = "bl_en";
    gpio = <&tlmm 10 GPIO_ACTIVE_HIGH>;
    enable-active-high;
    regulator-always-on;
    regulator-boot-on;
};
```

**步骤 2：用户态初始化脚本**

```bash
#!/bin/sh
# /usr/local/sbin/matepad-backlight
BUS=11
ADDR=0x2c
STATE=/var/lib/matepad/brightness
MIN=8; MAX=255; STEP=22; DEFAULT=115

[ -e "/dev/i2c-$BUS" ] || exit 0

current() { [ -r "$STATE" ] && cat "$STATE" || echo "$DEFAULT"; }

write_reg() {
    i2cset -y -f "$BUS" "$ADDR" 0x01 0x85 >/dev/null 2>&1   # 设备控制
    i2cset -y -f "$BUS" "$ADDR" 0x00 "$(printf '0x%02x' "$1")" >/dev/null 2>&1
}
```

用法：

```bash
sudo matepad-backlight              # 恢复上次亮度
sudo matepad-backlight set 50       # 设置 50%
sudo matepad-backlight up / down    # 步进
sudo matepad-backlight raw 0x8c     # 直接写寄存器
sudo matepad-backlight get          # 读当前值
```

**步骤 3：systemd 服务**

```ini
# /etc/systemd/system/matepad-backlight.service
[Unit]
Description=MatePad LP8556 backlight
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/matepad-backlight
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

#### LP8556 初始化寄存器序列（14 条）

| reg | value | reg | value |
|---|---|---|---|
| 0x01 | 0x85 | 0xA5 | 0x10 |
| 0xA0 | 0xFF | 0xA6 | 0x40 |
| 0xA1 | 0xDF | 0xA7 | 0xF7 |
| 0xA2 | 0x28 | 0xA9 | 0x80 |
| 0xA3 | 0x52 | 0xAA | 0x0F |
| 0xA4 | 0x12 | 0xAE | 0x0E |
| 0x9E | 0x22 | 0x16 | 0x1F |

亮度寄存器 `0x00`（0x00–0xFF）。使能前等待 100 ms，使能后 30 ms。

> 💡 这些值来自原厂 dtbo 覆盖层第 8 条的 `hw_lp855x,backlight_ic_kernel_init_cmd`。

### 9.2 触摸校准

面板原生是**竖屏**（1600×2560），桌面是横屏，坐标系需要换算。

**症状**：点击位置与反馈位置中心对称（180°）。

```bash
# /etc/udev/rules.d/99-matepad-touch.rules
ACTION=="add|change", KERNEL=="event*", ENV{ID_INPUT_TOUCHSCREEN}=="1", \
  ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 -1 1"
```

**矩阵含义**：`x' = a*x + b*y + c`，`y' = d*x + e*y + f`（0~1 归一化）。
`1 0 0 0 -1 1` = 仅翻转 Y 轴。

**试过的矩阵与结果**：

| 矩阵 | 结果 |
|---|---|
| 无 | 中心对称（180°） |
| `-1 0 1 0 -1 1`（XY 都翻） | 上下对称 |
| `-1 0 1 0 1 0`（只翻 X） | 中心对称 |
| **`1 0 0 0 -1 1`（只翻 Y）** | **正确** ✅ |

### 9.3 蓝牙适配器

**症状**：`hci0` 存在，固件加载正常，但适配器 DOWN，
BD 地址是占位值 `00:00:00:00:5A:AD`，ACL MTU `0:0`。

**原因**：DTB `&uart6/bluetooth` 节点 `local-bd-address = [00 00 00 00 00 00]`。
DTS 注释说明：小端序；没有它 QCA6390 停在未配置状态。

**修复**：见 [7.2 (3)](#3-蓝牙地址)，写入 WiFi MAC + 1。

修复后：

```
hci0: BD Address: 28:54:71:7C:12:D5  ACL MTU: 1024:7  SCO MTU: 240:4
      UP RUNNING
```

### 9.4 蓝牙键盘

**症状**：键盘配对/连接成功，但**打不出任何字**。（鼠标正常）

**原因**：镜像自带的 bluez 是未打补丁版本。
键盘对 CCC 描述符的读取返回 `Read Not Permitted`，
upstream hog-lib 因此**不启用通知、不读 Report Map、不创建 uhid 设备**。

**修复**：装打过补丁的 bluez（项目 apt 源里的 `+matepad1` 版本）：

```bash
wget -O /tmp/bz.deb 'https://github.com/svesnav/kubuntu-dby-w09/releases/download/apt/bluez_5.72-0ubuntu5.8%2Bmatepad1_arm64.deb'
sudo dpkg -i /tmp/bz.deb
sudo systemctl restart bluetooth
# 重新连接键盘
```

修复后验证：

```bash
ls /sys/bus/hid/devices/          # 应出现 0005:12D1:10B2.x
dmesg | grep "BLUETOOTH HID"      # hid-generic ... BLUETOOTH HID Keyboard
```

> ⚠️ **连带升级**：`libbluetooth3`、`bluez-cups`、`bluez-obexd` 也要一起升到 `+matepad1`，
> 否则依赖不满足。

### 9.5 M-Pencil 触控笔

> 🔴 **笔不会出现在「添加设备」里** —— 它广播不带 discoverable 标志，必须按地址配对。

**步骤 1：找地址**

```bash
# 笔离开磁吸 40 秒以上，同时运行扫描
sudo btmgmt find -l
# → hci0 dev_found: 70:61:EE:5B:5B:ED  name M-Pencil
```

**步骤 2：配对**

```bash
echo 70:61:EE:5B:5B:ED | sudo tee /etc/matepad/pen-mac
sudo systemctl start matepad-pen-pair.service
# 日志：pen seen; pairing -> paired and trusted; connecting -> done
```

之后笔会自动重连，`matepad-pen-bluez` 接管（压感、双击）。

**步骤 3：坐标校准**

> ⚠️ 笔是**独立设备**（`ID_INPUT_TABLET`，`/dev/input/event3`），
> 与触摸屏是两个不同的设备，**需要各自的校准规则**。

```bash
# /etc/udev/rules.d/98-matepad-pen.rules
ACTION=="add|change", KERNEL=="event*", ENV{ID_INPUT_TABLET}=="1", \
  ENV{LIBINPUT_CALIBRATION_MATRIX}="1 0 0 0 -1 0.991"
```

最后的 `0.991` 是笔尖与落点约 2 mm 的平移补偿（横屏左右 = 竖屏 Y）。

> 💡 `f = 1.009` 会让偏移更严重，说明方向反了，取 `0.991`。

### 9.6 键盘按键映射

**设备**：`HUAWEI MatePad Keyboard`（蓝牙 HID，`/dev/input/event12`）

它用三个报告：标准键盘（报告 2）、**消费者控制页**（报告 3，音量/静音走这里）、指针（报告 7）。

#### 完整映射表（实测）

| 按键 | 键码 | 状态 | 实现方式 |
|---|---|---|---|
| 字母 / 数字 / F1–F24 | 标准 | ✅ | 内核默认 |
| Esc / Tab / Caps / Shift / Ctrl / Alt / Enter / Del | 标准 | ✅ | 内核默认 |
| 方向键 / Home / End / PgUp / PgDn | 标准 | ✅ | 内核默认 |
| **窗口键**（左列方块图标） | `KEY_LEFTMETA` (125) | ✅ | = Super |
| **静音**（数字 4） | `KEY_MUTE` (113) | ✅ | PipeWire/Plasma |
| **音量 −**（数字 5） | `KEY_VOLUMEDOWN` (114) | ✅ | `matepad-volkeys` |
| **音量 +**（数字 6） | `KEY_VOLUMEUP` (115) | ✅ | `matepad-volkeys` |
| **锁屏键**（数字 7） | `KEY_SLEEP` (142) | ✅ | 系统睡眠 |
| **Fn+1 / Fn+2 亮度** | `KEY_BRIGHTNESSDOWN/UP` (224/225) | ✅ | `matepad-brightnessd` |
| 键盘背光键 | `KBDILLUMTOGGLE/DOWN/UP` (228–230) | ⚠️ | 已声明，系统无背光控制 |
| 地球键（Alt 下方） | `KEY_COMPOSE` (127) | ⚠️ | 已声明，KDE 未绑定动作 |

#### 音量键随屏幕方向交换

`matepad-volkeys` 服务读取重力传感器方向，在竖屏时自动交换音量键左右：

```ini
# /etc/systemd/system/matepad-volkeys.service
Environment="MATEPAD_VOLKEYS_SWAP=right-up bottom-up"
Environment="MATEPAD_VOLKEYS_DEFAULT=right-up"
ExecStart=/usr/local/sbin/matepad-volkeys
```

#### 亮度键为什么要绕开 KDE

`matepad-brightnessd` 直接读 `/dev/input/event*`，捕获 `KEY_BRIGHTNESSDOWN(224)` /
`KEY_BRIGHTNESSUP(225)`。**不用 KDE 的 kglobalaccel**，因为在本镜像里它跑不起来。

#### 如何自己验证按键

```bash
# 安装 evtest
sudo apt install evtest

# 方法 1：看设备支持哪些键（不用按）
timeout 4 sudo evtest /dev/input/event12 | grep "Event code"

# 方法 2：实时捕获
sudo evtest /dev/input/event12
```

### 9.7 让 udev 规则生效

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=input
sudo reboot
```

---

## 10. 阶段九：内部存储接入（★ 上游无此章节）

> **上游完全没有提到内部 256 GB 存储怎么用。** 这一节是我们摸索出来的。

### 10.1 问题：UFS 首次探测失败

开机日志：

```
ufshcd-qcom 1d84000.ufshc: link startup failed 1
ufshcd-qcom 1d84000.ufshc: error -EIO: ufshcd_pltfrm_init() failed
→ /proc/partitions 里没有 /dev/sda
```

**看起来像驱动缺失或 DT 属性错误，其实不是。**

对比主线 `sm8250.dtsi` 和原厂 DTB 后确认：节点、时钟、reset、电源域、稳压器**全部正确**。
这是**首次初始化时序问题**。

### 10.2 ★ 突破：第二次探测就成功

```bash
echo 1d84000.ufshc > /sys/bus/platform/drivers/ufshcd-qcom/unbind
echo 1d84000.ufshc > /sys/bus/platform/drivers/ufshcd-qcom/bind
```

立即成功：

```
/dev/sda (236.3G) + sdb/sdc/sdd/sde/sdf 全部出现
```

**自动化脚本**：

```bash
#!/bin/sh
# /usr/local/sbin/matepad-ufs-retry
DRIVER=/sys/bus/platform/drivers/ufshcd-qcom
DEV=1d84000.ufshc

[ -b /dev/sda ] && exit 0
[ -d "$DRIVER" ] || exit 0

for _attempt in 1 2 3; do
    echo "$DEV" > "$DRIVER/unbind" 2>/dev/null
    sleep 1
    echo "$DEV" > "$DRIVER/bind" 2>/dev/null
    sleep 3
    [ -b /dev/sda ] && exit 0
done
exit 1
```

```ini
# /etc/systemd/system/matepad-ufs-retry.service
[Unit]
Description=MatePad internal UFS bring-up (second probe)
After=local-fs.target
Before=data.mount

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/matepad-ufs-retry
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

### 10.3 格式化 userdata 为 /data

**内部存储布局（只读探测结果）**

| 设备 | 大小 | 内容 |
|---|---|---|
| `sda` | 236.3 G | LUN0，40 个分区 |
| ├ `sda37` super | 7.2 G | 鸿蒙系统 |
| ├ `sda38/39` preload/version | 1.4 G + 576 M | erofs 预置应用 |
| └ **`sda40` userdata** | **225.8 G f2fs** | **鸿蒙用户数据** |
| `sdb` | 8 M | xbl |
| `sdd` | 32 M | cdt/ddr |
| `sde` | 2 G | aop/tz/hyp/modem/abl |
| `sdf` | 32 M | 保留 |

**唯一能拿来给 Ubuntu 的是 `sda40`（225.8 G）。**

它原本是 f2fs 且带脏标记：

```bash
mount -o ro /dev/sda40 /mnt/harmonyos
# → Structure needs cleaning
```

> 🔴 **不要跑 fsck** —— 会改动鸿蒙数据，不可逆。

**格式化（破坏性，会丢失鸿蒙用户数据）**

```bash
sudo mkfs.ext4 -L MATEPADDATA /dev/sda40
```

结果：

```
LABEL=MATEPADDATA
UUID=a308d2c6-0e13-4ab3-9680-26e2e19dac51
可用 222 GB
```

### 10.4 ★ 开机自动挂载的坑：排序环

**第一次尝试**用了 `data.mount` + `After=multi-user.target`，结果：

```
桌面起来了、蓝牙正常，但没有 Wi-Fi 菜单、SSH 也进不去
```

**根因**：systemd 排序环。

```
matepad-ufs-retry.service 写了 After=multi-user.target
data.mount 又 Requires 它，且被 multi-user.target 依赖
→ target 等 service，service 等 target
```

systemd 打破环时会**删除该事务里的部分启动任务**，
连带把 **NetworkManager 和 ssh 的启动任务一起丢了**。

**修正**：

1. `matepad-ufs-retry.service`：`After=local-fs.target` + `Before=data.mount`，
   **去掉对 multi-user 的依赖**
2. 删掉 `data.mount`，改用 `matepad-data.service`：

```ini
# /etc/systemd/system/matepad-data.service
[Unit]
Description=MatePad internal storage at /data
Requires=matepad-ufs-retry.service
After=matepad-ufs-retry.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/matepad-internal-storage mount
ExecStop=/usr/local/sbin/matepad-internal-storage umount

[Install]
WantedBy=multi-user.target
```

3. **`systemd-analyze verify` 先验证过再 enable**

```bash
sudo systemd-analyze verify /etc/systemd/system/matepad-data.service
sudo systemctl daemon-reload
sudo systemctl enable matepad-data.service
```

> 📌 **教训（写开机单元必看）**：
> - 一律加 `nofail`
> - 不要用 `Requires` 挂到 target 链上
> - `systemd-analyze verify` 先验证
> - 改完必须**真重启验证一次**，不能只看 `systemctl start` 成功

### 10.5 存储策略

> **原则：软件、下载、数据一律放 `/data`（222 GB UFS）；
> 只有必须装进系统的（内核模块、系统库、APT 包）才留在 SD 卡。**

**两块盘的分工**

| 设备 | 挂载点 | 容量 | 放什么 |
|---|---|---|---|
| microSD（系统卡） | `/` | 58 GB | 操作系统、内核模块、系统库、APT 包 |
| 内置 UFS | `/data` | 222 GB | 应用、下载、文档、图片、缓存、容器镜像 |

**已迁移清单**

| 项目 | 位置 | 方式 |
|---|---|---|
| 用户目录 | `/data/home/{Downloads,Documents,Pictures,Videos,Music,Templates}` | `~/.config/user-dirs.dirs` + 符号链接 |
| 应用配置 | `/data/home/config/{QQ,BraveSoftware,mozilla}` | 符号链接 |
| Firefox 下载 | `/data/home/Downloads` | `profile/user.js` |
| Firefox 缓存 | `/data/cache/firefox` | `profile/user.js` |
| pip 缓存 | `/data/cache/pip` | `~/.config/pip/pip.conf` |
| Podman 镜像 | `/data/containers/storage` | `~/.config/containers/storage.conf` |
| VS Code | `/data/apps/code`（971 MB） | 整目录复制 + `dpkg -r code` |
| Firefox | `/data/apps/firefox` | 官方 tar 解包 |
| QQ | `/data/apps/qq` | AppImage |
| CordCloud | `/data/apps/cordc` | AppImage 解包（注入中文字体） |
| DeepSeek Harness | `/data/apps/dsh`（1.1 GB） | tar.gz 解包 |

**三种迁移模式**

**A. 绿色软件（tar / AppImage）**

```bash
mkdir -p /data/apps/<名字>
tar -xf xxx.tar.gz -C /data/apps/<名字> --strip-components=1
# 或
cp xxx.AppImage /data/apps/<名字>/ && chmod +x /data/apps/<名字>/xxx.AppImage
```

**B. deb 包安装的软件**

```bash
sudo apt install ./xxx.deb            # 先正常装
sudo cp -a /usr/share/<程序> /data/apps/<程序>
sudo ln -sfn /data/apps/<程序>/bin/<程序> /usr/local/bin/<程序>
sudo dpkg -r <包名>                    # 卸载系统副本，释放 SD
```

**C. 配置目录迁移（符号链接法）**

```bash
mv ~/.config/<程序> /data/home/config/<程序>
ln -sfn /data/home/config/<程序> ~/.config/<程序>
```

> ⚠️ **注意**：
> - `/data` 挂载失败时符号链接会变成死链，程序以空配置启动（数据仍在 UFS 上，不会丢）
> - 迁移配置**必须在程序退出后**进行
> - `/data` 上的数据**不在系统备份范围内**

---

## 11. 阶段十：系统调优（★ 上游无此章节）

> 所有优化项均可回退，脚本在 `/data/rollback-optimizations.sh`。

### 11.1 内存：zram

**问题**：内核**根本没有编译 `CONFIG_ZRAM`**：

```
# CONFIG_ZRAM is not set
# CONFIG_ZSMALLOC is not set
```

**解决方案（不用重刷内核，只补编模块）**：

```bash
# 1) 打开配置
cd /data/linux-7.0.14
./scripts/config --file /data/kbuild/.config -m ZRAM
./scripts/config --file /data/kbuild/.config -m ZSMALLOC
make -C /data/linux-7.0.14 O=/data/kbuild ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

# 2) 强制同步 auto.conf（关键！否则改了配置不生效）
rm -f /data/kbuild/include/config/auto.conf /data/kbuild/include/config/auto.conf.cmd
make -C /data/linux-7.0.14 O=/data/kbuild ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig

# 3) 编译（注意：必须用 M= 指定目录，不能直接 make modules）
make -C /data/linux-7.0.14 O=/data/kbuild ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=drivers/block/zram -j4
make -C /data/linux-7.0.14 O=/data/kbuild ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=mm -j4

# 4) 安装
KVER=7.0.14-dby-w09
sudo install -D -m 644 /data/kbuild/mm/zsmalloc.ko        /lib/modules/$KVER/kernel/mm/zsmalloc.ko
sudo install -D -m 644 /data/kbuild/drivers/block/zram/zram.ko /lib/modules/$KVER/kernel/drivers/block/zram/zram.ko
sudo depmod -a $KVER
```

**启用 zram**：

```bash
sudo apt install zram-tools
printf 'ALGO=lzo-rle\nSIZE=2048\nPRIORITY=100\n' | sudo tee /etc/default/zramswap
sudo systemctl restart zramswap

# swappiness 调高（zram 场景推荐）
printf 'vm.swappiness=100\n' | sudo tee /etc/sysctl.d/90-zram.conf
```

> 💡 **压缩算法只能用 lzo-rle**：内核没编 zstd 后端
> （`CONFIG_ZRAM_BACKEND_ZSTD` 未设置）。对 6 GB 设备够用且更快。

**验证**：

```
NAME       ALGORITHM DISKSIZE DATA COMPR TOTAL STREAMS MOUNTPOINT
/dev/zram0 lzo-rle         2G   4K   74B   12K         [SWAP]
```

### 11.2 背光随息屏关闭（最大省电收益）

**问题**：内核没有这块板子的背光驱动，LP8556 是用户态驱动的。
**DRM 无法随面板一起熄灭背光** —— 息屏后背光仍满功率烧着。

**解决方案**：`matepad-panelbacklightd` 轮询 DRM DPMS 状态：

```python
"""matepad-panelbacklightd - drive the LP8556 backlight from the panel's DPMS."""

BACKLIGHT = "/usr/local/sbin/matepad-backlight"
POLL = 1.0

def panel_off():
    """True while every DSI panel is blanked; None if there is no panel."""
    states = []
    for path in glob.glob("/sys/class/drm/card*-DSI-1/dpms"):
        with open(path) as fh:
            states.append(fh.read().strip())
    if not states:
        return None
    return all(state != "On" for state in states)
```

实测：关屏 `dpms=Off reg=0x00`，唤醒 `reg=0x8c`(140)。

**另外**：睡眠时也关背光

```bash
# /usr/lib/systemd/system-sleep/matepad-backlight
# pre: 存值 + raw 0；post: 恢复
```

### 11.3 SD 卡写入策略

SD 卡写入慢，默认脏页比例会造成一次性回写卡顿。

```bash
cat > /etc/sysctl.d/91-sd-writeback.conf <<'EOF'
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.dirty_expire_centisecs = 1500
EOF
```

> 默认值是 20 / 10 / 3000。

### 11.4 系统监视器磁盘显示 0B/0B

**症状**：Plasma 系统监视器「磁盘」小部件显示 `0B / 0B`，其他（CPU、内存）正常。

**源码级根因**：`ksystemstats` 的 `plugins/disks/disks.cpp`（Plasma 5.27）：

```cpp
while (drive.isValid()) {
    if (drive.is<Solid::StorageDrive>()) {
        auto type = drive.as<Solid::StorageDrive>()->driveType();
        if (type == Solid::StorageDrive::HardDisk) {
            break;
        } else {
            return;              // ← 非 HardDisk 直接丢弃
        }
    }
    drive = drive.parent();
}
```

SD 卡在 udisks/Solid 里的 `driveType` 是 **`SdMmc`**（不是 `HardDisk`），
所以**连单个磁盘传感器都不会创建**，聚合传感器 `disk/all/*` 自然为 0。

**修复**：改成 `HardDisk || SdMmc`，重编：

```bash
apt-get source ksystemstats
# 打补丁 packages/ksystemstats-sdmmc.patch
dpkg-buildpackage -b -uc -us -j4
sudo dpkg -i ../ksystemstats_*.deb
```

产物存档：`packages/ksystemstats_5.27.11-0ubuntu2_arm64.deb`

### 11.5 内核补丁（深睡尝试）

**背景**：SM8250 的 CX 深度塌陷（`cxsd`）从未进入，整块 SoC 在"睡眠"时仍带电。
根因是 `bi_tcxo` 时钟投票数不为 0。

**参考**：`shuuri-labs/pocknix-os` PR #161（同款 SM8250 掌机）

**打的补丁**：

| 补丁 | 内容 |
|---|---|
| **1097** | `camcc-sm8250`：GDSC 时钟不再注册为 `CLK_IS_CRITICAL`，改为 probe 里直接置使能位 |
| **1098** | `dsi_phy`：AHB 时钟改由 runtime PM 的 suspend/resume 管理 |

**结果**：

| 指标 | 补丁前 | 补丁后 |
|---|---|---|
| `cam_cc_gdsc_clk` | 存在，prep=1 | **已从框架移除** ✅ |
| `bi_tcxo` prepare 数 | 19~26 | **18** |
| `cxsd` 计数 | 0 | **仍然 0** ❌ |

**为什么还是进不了 cxsd**：

```
CPU 空闲状态：只有 WFI + cpu-sleep-0-0（小核）/ cpu-sleep-1-0（大核）
没有 cluster 级 cpuidle 设备（/sys/class/cpuidle 为空）
DT 里拓扑其实是完整的：
  /psci/power-domain-cpu0..7 → power-domain-cpu-cluster0
  /cpus/domain-idle-states/cluster-sleep-0 (psci-suspend-param 0x4100c244)
固件日志：
  psci: OSI mode supported
  psci: [Firmware Bug]: failed to set PC mode: -3
  CPUidle PSCI: Initialized CPU PM domain topology using OSI mode
```

DT 和配置都对，但 **cluster 域的 cpuidle 状态没有被注册**，
加上固件拒绝 PC 模式，SoC 永远停在 CPU 级空闲。

> 📌 **结论**：社区方案在这台机器上**部分生效**（释放了一个永久投票），
> 但离"能进深睡"还差 cluster 空闲状态这一层，属于移植内核本身的空白。
> **继续投入性价比不高。**

**补丁产物**：

```
kernel-new/Image.gz                    打了补丁的内核
kernel-new/camcc-sm8250.ko.patched     补丁版模块
kernel-new/camcc-sm8250.ko.orig        原始模块（回退用）
flash-set/boot-patch.img               完整 boot 镜像
flash-set/boot-bt.img                  补丁前的 boot（回退用）
patches/1097-*.patch  1098-*.patch     补丁原文
```

### 11.6 关于"8 GB 内存只显示 5.5 GB"

**结论：这台机器的 DDR 配置就是 6 GB，不是 8 GB。**

从 ABL 日志（`rawdump`，`/dev/sde20`）读到的硬证据：

```
ddr_total_size = 6144
Total DDR Size: 0x000000017CC00000        → 6,387,924,992 字节 = 6092 MiB
HwDdrSize = 6GB, qcom,is-low-ram = 0
VM Hyp calls not present                  → 没有 hypervisor 占用
OEM_HYP Image Loaded, Delta - (0 Bytes)   → hypervisor 是空的
```

再看鸿蒙自己的 DTB：**完全没有 `/memory` 节点** —— 内存映射是 ABL 运行时注入的，
鸿蒙和 Linux 拿到的是同一张表。

| 层级 | 大小 | 依据 |
|---|---|---|
| DDR 总量（Bootloader 报告） | 6.39 GB（6092 MiB = 5.95 GiB） | ABL rawdump |
| 内核保留 | 0.52 GiB | `529724K reserved, 32768K cma-reserved` |
| 可用 | 5.41 GiB | `Memory: 5671240K/6238208K available` |
| MemTotal | 5.45 GiB | `/proc/meminfo` |

> ⚠️ **不要试图"找回"这 2 GB**：那属于 **XBL/SBL1 的 DDR 配置层**，
> Linux 层完全无法触碰。改它需要换匹配的 XBL，失败会**直接变砖**（连 EDL 都可能救不回）。
> 收益 2 GB，风险是整机 —— **不建议**。

### 11.7 关于"关机后自动开机"

**现象**：点关机 → 熄屏 → 出现启动代码 → 又开机了。

**原因**：不是关机失败。启动 cmdline 里写着：

```
reboot_reason=NORMALBOOT sreason=U_CBLPWR_D_PS_HOLD reset_type=COLD
```

`CBLPWR` = 线缆供电。systemd 日志显示 `Reached target poweroff.target` 正常完成关机，
随后 PMIC 断电，但**充电器 VBUS 又把设备唤醒**。

**验证**：拔掉充电线后远程执行 `systemctl poweroff`，设备离线 141 秒以上没有回来 —— 真关机。

> 📌 **结论**：插着充电器关机就会自动重启，这是高通设备的常见行为。
> **关机前拔线即可，不需要修复。**

---

## 12. 阶段十一：应用生态（★ 上游无此章节）

### 12.1 中文输入法

**安装**：

```bash
sudo apt install fcitx5 fcitx5-chinese-addons fcitx5-frontend-all \
                 kde-config-fcitx5 fcitx5-config-qt fonts-noto-cjk
```

**配置 `~/.config/fcitx5/profile`**：

```ini
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
```

**配置 `~/.config/fcitx5/config`**（Ctrl+空格 切换）：

```ini
[Hotkey/TriggerKeys]
0=Control+space
1=Zenkaku_Hankaku
2=Hangul

[Hotkey/EnumerateForwardKeys]
0=Super+space
```

**环境变量 `~/.config/environment.d/90-fcitx5.conf`**：

```
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
```

**自启动**：用 systemd 用户服务（**不要用 autostart**，实测不生效）：

```ini
# ~/.config/systemd/user/fcitx5.service
[Unit]
Description=Fcitx5 input method
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/fcitx5 --replace
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now fcitx5.service
```

> ⚠️ **踩坑记录**：`~/.config/autostart/org.fcitx.Fcitx5.desktop` 方式在 KDE Wayland 下
> **不生效**（fcitx5 进程起来了，但引擎列表为空）。必须用 systemd 用户服务。

### 12.2 开发环境

```bash
# Python 3.12（系统自带，只需补工具）
sudo apt install python3-pip python3-venv python3-dev python3-full pipx

# PyPI 镜像
cat > ~/.config/pip/pip.conf <<'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
EOF

# Git
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
```

**APT 换清华镜像**（官方源在国内下 41 MB 要 10 分钟）：

```bash
sudo cp /etc/apt/sources.list.d/ubuntu.sources /data/ubuntu.sources.bak
sudo sed -i 's|http://ports.ubuntu.com/ubuntu-ports|https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports|g' \
     /etc/apt/sources.list.d/ubuntu.sources
sudo apt update
```

**VS Code**：装 deb 后搬到 `/data`（见 [10.5](#105-存储策略)），
或直接用 tar.gz 解压到 `/data/apps/code`。

### 12.3 容器：Docker 不可用，改用 Podman

> 🔴 **这是本手册最有价值的"避坑"之一。**

**Docker 为什么不行**：

```
failed to create NAT chain DOCKER: iptables: Failed to initialize nft: Protocol not supported
```

内核配置里 **`CONFIG_NF_TABLES` / `CONFIG_NF_NAT` / `CONFIG_NFT_COMPAT` 全部未设置**。

**尝试补编模块（失败）**：

只编模块、不重刷内核的思路是对的，但触发连锁依赖：

```
ERROR: modpost: "nf_sk_lookup_slow_v4" [nft_socket.ko] undefined!
ERROR: modpost: "nf_tproxy_get_sock_v4" [nft_tproxy.ko] undefined!
ERROR: modpost: "udp4_lib_lookup" [nf_socket_ipv4.ko] undefined!
ERROR: modpost: "icmpv6_ndo_send" [net/ipv4/ip_tunnel.ko] undefined!
ERROR: modpost: "icmp_ndo_send" [net/ipv6/sit.ko] undefined!
```

牵扯面太大，**放弃**。

**改用 Podman**：

```bash
sudo apt install podman slirp4netns uidmap fuse-overlayfs
```

Podman 用**用户态网络**（slirp4netns），**完全不需要内核 NAT**：

```
podman run --rm alpine echo "hello from container"   → 成功
容器内访问外网（wget baidu.com）                      → NET_OK
rootless + cgroup v2                                  → ✓
```

**镜像加速 `/etc/containers/registries.conf.d/99-mirror.conf`**：

```toml
unqualified-search-registries = ["docker.io"]
[[registry]]
prefix = "docker.io"
location = "docker.m.daocloud.io"
```

**镜像存储放 /data**（`~/.config/containers/storage.conf`）：

```toml
[storage]
driver = "overlay"
graphroot = "/data/containers/storage"
runroot = "/run/user/1000/containers"
```

> 💡 建议加别名：`alias docker=podman`，常用命令完全兼容。

### 12.4 ARM64 上的软件获取策略

**核心矛盾**：绝大多数 Linux 软件只发 x86_64，而这是 ARM64。

| 情况 | 做法 |
|---|---|
| APT 源里有 arm64 | ✅ 直接 `apt install` |
| 官方发 arm64 deb/tar | ✅ 下载解压到 `/data/apps` |
| AppImage 标 `amd64` / `x86_64` | ❌ **跑不了**，找 `arm64` / `aarch64` 版本 |
| 只有 Windows 版（x86） | ❌ 基本无解（Box64 转译对 3D 应用不现实） |
| 安卓版 | ⚠️ 理论可走 Waydroid，但 GPU 支持不完整 |

**验证 AppImage 架构**：

```bash
file xxx.AppImage
# 或看 ELF 机器类型
dd if=xxx.AppImage bs=1 skip=18 count=2 status=none | xxd
# 3e00 = x86-64     b700 = aarch64
```

### 12.5 Flutter 应用中文方块字

**症状**：某些 Flutter 打包的应用（如 CordCloud）中文全显示为方块 □□□。

**原因**：Flutter 应用**不走系统 fontconfig 回退**，
而 `FontManifest.json` 里只声明了图标字体和等宽字体，**没有任何 CJK 字体**。

**验证**：系统字体本身是正常的

```bash
fc-match sans        # → Noto Sans CJK SC（说明系统没问题）
fc-list :lang=zh | wc -l
```

**修复方案（两步）**：

**步骤 1：系统级 fontconfig 规则**（对其它 Flutter/Electron 应用也有效）

```xml
<!-- ~/.config/fontconfig/fonts.conf -->
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias binding="strong">
    <family>sans-serif</family>
    <prefer><family>Noto Sans CJK SC</family></prefer>
  </alias>
  <alias binding="strong">
    <family>sans</family>
    <prefer><family>Noto Sans CJK SC</family></prefer>
  </alias>
  <match target="pattern">
    <test qual="any" name="lang" compare="contains"><string>zh</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Sans CJK SC</string></edit>
  </match>
</fontconfig>
```

```bash
fc-cache -f
```

**步骤 2：注入字体到应用内**（如果步骤 1 不够）

```bash
# 1) 解包
cd /tmp && /data/apps/cordc/CordC.AppImage --appimage-extract
mv squashfs-root /data/apps/cordc/app

# 2) 备份并替换等宽字体（它本来就不含中文）
cp /data/apps/cordc/app/data/flutter_assets/assets/fonts/JetBrainsMono-Regular.ttf{,.orig}
cp /usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf \
   /data/apps/cordc/app/data/flutter_assets/assets/fonts/JetBrainsMono-Regular.ttf
cp /usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf \
   /data/apps/cordc/app/data/flutter_assets/fonts/DroidCJK.ttf

# 3) 补丁字体清单
python3 - <<'PY'
import json
p = "/data/apps/cordc/app/data/flutter_assets/FontManifest.json"
m = json.load(open(p))
fams = {f["family"] for f in m}
for name in ("Roboto", "sans-serif", "Noto Sans CJK SC"):
    if name not in fams:
        m.append({"family": name, "fonts": [{"asset": "fonts/DroidCJK.ttf"}]})
json.dump(m, open(p, "w"), ensure_ascii=False)
PY

# 4) 快捷方式改指向解包目录
# Exec=/data/apps/cordc/app/AppRun %u
```

### 12.6 办公套件

```bash
sudo apt install libreoffice-writer libreoffice-calc libreoffice-impress \
                 libreoffice-l10n-zh-cn libreoffice-help-zh-cn libreoffice-qt5
```

**已自带可用的**：

| 用途 | 软件 |
|---|---|
| PDF 阅读批注 | Okular |
| **手写笔记 / PDF 批注** | **Xournal++**（配 M-Pencil 绝配） |
| 文本/代码 | Kate |
| 文件管理 | Dolphin |
| 手机互传 | KDE Connect |

### 12.7 关于游戏

ARM64 Linux 上能玩的**流行游戏**很有限（Steam 客户端无 arm64 版，绝大多数游戏是 x86 的）。

APT 源里原生的：

| 游戏 | 类型 |
|---|---|
| SuperTuxKart | 卡丁车竞速（最能验证 GPU 性能） |
| 0 A.D. | 即时战略 |
| Minetest | 沙盒 |
| Battle for Wesnoth | 战棋 |
| Teeworlds / Hedgewars | 联机对战 |
| RetroArch + DeSmuME / Mednafen | 模拟器 |

**炉石传说等 Windows/安卓游戏**：原生跑不了。可行路径只有
**PC 串流**（Sunshine + Moonlight）或**云游戏**。

---

## 13. 故障排查手册

### 13.1 读 ABL 日志（最有用的诊断手段）

ABL 会把启动过程写进 `rawdump` 分区（LUN4，起始扇区 99710）。

```bash
python edl.py r rawdump rawdump.bin --memory=ufs --lun=4 --loader=...
# 然后在二进制里找 "APPSBL Image Loaded" 之后的可读文本
```

**典型报错对照表**

| 日志 | 含义 | 处理 |
|---|---|---|
| `Unable to find the Board Dtb` | DTB board-id 与 DTBO 条目不匹配 | 改 `qcom,board-id` 为 `0x206a 0x0` |
| `Couldn't find 'xxx' symbol in main dtb` | 覆盖层缺符号 | 补桩节点 |
| `ApplyOverlay: ufdt apply overlay failed` | 同上 | 同上 |
| `Couldn't find UBWC config data` | 根 compatible 缺 `qcom,sm8250` | 改 dtbo 条目 compatible |
| `spmi_pmic_arb_probe ... -EEXIST` | 覆盖层污染了真实 PMIC 节点 | 符号全部重定向到桩 |
| 停在 `FASTBOOT&RESCUE` | 引导镜像被拒 | 读日志，逐项修 |
| `failed to enable backlight: -6` | 背光芯片型号不对 | 见 [9.1](#91-背光最关键的一步) |
| `link startup failed 1` | UFS 首次探测失败 | 见 [10.1](#101-问题ufs-首次探测失败) |

### 13.2 进入 fastboot / EDL / 强制复位

| 目标 | 方法 |
|---|---|
| **fastboot**（关机状态） | 按住「音量下」，插 USB 或让设备重启 |
| **fastboot**（Linux 已启动） | `sudo touch /var/lib/linux70/fastboot-next-boot && sudo reboot` |
| **EDL**（HarmonyOS 4.2） | `fastboot oem edl` |
| **EDL**（HarmonyOS 2.0） | `adb reboot edl` |
| **强制复位** | `电源 + 音量上 + 音量下` 按住 20 秒 |

### 13.3 设备卡死

| 现象 | 处理 |
|---|---|
| 屏幕停在 logo / 完全无 USB | 三键复位 |
| EDL 握手卡在 `sahara` | 先起工具再插线，或复位后重来 |
| 串口无输出 | 检查 `/dev/ttyGS0` getty，必要时 `systemctl restart serial-getty@ttyGS0` |

### 13.4 桌面没画面但系统在跑

```bash
sudo chvt 1        # 切回图形 VT
systemctl restart sddm
```

> ⚠️ **实测警告**：重启 `sddm` 后 KWin 重新接管显示时**帧缓冲可能卡死**
> （DPMS 显示 `On` 但屏幕全黑）。此时**重启整机才能恢复**。
> 建议在改图形相关配置前先备份，并接受"可能要重启一次"。

### 13.5 息屏后进不去系统（锁屏无键盘）

**现象**：屏幕自动锁定，但锁屏界面没有屏幕键盘，没接实体键盘就进不去。

**原因**：电源设置「电池供电 → 5 分钟息屏 → 自动锁定」。

**临时救援**（SSH 进去）：

```bash
sudo loginctl unlock-session 1
```

**永久关闭自动锁定**：

```ini
# ~/.config/kscreenlockerrc
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
```

### 13.6 Wi-Fi / SSH 突然消失

**症状**：桌面起来了、蓝牙正常，但**没有 Wi-Fi 菜单、SSH 也进不去**。

**根因**：systemd 排序环导致 `NetworkManager` 和 `ssh` 的启动任务被静默丢弃。
见 [10.4](#104--开机自动挂载的坑排序环)。

**检查**：

```bash
systemd-analyze verify /etc/systemd/system/*.service
systemctl list-jobs          # 看有没有卡住的任务
```

### 13.7 Wi-Fi 密码不持久

**症状**：重启后需要重新输 Wi-Fi 密码。

**原因**：PSK 由 KWallet 托管（`psk-flags: "1"`），KWallet 未解锁时拿不到密码。

**修复**：把密码写入 netplan（明文，注意安全）：

```yaml
# /etc/netplan/90-NM-*.yaml
network:
  version: 2
  wifis:
    wlp1s0:
      access-points:
        "你的SSID":
          password: "你的密码"
```

```bash
sudo chmod 600 /etc/netplan/90-NM-*.yaml
sudo netplan apply
```

---

## 14. 回退与救援

### 14.1 回到 HarmonyOS（保留 Linux 系统卡）

```bash
fastboot flash boot    <4.2包>/images/boot.img
fastboot flash ramdisk <4.2包>/images/ramdisk.img
fastboot flash dtbo    <4.2包>/images/dtbo.img
fastboot reboot
```

> ⚠️ **注意**：鸿蒙会**重新格式化 `/data`**（ext4 ≠ f2fs），Linux 数据盘内容会丢失。
> SD 卡里的 Kubuntu 不受影响，随时可以刷回三件套再进 Linux。

### 14.2 回退内核补丁

```bash
fastboot flash boot flash-set/boot-bt.img
```

再把 `kernel-new/camcc-sm8250.ko.orig` 拷回：

```bash
sudo cp camcc-sm8250.ko.orig /lib/modules/7.0.14-dby-w09/kernel/drivers/clk/qcom/camcc-sm8250.ko
sudo depmod -a
```

### 14.3 回退系统优化

```bash
sudo bash /data/rollback-optimizations.sh <项目>
#   data-noatime   /data 恢复 relatime
#   autostart      恢复 Discover 通知和 geoclue 自启
#   zram           关闭并移除 zram
#   writeback      恢复默认脏页比例（20/10）
#   all            全部回退
```

### 14.4 回退存储迁移

符号链接的还原：

```bash
rm ~/.config/QQ                    # 删符号链接
mv /data/home/config/QQ ~/.config/QQ
```

### 14.5 终极救援：EDL

只要 EDL 还能握手，机器就救得回来。

```bash
python edl.py printgpt --memory=ufs --loader=Huawei865870_devprg.elf
```

能出分区表 → 可以从备份逐分区写回。

> 🔴 **EDL 也进不去的情况**：通常是 XBL/SBL1 被破坏，需要 JTAG 或换主板。

---

## 15. 已知限制

### 15.1 无法解决的

| 限制 | 原因 | 影响 |
|---|---|---|
| **无深度睡眠** | cluster 级 cpuidle 未注册 + 固件拒绝 PC 模式 | 待机功耗高于鸿蒙 |
| **只有 5.45 GiB 内存** | DDR 配置在 XBL/SBL1 层，就是 6 GB | 无法"找回" |
| **关机需拔充电线** | 高通设备 VBUS 唤醒行为 | 使用习惯问题 |
| **Docker 不可用** | 内核无 netfilter NAT 栈 | 用 Podman 替代 |

### 15.2 有缺陷但可接受的

| 项目 | 现象 | 规避 |
|---|---|---|
| 亮屏功耗 | 高于鸿蒙 | 降低亮度、缩短息屏时间 |
| 键盘背光键 | 无作用 | — |
| 地球键 | 无作用（`KEY_COMPOSE` 未绑定） | 用 Ctrl+空格 |
| 系统监视器 | 需打补丁才显示磁盘 | 见 [11.4](#114-系统监视器磁盘显示-0b0b) |
| `smartmontools` | 服务 failed | 无影响，可 `systemctl disable` |

### 15.3 应用层限制

| 项目 | 说明 |
|---|---|
| Steam / 大多数 PC 游戏 | 无 arm64 版 |
| 炉石等 Windows 游戏 | 需串流或云游戏 |
| 安卓应用 | 理论可走 Waydroid，GPU 支持不完整 |
| Office 文档转换（DSH） | 社区构建缺 LibreOffice Kit 绑定 |

---

## 16. 附录：速查表

### 16.1 分区大小（本机 256 G）

| 分区 | 大小 | 用途 |
|---|---|---|
| `boot` | 96 MiB | 内核 + DTB（header v2） |
| `ramdisk` | 2 MiB | initramfs |
| `dtbo` | 24 MiB | 设备树覆盖层表（9 条目） |
| `super` | 7.16 GiB | 动态分区 |
| `userdata` | 剩余 | 鸿蒙数据（后改为 `/data`） |
| `rawdump` | 25 MiB | ABL 日志 |

### 16.2 boot header 偏移

```
0x008 kernel_size     0x010 ramdisk_size
0x024 page_size       0x028 header_version
0x040 cmdline[512]    0x240 id[32]
0x260 extra_cmdline[1024]     ← 不是 0x2C0！
0x630 recovery_dtbo_size   0x66C header_size=1660
0x670 dtb_size             0x674 dtb_addr
```

### 16.3 libinput 校准矩阵

| 用途 | 矩阵 |
|---|---|
| 触摸屏（本机） | `1 0 0 0 -1 1` |
| M-Pencil（本机） | `1 0 0 0 -1 0.991` |

### 16.4 关键硬件参数

| 项目 | 值 |
|---|---|
| 背光芯片 | LP8556 @ i2c-11 `0x2C` |
| 背光使能 | TLMM GPIO 10 |
| 背光控制寄存器 | `0x00`（亮度）、`0x01`（设备控制 = `0x85`） |
| 触摸屏 | `/dev/input/event*`，`ID_INPUT_TOUCHSCREEN` |
| 触控笔 | `/dev/input/event3`，`ID_INPUT_TABLET` |
| 键盘 | `/dev/input/event12`，`HUAWEI MatePad Keyboard` |
| UFS 控制器 | `1d84000.ufshc` |
| 数据盘 | `/dev/sda40`，LABEL=`MATEPADDATA` |

### 16.5 服务清单（本移植新增）

| 服务 | 作用 |
|---|---|
| `matepad-backlight.service` | LP8556 开机初始化 |
| `matepad-brightnessd.service` | 捕获 Fn+1/Fn+2 亮度键 |
| `matepad-panelbacklightd.service` | 背光随 DPMS 开关 |
| `matepad-ufs-retry.service` | UFS 二次探测 |
| `matepad-data.service` | 挂载 `/data` |
| `matepad-volkeys.service` | 音量键随屏幕方向交换 |
| `fcitx5.service`（用户级） | 中文输入法 |

### 16.6 常用命令

```bash
# 亮度
sudo matepad-backlight set 50
sudo matepad-backlight up / down

# 进 fastboot
sudo touch /var/lib/linux70/fastboot-next-boot && sudo reboot

# 看 IP
hostname -I
# 或双击桌面「我的 IP」

# 检查 UFS
lsblk | grep sda
systemctl status matepad-ufs-retry matepad-data

# 检查背光
sudo i2cget -y -f 11 0x2c 0x00
cat /var/lib/matepad/brightness
```

---

## 17. 参考与致谢

### 上游项目

| 项目 | 内容 |
|---|---|
| [`svesnav/linux-dby-w09`](https://github.com/svesnav/linux-dby-w09) | 内核、设备树、引导镜像工具 |
| [`svesnav/kubuntu-dby-w09`](https://github.com/svesnav/kubuntu-dby-w09) | Kubuntu 镜像与硬件服务 |
| [`svesnav/dby-w09-installer`](https://github.com/svesnav/dby-w09-installer) | 在鸿蒙上运行的安装器 |
| [`bkerler/edl`](https://github.com/bkerler/edl) | EDL 工具 |

### 内核补丁来源

| 来源 | 内容 |
|---|---|
| [`shuuri-labs/pocknix-os` PR #161](https://github.com/shuuri-labs/pocknix-os/pull/161) | camcc / dsi_phy XO 投票释放（SM8250） |
| PR #167 | Wi-Fi 睡眠时关闭（未采用） |

### 其他参考

- `Zhou-Yujing114514/deepseek-harness-linux` — DSH Linux arm64 打包
- 高通 SM8250 平台文档、Linux 主线 `sm8250.dtsi`

### 本手册的探索产出

```
flash-set/                  引导镜像（含各阶段实验版本）
tools/                      DTB/DTBO 修改与校验脚本
patches/                    内核补丁 1097/1098
packages/                   ksystemstats SdMmc 补丁与 deb
files/                      所有系统脚本与 systemd 单元
kernel-new/                 补丁内核与模块
docs/kernel-patch-rollback.md   内核补丁回退说明
```

---

## 变更记录

### 2026-11-08 — 初版
- 基于一次完整实机部署（2026-11-05 → 11-08）整理
- 补充上游缺失的 20+ 处问题与解决方案
- 新增内部存储、系统调优、应用生态三个章节

---

<p align="center">
  <i>本手册基于一次完整实机部署整理。所有寄存器值、偏移、矩阵参数均来自实测，非推测。</i><br>
  <i>刷机有风险，请务必先完成 EDL 全盘备份。</i>
</p>

---

## 仓库结构

```
.
├── README.md              完整部署指南（本文件）
├── LICENSE                MIT
├── docs/
│   └── README.md          脚本 / systemd 单元 / 补丁的安装说明
├── scripts/               可直接复用的系统脚本
│   ├── matepad-backlight          LP8556 背光控制
│   ├── matepad-brightnessd        Fn+1/Fn+2 亮度键守护进程
│   ├── matepad-panelbacklightd    背光随 DPMS 开关（省电最大项）
│   ├── matepad-ufs-retry          UFS 二次探测
│   ├── matepad-internal-storage   /data 挂载管理
│   └── rollback-optimizations.sh  一键回退所有优化
├── systemd/               对应的 systemd 单元
└── patches/
    ├── 1097-*.patch       camcc XO 投票释放（深睡尝试）
    ├── 1098-*.patch       dsi_phy AHB 时钟（深睡尝试）
    └── ksystemstats-sdmmc.patch   系统监视器磁盘显示修复
```

## 参与与反馈

如果你在**其他批次的 DBY-W09** 上部署时发现了不同的现象（尤其是背光芯片型号），
欢迎提 Issue 补充。本文档的价值就在于把"上游没写、但实际会卡住人"的点记录下来。

特别希望收集的信息：

- 背光芯片是 RT8555 还是 LP8556（`i2cget -y -f 11 0x31 0x00` 能否读通）
- `ddr_total_size` 的实际值（从 ABL rawdump 读，判断是 6 GB 还是 8 GB 版）
- UFS 首次探测是否同样失败
- 键盘/笔的型号与配对情况

## 免责声明

**刷机有风险，变砖自负。** 本手册记录的是**一台具体设备**上的成功路径，
不保证在所有 DBY-W09 上都能复现（硬件变体、固件版本、批次差异都可能影响）。

动手前请务必：

1. 完成 EDL 全盘备份
2. 确认 `fastboot oem edl` 可用（这是唯一的救援通道）
3. 接受"可能失去鸿蒙数据"的后果