# 目录说明

本目录存放从部署过程中提取的可复用资产。

## scripts/

在平板上运行的系统脚本，安装到 `/usr/local/sbin/`。

| 脚本 | 作用 | 依赖 |
|---|---|---|
| `matepad-backlight` | LP8556 背光控制（up/down/set/raw/get） | `i2c-tools` |
| `matepad-brightnessd` | 捕获 Fn+1/Fn+2 亮度键（绕过 KDE kglobalaccel） | `python3` |
| `matepad-panelbacklightd` | 背光随 DRM DPMS 自动开关（**省电最大项**） | `python3` |
| `matepad-ufs-retry` | UFS 二次探测（解决 `link startup failed`） | 无 |
| `matepad-internal-storage` | `/data` 挂载/卸载/状态查看 | `e2fsprogs` |
| `rollback-optimizations.sh` | 一键回退所有系统优化 | 无 |

### 安装

```bash
sudo install -m 755 scripts/matepad-backlight          /usr/local/sbin/
sudo install -m 755 scripts/matepad-brightnessd        /usr/local/sbin/
sudo install -m 755 scripts/matepad-panelbacklightd    /usr/local/sbin/
sudo install -m 755 scripts/matepad-ufs-retry          /usr/local/sbin/
sudo install -m 755 scripts/matepad-internal-storage   /usr/local/sbin/
sudo install -m 755 scripts/rollback-optimizations.sh  /data/
```

## systemd/

对应的 systemd 单元，安装到 `/etc/systemd/system/`。

| 单元 | 作用 |
|---|---|
| `matepad-brightnessd.service` | 亮度键守护进程 |
| `matepad-panelbacklightd.service` | 背光随 DPMS 守护进程 |
| `matepad-ufs-retry.service` | UFS 二次探测（开机早期） |
| `matepad-data.service` | 挂载 `/data` |

### 安装

```bash
sudo cp systemd/*.service /etc/systemd/system/
sudo systemd-analyze verify /etc/systemd/system/matepad-data.service
sudo systemctl daemon-reload
sudo systemctl enable --now matepad-ufs-retry matepad-data \
                          matepad-brightnessd matepad-panelbacklightd
```

> ⚠️ **注意**：`matepad-backlight.service`（LP8556 开机初始化）不在此目录，
> 因为它的 `ExecStart` 路径依赖你自己的安装位置，请按
> [README 第 9.1 节](../README.md#91-背光最关键的一步) 手动创建。

## patches/

| 补丁 | 来源 | 作用 |
|---|---|---|
| `1097-clk-qcom-camcc-sm8250-*.patch` | [pocknix-os PR #161](https://github.com/shuuri-labs/pocknix-os/pull/161) | camcc GDSC 时钟不再持有 XO 投票 |
| `1098-drm-msm-dsi-phy-*.patch` | 同上 | dsi_phy AHB 时钟改由 runtime PM 管理 |
| `ksystemstats-sdmmc.patch` | 本项目 | 让 ksystemstats 接受 `SdMmc` 类型磁盘 |

### 应用内核补丁

```bash
cd /data/linux-7.0.14
patch -p1 < /path/to/patches/1097-*.patch
patch -p1 < /path/to/patches/1098-*.patch
```

详见 [README 第 11.5 节](../README.md#115-内核补丁深睡尝试)。

> 📌 **提醒**：这两个补丁只能释放一个永久时钟投票，**无法真正进入深睡**。
> cluster 级 cpuidle 状态未注册是移植内核本身的空白。

### 应用 ksystemstats 补丁

```bash
apt-get source ksystemstats
cd ksystemstats-5.27.11
patch -p1 < /path/to/patches/ksystemstats-sdmmc.patch
dpkg-buildpackage -b -uc -us -j4
sudo dpkg -i ../ksystemstats_*.deb
```
