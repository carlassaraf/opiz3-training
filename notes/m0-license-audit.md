# M0 — License audit of the Orange Pi vendor image

Image: `Orangepizero3_1.0.4_debian_bookworm_server_linux6.1.31.7z`, booted on the Orange Pi Zero 3 (H618).
Raw command output: [`evidence/m0-vendor-facts.log`](../evidence/m0-vendor-facts.log). Boot log (bootloader versions): [`evidence/m0-vendor-boot.log`](../evidence/m0-vendor-boot.log).

## 1. What is in the image

| Component | Version found | License | Source location | Exact match? |
|---|---|---|---|---|
| TF-A (BL31) | `v2.11.0(debug):4b9be5ab`, built Jul 9 2024 (detects the SoC as "Allwinner H616") | BSD-3-Clause | TODO: upstream TF-A or an Orange Pi fork? does `4b9be5ab` exist there? | TODO |
| U-Boot + SPL | `2024.01-orangepi`, built Jul 11 2024 16:36:36 +0800 | GPL-2.0+ | TODO | TODO |
| Linux kernel | `6.1.31-sun50iw9 #1.0.4 SMP Thu Jul 11 16:37:41 CST 2024`, built by `root@orangepi` with Arm GNU Toolchain 9.2-2019.12 (GCC 9.2.1) | GPL-2.0 | TODO: kernel repo + branch | TODO |
| Vendor kernel modules | `uwe5622_bsp_sdio`, `sprdwl_ng`, `sprdbt_tty`, `sunxi_addr` (UWE5622 Wi-Fi/BT) | TODO: GPL? check `modinfo -l` | TODO | TODO |
| Firmware blobs | UWE5622: `wcnmodem.bin`, `wifi_2355b001_1ant.ini`, `uwe5621ds/`; plus many unrelated (Broadcom, Realtek, Intel, MediaTek, Rockchip, i.MX, DVB, …) | TODO: proprietary, redistributable? | n/a (no source) | n/a |
| Debian userland | Debian 12 (bookworm), 535 lines of `dpkg -l` (≈530 packages) | mix: GPL-2/3, LGPL, MIT, BSD | Debian archive / sources.debian.org | yes (Debian versions) |
| Build system | `orangepi-build` @ `82f9e56` (`BRANCH=next`, `IMAGE_TYPE=user-built`) | GPL-2.0 | https://github.com/orangepi-xunlong/orangepi-build | TODO: does that commit exist publicly? |

Observations so far:
- U-Boot and the kernel were built a minute apart on Jul 11 2024 (`16:36:36` and `16:37:41`, both +0800/CST), which suggests one `orangepi-build` run. TF-A was built two days earlier, possibly prebuilt.
- The kernel config is exposed through `/proc/config.gz`, so the configuration can be recovered from the running image.
- The kernel is a vendor BSP kernel (`sun50iw9`), not mainline 6.1.31.
- The Wi-Fi/BT stack depends on out-of-tree vendor drivers and a binary firmware blob.
- `/lib/firmware` ships far more firmware than this board needs.

## 2. Where the sources are published

TODO:
- Kernel: repo, branch and, if possible, the exact commit that produced `6.1.31-sun50iw9 #1.0.4`.
- U-Boot and TF-A: repos and versions used by `orangepi-build` @ `82f9e56` for `sun50iw9`.
- UWE5622 drivers: in-tree in the vendor kernel, or a separate repo?
- Firmware: license files (e.g. `/lib/firmware/README.md`, upstream `linux-firmware` WHENCE).

## 3. What a company shipping this image would have to provide

TODO: one paragraph each:
- GPL-2.0 source for the kernel and U-Boot (complete corresponding source, `.config`, build scripts), shipped with the product or as a 3-year written offer.
- License texts and copyright notices for everything shipped.
- LGPL obligations (glibc and other libraries): allowing the user to relink against a modified library.
- GPLv3 packages (`bash`, `coreutils`, …): installation information if the device is a locked-down "User Product".
- Firmware blobs: redistribution terms.

## 4. Gaps and risks

TODO: what in the vendor image makes compliance hard (exact-commit traceability, toolchain provenance, blob licenses, unneeded firmware), and what the later modules replace (own U-Boot in M2, kernel in M3, Yocto image in M5).
