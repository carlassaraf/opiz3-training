# Embedded Linux Training Plan — Orange Pi Zero 3 Edition

**Audience:** Junior firmware engineers coming from the Zephyr RTOS team
**Source of truth:** *Mastering Embedded Linux Development*, 4th Edition — Frank Vasquez & Chris Simmonds, Packt, 2025 (ISBN 9781803232591). Linux 6.6, Yocto Project 5.0 *Scarthgap*, Buildroot 2024.02 LTS, U-Boot 2024.04.
**Companion code:** https://github.com/PacktPublishing/Mastering-Embedded-Linux-Development (read the README errata before starting)
**Training platform:** Orange Pi Zero 3, 4 GB LPDDR4 (Allwinner H618, 4× Cortex-A53, AArch64)
**Business goal:** Make the team capable of designing, building, shipping and maintaining Linux-based IoT products, with the Yocto Project as the production build system.

> Note on the title: the 3rd edition was called *Mastering Embedded Linux **Programming***. The 4th edition was renamed *Mastering Embedded Linux **Development***. Make sure every trainee has the 4th edition — chapter numbers in this plan refer to it.

---

## 1. How this plan works

### 1.1 Principles

1. **Follow the book in order.** Every module maps to one or two chapters. Trainees read the chapter first, then do the book's exercises, then do the *Orange Pi Zero 3 port* of those exercises.
2. **The book uses BeaglePlay, Raspberry Pi 4 and QEMU; we use the Orange Pi Zero 3.** The BeaglePlay (TI AM62x, Cortex-A53) is the closest match, so most manual bring-up chapters translate almost 1:1 — same architecture, same Bootlin AArch64 toolchain. Where a book exercise is board-specific, this plan gives the H618 equivalent.
3. **QEMU first, hardware second.** When the book offers a QEMU path, do it first. It isolates "I don't understand the concept" from "my board/cable/SD card is broken".
4. **Yocto is the spine.** From Module 5 onward every deliverable lands in the team's own layers (`meta-opiz3-bsp` and `meta-opiz3-apps`). By the capstone, the trainee owns a production-style BSP, distro and image.
5. **Every lab has an exit check.** No lab is "done" until its validation commands produce the expected output, and the evidence (logs, screenshots, `git` commits) is pushed to the trainee's repo.

### 1.2 Duration and cadence

| Mode | Duration | Notes |
|---|---|---|
| Recommended: 50% allocation (~20 h/week) | **18 weeks** | Leaves room for real project work |
| Full-time bootcamp | ~9 weeks | Needs a fast shared build server |

Weekly rhythm: Monday kick-off (30 min, instructor walks through the chapter's key ideas), self-paced reading + labs, Thursday clinic (1 h, debugging help), Friday demo + exit-check review (1 h, trainees show their validation output).

### 1.3 Trainee repository layout

Each trainee keeps one Git repo, reviewed weekly:

```
el-training-<name>/
├── notes/                 # chapter notes, answers to review questions
├── labs/
│   ├── m01-toolchain/
│   ├── m02-bootloader/
│   └── ...
├── evidence/              # serial logs, command outputs used for validation
├── layers/
│   ├── meta-opiz3-bsp/    # machine, bootloader, kernel, wks (from Module 6)
│   └── meta-opiz3-apps/   # distro, images, apps, drivers (from Module 6)
└── kas/ or setup/         # reproducible Yocto setup (kas file or repo manifest)
```

---

## 2. Lab setup

### 2.1 Host machine (per trainee or shared build server)

| Item | Minimum | Recommended |
|---|---|---|
| OS | Ubuntu 24.04 LTS **x86-64** (book errata: ARM hosts don't work verbatim) | Same |
| CPU | 8 cores | 16+ cores |
| RAM | 16 GB | 32 GB+ |
| Disk | 300 GB free SSD | 1 TB NVMe |

**Shared infrastructure (strongly recommended):** one build server exporting a shared Yocto `DL_DIR` and `SSTATE_DIR` (NFS or HTTP sstate mirror). This cuts a clean `core-image-minimal` from hours to minutes for everyone after the first build. Also run a TFTP server and an NFS server on the lab network for Module 4.

### 2.2 Hardware kit per trainee

| Item | Purpose |
|---|---|
| Orange Pi Zero 3, 4 GB | Target |
| 5 V / 3 A USB-C power supply | Stable power (undervoltage causes "random" crashes) |
| 3.3 V USB-to-TTL serial adapter (FTDI/CP2102) | Debug UART (UART0, 115200 8N1) — **mandatory** |
| 2× microSD 16–32 GB (A1, good brand) + USB reader | One "known good", one for experiments |
| Ethernet cable + lab switch | Primary network (onboard Gigabit, Motorcomm YT8531 PHY) |
| USB-A ↔ USB-C data cable | USB OTG / FEL recovery mode |
| USB Wi-Fi dongle with mainline driver (e.g. MT7601U or MT7612U based) | Wi-Fi labs (see §2.4) |
| Breadboard, jumpers, LEDs, push buttons, resistors | GPIO labs |
| BME280 breakout (I2C) | Sensor / IIO driver labs + capstone |
| SPI device (e.g. MCP3008 ADC or SX126x LoRa module) | SPI labs |
| GPS/GNSS module with UART output (optional) | UART add-on lab (mirrors the book's GNSS example) |
| USB power meter (inline USB-C) | Power management labs |
| Heatsink | Sustained Yocto/perf workloads on target |
| Logic analyzer (shared, 1 per 3 trainees) | Bus debugging |

### 2.3 Orange Pi Zero 3 facts the trainees must know on day one

- **SoC:** Allwinner H618 = H616 with more L2 cache and a different CPU cluster control block. Software-wise it is H616-compatible except for TF-A and U-Boot.
- **Mainline support:** device tree `sun50i-h618-orangepi-zero3.dtb` is in mainline Linux since **v6.6** — exactly the kernel version the book uses. U-Boot has `orangepi_zero3_defconfig`. Buildroot has `orangepi_zero3_defconfig` using upstream U-Boot and Linux.
- **Boot chain:** Boot ROM (BROM) → U-Boot SPL (at 8 KiB offset on the SD card) → TF-A BL31 → U-Boot proper → Linux. Compare this with the BeaglePlay chain in Chapter 3 (R5 SPL → TF-A → OP-TEE → A53 SPL → U-Boot).
- **PMIC:** X-Powers AXP313A on I2C.
- **Storage:** microSD + 16 MB SPI NOR flash (useful for Chapter 9 and for booting U-Boot from SPI).
- **SD card-detect is broken in hardware** (`broken-cd` in the DT) — don't waste time debugging hot-plug.
- **FEL mode:** if no bootable media is found, the BROM enters FEL over USB OTG. `sunxi-fel` (from `sunxi-tools`) can load SPL/U-Boot directly into RAM — the unbrickable recovery path.

### 2.4 Known deviation: on-board Wi-Fi/BT

The on-board Wi-Fi/BT combo (Unisoc UWE5622 family) **has no mainline driver**. The book's Chapter 7 Wi-Fi/BT exercise is done with:

- **Default path:** a USB Wi-Fi dongle with a mainline driver + `linux-firmware` package — this teaches exactly the Yocto skills the chapter targets (kernel config fragment, firmware packaging, `wpa_supplicant`/`iwd`, `MACHINE_FEATURES`).
- **Stretch path:** package the out-of-tree vendor driver as an external kernel module recipe. Great Yocto exercise, but not production-grade — discuss why (maintenance cost of out-of-tree drivers is a key lesson for IoT product decisions).

---

## 3. Book-to-board adaptation map

| Ch. | Title | Book hardware | Orange Pi Zero 3 adaptation |
|---|---|---|---|
| 1 | Starting Out | — | Host setup; board tour; license audit of the OPi vendor image |
| 2 | Learning about Toolchains | Bootlin aarch64 toolchain | **Identical** (same AArch64 toolchain) |
| 3 | All about Bootloaders | BeaglePlay, QEMU | QEMU as in book, then TF-A (`sun50i_h616`) + U-Boot `orangepi_zero3_defconfig`; FEL boot |
| 4 | Configuring and Building the Kernel | BeaglePlay, RPi4, QEMU | Mainline 6.6 `defconfig` + `sun50i-h618-orangepi-zero3.dtb` |
| 5 | Building a Root Filesystem | BeaglePlay, QEMU | BusyBox rootfs, initramfs, TFTP + NFS root on OPiZ3 |
| 6 | Selecting a Build System | BeaglePlay (Buildroot "nova", Yocto `meta-ti`) | Buildroot `orangepi_zero3_defconfig` → custom board; Yocto intro with team BSP layer |
| 7 | Developing with Yocto | RPi4, QEMU | `devtool`, SDK, package feeds, Wi-Fi via USB dongle in our layers |
| 8 | Yocto under the Hood | Yocto | **Identical** concepts, applied to our layers |
| 9 | Creating a Storage Strategy | BeaglePlay | microSD (MMC) + SPI NOR (MTD, UBI/UBIFS), read-only rootfs |
| 10 | Updating Software in the Field | RPi4, QEMU | Mender A/B on QEMU (book), then port to OPiZ3 (U-Boot integration); balena read-only (OPiZ3 not a balenaOS device type) |
| 11 | Interfacing with Device Drivers | BeaglePlay | 26-pin header: GPIO (libgpiod), I2C3, SPI1, UART5, `dummy-char` module via Yocto |
| 12 | Prototyping with Add-On Boards | BeaglePlay (add-on boards) | BME280 (I2C), GNSS (UART), SPI device on the 26-pin header; DT overlays |
| 13 | Starting Up – The init Program | Yocto, Buildroot | BusyBox init / SysV / systemd on OPiZ3; systemd units + watchdog |
| 14 | Managing Power | BeaglePlay | cpuidle/cpufreq (verify H616 support in 6.6), runtime PM, s2idle, measure with USB meter |
| 15 | Packaging Python | Host + Yocto | Host tooling + Python recipes in `meta-opiz3-apps` |
| 16 | Deploying Container Images | RPi4 | Docker via `meta-virtualization` on OPiZ3 (4 GB RAM is plenty) |
| 17 | Learning about Processes and Threads | Any | Run on OPiZ3 (4 cores — good for affinity/scheduling labs) |
| 18 | Managing Memory | Any | Run on OPiZ3; Valgrind, `smem`, OOM experiments |
| 19 | Debugging with GDB | RPi4, Yocto, Buildroot | Remote GDB via SDK; core dumps; kernel debugging (kgdb over UART) |
| 20 | Profiling and Tracing | RPi4, Buildroot | `perf`, ftrace, LTTng, eBPF (bcc/bpftrace/ply), Valgrind |
| 21 | Real-Time Programming | Yocto | `linux-yocto-rt` 6.6 for OPiZ3; `cyclictest` comparisons |

---

## 4. Zephyr → Linux concept bridge

Use this table in the first kick-off. Trainees already know half of embedded Linux — they just don't know it yet.

| Zephyr concept | Embedded Linux equivalent | Key difference to stress |
|---|---|---|
| Devicetree (`.dts`, overlays, bindings) | Same DT syntax and bindings culture | In Linux the DT is consumed **at runtime** by the kernel, not compiled into C macros |
| Kconfig / `prj.conf` | Kconfig in U-Boot, Linux, BusyBox, Buildroot | Same tool, several independent configs |
| `west` + manifest | `repo`/`kas` + Yocto layers | Yocto builds a whole distro, not one binary |
| Zephyr SDK toolchain | Cross toolchain (Bootlin, Buildroot, Yocto SDK) | Need a matching **sysroot** (libc, headers) |
| MCUboot | U-Boot + A/B partitions + Mender/RAUC/SWUpdate | Bootloader is a full OS-like environment |
| Device driver API (`device_get_binding`) | Kernel drivers exposing `/dev`, sysfs, IIO, netdev | User space never touches registers directly |
| Threads, `k_sem`, `k_msgq` | Processes, pthreads, POSIX IPC | MMU, process isolation, virtual memory |
| `SYS_INIT`, `main()` | init system (systemd) + services | Boot = many processes started by PID 1 |
| `printk`, RTT, logging subsystem | `dmesg`, journald, syslog, ftrace | Logs persist and are queryable |
| Static memory, heap | Virtual memory, page cache, OOM killer | "Free memory" means something different |
| Hard real-time by design | PREEMPT_RT, latency measurement | Real-time must be measured and tuned |

---

## 5. Schedule overview

| Week | Module | Book chapters | Milestone |
|---|---|---|---|
| 1 | M0 — Onboarding & board tour | 1 | Host ready, vendor image boots, serial console works |
| 2 | M1 — Toolchains | 2 | Cross-compiled static + dynamic binaries running on target |
| 3 | M2 — Bootloaders | 3 | Own TF-A + U-Boot booting from SD **and** via FEL |
| 4 | M3 — Kernel | 4 | Own 6.6 kernel boots to "no rootfs" panic, then to shell |
| 5 | M4 — Root filesystem | 5 | BusyBox rootfs via initramfs, SD and NFS |
| 6–7 | M5 — Build systems | 6 | Buildroot custom board + first Yocto image from **own BSP layer** |
| 8 | M6 — Developing with Yocto | 7 | devtool workflow, SDK, package feed, Wi-Fi |
| 9 | M7 — Yocto under the hood | 8 | Debugging a broken recipe; buildhistory; sstate mirror |
| 10 | M8 — Storage | 9 | Read-only rootfs + data partition; UBIFS on SPI NOR |
| 11 | M9 — OTA updates | 10 | Mender A/B update + rollback on target |
| 12 | M10 — Drivers & add-on boards | 11, 12 | GPIO/I2C/SPI/UART from user space; kernel module recipe; DT overlay |
| 13 | M11 — init & power | 13, 14 | systemd services + watchdog; power measurements |
| 14 | M12 — Python & containers | 15, 16 | Python app recipe; Docker container on target |
| 15 | M13 — Processes, threads, memory | 17, 18 | IPC labs; memory leak found with Valgrind |
| 16 | M14 — Debugging, profiling, tracing | 19, 20 | Remote GDB; perf flame graph; eBPF trace |
| 17 | M15 — Real-time | 21 | cyclictest comparison: standard vs PREEMPT_RT |
| 18 | Capstone | All | IoT gateway image demo + review |

---

## 6. Modules

Each module lists: **Reading**, **Objectives**, **Labs** (book exercise first, then the OPiZ3 port), **Exit checks** (what must be demonstrated), and **Review questions**.

---

### M0 — Onboarding & board tour (Week 1) · Chapter 1

**Reading:** Chapter 1 + the repo README (errata).

**Objectives**
- Understand when (and when not) to choose Linux; the four elements: toolchain, bootloader, kernel, root filesystem.
- Understand GPL v2/v3, LGPL, permissive licenses and their product implications.
- Provision the Ubuntu 24.04 x86-64 host exactly as the book describes.

**Labs**
1. Provision the host per Chapter 1 (packages, Git config, disk space).
2. Wire the serial adapter (GND, TX, RX — **never** connect VCC). Open the console with `picocom -b 115200 /dev/ttyUSB0` (or `tio`).
3. Flash the vendor Debian/Ubuntu image, boot it, and do a **board tour**: `cat /proc/cpuinfo`, `cat /proc/device-tree/model`, `lsblk`, `ip link`, `cat /proc/mtd` (if enabled), `dmesg | less`.
4. License audit: list the kernel version and bootloader of the vendor image and find where its sources are published. Write a one-page note on what the company would need to provide if it shipped that image in a product.

**Exit checks**
- Serial log in `evidence/m0-vendor-boot.log` showing the full boot from SPL to login prompt.
- `notes/m0-board-tour.md` with SoC, RAM, storage devices, network interfaces, kernel version.
- License note reviewed by the instructor.

**Review questions**
- What are the four elements of embedded Linux, and which one does the Boot ROM load?
- Why does GPLv3 matter for locked-down IoT devices?

---

### M1 — Toolchains (Week 2) · Chapter 2

**Reading:** Chapter 2.

**Objectives**
- Toolchain anatomy: binutils, GCC, C library, kernel headers; tuple naming; sysroot.
- Static vs dynamic linking, shared library versioning, `pkg-config`, cross-compiling Make/Autotools/CMake projects.

**Labs**
1. Install the **Bootlin aarch64 toolchain 2024.02-1** exactly as the book does (it matches our Cortex-A53).
2. Do every book exercise: `-v` / `-print-sysroot`, build the `Chapter02/library` example as static and shared library.
3. OPiZ3 port: cross-compile a `hello` and the library example, `scp` them to the vendor image, run them.
4. Cross-compile a real Autotools project and a CMake project (e.g. `libgpiod` and a small CMake app) using a CMake toolchain file you write yourself.
5. Break it on purpose: run a dynamically linked binary whose libc doesn't match the target. Capture and explain the error.

**Exit checks**
```sh
$ file hello
hello: ELF 64-bit LSB executable, ARM aarch64, ...
# on target:
$ ./hello            # prints expected output
$ ldd ./hello-dyn    # (or readelf -d) shows expected NEEDED libs
```
- CMake toolchain file committed to `labs/m01-toolchain/`.

**Review questions**
- What is the sysroot and why must it match the target's libraries?
- Why is glibc vs musl a product decision, not just a technical one?

---

### M2 — Bootloaders (Week 3) · Chapter 3

**Reading:** Chapter 3.

**Objectives**
- Boot sequence phases; device tree basics (Zephyr engineers: compare!); U-Boot build, environment, commands, boot scripts, FIT images; porting U-Boot to a new board.

**Labs**
1. Book path: build U-Boot for QEMU and boot it.
2. Read the BeaglePlay sections and draw both boot chains (BeaglePlay vs OPiZ3) side by side in your notes.
3. OPiZ3 port — build your own boot chain:
   - Build **TF-A** BL31: `make CROSS_COMPILE=aarch64-linux- PLAT=sun50i_h616 DEBUG=0 bl31` (use a TF-A release with H618 support; verify on the linux-sunxi wiki).
   - Build **U-Boot v2024.04** (book version): `make orangepi_zero3_defconfig && make BL31=<path>/bl31.bin SCP=/dev/null CROSS_COMPILE=aarch64-linux-`.
   - Write `u-boot-sunxi-with-spl.bin` to the SD card at 8 KiB: `dd if=u-boot-sunxi-with-spl.bin of=/dev/sdX bs=1k seek=8 conv=fsync`.
4. FEL boot: put the board in FEL (no SD card), then `sunxi-fel -v uboot u-boot-sunxi-with-spl.bin`. This is your recovery path for the rest of the course.
5. U-Boot hands-on: `printenv`, `setenv`/`saveenv`, `mmc info`, `md`, `fdt` commands, `sf probe` on the SPI NOR, write a `boot.cmd` → `boot.scr` with `mkimage`.
6. Porting exercise (book's "nova" equivalent): create a custom board defconfig `opiz3_training_defconfig` that changes the prompt to `opiz3 => ` and sets a custom default environment.

**Exit checks**
- Serial log showing `U-Boot SPL 2024.04...`, `NOTICE: BL31: ...`, and the custom `opiz3 =>` prompt.
- FEL boot log.
- `boot.cmd` committed.

**Review questions**
- Why does the H618 need TF-A before U-Boot proper? What does BL31 provide to Linux (hint: PSCI)?
- What is the difference between the U-Boot DT and the kernel DT?

---

### M3 — Configuring and building the kernel (Week 4) · Chapter 4

**Reading:** Chapter 4.

**Objectives**
- Choosing a kernel (mainline vs vendor vs LTS), Kconfig/Kbuild, building `Image`, modules and DTBs, booting, early-boot debugging, porting to a new board via DT.

**Labs**
1. Book path: build Linux 6.6 for QEMU AArch64 and boot it.
2. OPiZ3 port: clone mainline `v6.6.y` (stable), `make ARCH=arm64 CROSS_COMPILE=aarch64-linux- defconfig`, build `Image`, `modules`, `dtbs`. Confirm `arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dtb` exists.
3. Boot from U-Boot: load `Image` + DTB from the SD card FAT partition (`load mmc 0:1 ...`) and `booti`. Expect the "VFS: Unable to mount root fs" panic — that's success for this lab.
4. Boot over the network: TFTP `Image` + DTB from the lab server.
5. Kernel config: use `menuconfig` to enable a feature, then produce a minimal **config fragment** (`.cfg`) — you'll reuse this format in Yocto.
6. DT exercise: create `sun50i-h618-orangepi-zero3-training.dts` that includes the upstream DTS, changes `model`, enables `i2c3` on the 26-pin header, and adds a `gpio-leds` node for an LED on a header GPIO. Boot it and check.

**Exit checks**
```sh
# kernel panic log captured, then later (after M4):
$ uname -r                    # 6.6.x
$ cat /proc/device-tree/model # your custom model string
$ ls /sys/class/leds/         # your LED appears
```

**Review questions**
- What happens between `booti` and `init`? Name the console-related bootargs and why `earlycon` helps.
- Why is mainline support for the H618 a business advantage over the vendor 6.1 BSP kernel?

---

### M4 — Building a root filesystem (Week 5) · Chapter 5

**Reading:** Chapter 5 (apply errata for p.159: rebuild the kernel **without** built-in initramfs before NFS root).

**Objectives**
- Rootfs directory layout, BusyBox (vs ToyBox), libraries, device nodes, `proc`/`sysfs`, kernel modules, initramfs (standalone and built-in), init with `inittab`, user accounts, `devtmpfs`/`mdev`, network config, TFTP/NFS workflow.

**Labs**
1. Build the staging rootfs exactly as the book does (BusyBox, libs copied from the toolchain sysroot with the repo's `list-libs` helper).
2. QEMU boot with initramfs (book path).
3. OPiZ3: boot the same rootfs as initramfs, then from the SD card ext4 partition, then via **NFS root** over the lab network.
4. Add an `inittab`, user accounts, `mdev`, and static network config. Mount `proc`, `sys`, `devtmpfs`.
5. Install your kernel modules into the rootfs and load one with `modprobe`.

**Exit checks**
- Three boot logs: initramfs, SD rootfs, NFS rootfs.
- On NFS: create a file on the host's export, `cat` it on the target without rebooting.
- `ls -l /lib/modules/$(uname -r)` populated; `lsmod` shows a loaded module.

**Review questions**
- Why is building rootfs by hand a bad idea for products — and why did we do it anyway?
- What does `devtmpfs` give you that a static `/dev` doesn't?

---

### M5 — Selecting a build system (Weeks 6–7) · Chapter 6

**Reading:** Chapter 6.

**Objectives**
- Build system concepts, package formats, Buildroot (configs, custom board, packages, licenses), Yocto intro (Poky, layers, BitBake, images, `MACHINE`), creating a BSP.

**Labs — Buildroot (Week 6)**
1. Buildroot 2024.02 LTS (book version): `make orangepi_zero3_defconfig && make`. Flash `output/images/sdcard.img`, boot.
2. Book "nova" equivalent: create `BR2_EXTERNAL` tree `br2-opiz3-training` with your own board directory, `post-image.sh`, genimage config, defconfig pointing to **your** custom U-Boot defconfig and DTS from M2/M3.
3. Add a custom package (your `hello` from M1) and generate the license manifest (`make legal-info`).

**Labs — Yocto (Week 7) — start of the Yocto spine**
1. Book path: build `core-image-minimal` for `qemuarm64` on Scarthgap and run it with `runqemu`.
2. Create the team layers with `bitbake-layers create-layer`: `meta-opiz3-bsp` and `meta-opiz3-apps`. Set up the build reproducibly with **kas** (or a repo manifest) pinned to Scarthgap: `poky`, `meta-openembedded`, `meta-arm` (for TF-A).
3. Write the **machine** `opiz3.conf` (see Appendix A for a starting skeleton):
   - TF-A from `meta-arm` (`TFA_PLATFORM = "sun50i_h616"`),
   - U-Boot with a `.bbappend` passing `BL31=` and `SCP=/dev/null`, using your training defconfig,
   - `linux-yocto` 6.6 with `defconfig` + your fragments and DTS,
   - a `.wks` file placing `u-boot-sunxi-with-spl.bin` at 8 KiB.
4. Before writing it, check whether the community `meta-sunxi` layer (Scarthgap branch) has an Orange Pi Zero 3 machine. If it does, build it too and write a diff-style review comparing it with yours. If it doesn't, note that you just did what a BSP vendor does.

**Exit checks**
```sh
$ bitbake core-image-minimal        # MACHINE = "opiz3", completes with no errors
$ bmaptool copy ...wic.bz2 /dev/sdX
# on target:
$ cat /etc/os-release               # Poky / scarthgap
$ uname -r                          # 6.6.x-yocto-standard
$ cat /proc/device-tree/model       # your custom model
```
- Buildroot `legal-info` output and Yocto `tmp/deploy/licenses/` reviewed in notes.

**Review questions**
- Buildroot vs Yocto: when would you pick each for an IoT product?
- Why does the bootloader need to be in `EXTRA_IMAGEDEPENDS` / `do_image_wic[depends]`?

---

### M6 — Developing with Yocto (Week 8) · Chapter 7

**Reading:** Chapter 7.

**Objectives**
- Layers and BSPs in practice, Wi-Fi/Bluetooth via BSP, `devtool` workflow (add, modify, upgrade, finish), package-based workflow and package feeds, extensible SDK, custom distro and image recipes.

**Labs**
1. Create a **custom distro** `opiz3-iot` (`conf/distro/opiz3-iot.conf`): systemd, `ipv6`, `wifi`, package management (ipk or rpm), `INIT_MANAGER = "systemd"`.
2. Create an image recipe `opiz3-iot-image` (start from `core-image-base`) with SSH, `libgpiod-tools`, `i2c-tools`, `iw`.
3. **Wi-Fi:** enable the USB dongle driver with a kernel config fragment, add the firmware package from `linux-firmware`, configure `wpa_supplicant` (or `iwd`) via a recipe that installs a config template + systemd unit.
4. `devtool` workflow: `devtool add` a small C or Rust app from a Git repo; `devtool modify` `linux-yocto` to add a DT change; `devtool deploy-target` to the board; `devtool finish` into your layers.
5. Package feed: serve `tmp/deploy/ipk` over HTTP from the build server, configure `opkg` on target, install a package without reflashing.
6. Extensible SDK: `bitbake opiz3-iot-image -c populate_sdk_ext`, install it, build an app outside BitBake.

**Exit checks**
- On target: `iw dev` shows the interface; `ping` works over Wi-Fi.
- `opkg install <pkg>` from your feed succeeds.
- Git history of `meta-opiz3-*` shows the `devtool finish` result (patches + bbappend).

---

### M7 — Yocto under the hood (Week 9) · Chapter 8

**Reading:** Chapter 8.

**Objectives**
- Build workflow (fetch → unpack → patch → configure → compile → install → package), metadata syntax, variable assignment/override rules, `bitbake-getvar`, `bitbake -e`, task logs in `tmp/work`, dependency graphs, `buildhistory`, sstate.

**Labs**
1. Instructor provides **five deliberately broken recipes** (wrong `SRC_URI` checksum, missing `DEPENDS`, wrong `FILES:${PN}`, override precedence bug, `do_install` path error). Trainee fixes each and writes a 3-line root-cause note.
2. Use `bitbake-getvar` / `bitbake -e` to trace where `IMAGE_INSTALL` gets each value.
3. Enable `buildhistory`, change one package, and diff image contents between builds.
4. `bitbake -g` + `oe-depends-dot` (or `task-depends.dot`) — explain why changing a kernel config rebuilds what it rebuilds.
5. Point builds to the shared sstate mirror; measure clean-build time before and after.

**Exit checks**
- All five broken recipes build; root-cause notes reviewed.
- Buildhistory diff committed to evidence.

---

### M8 — Creating a storage strategy (Week 10) · Chapter 9

**Reading:** Chapter 9.

**Objectives**
- Flash types (NOR, raw NAND, managed flash), MTD, filesystems (ext4, F2FS, UBIFS, SquashFS, tmpfs), read-only rootfs, wear considerations, partition layout.

**Labs**
1. Inspect the SD card with `mmc-utils`-style tooling and `/sys/block/mmcblk0/`; discuss SD card endurance for IoT (a frequent field failure).
2. **SPI NOR:** enable MTD + SPI NOR in kernel and DT, inspect `/proc/mtd`, `mtdinfo`; create a UBI volume and mount **UBIFS** on the 16 MB NOR; write a JFFS2 image for comparison.
3. **Read-only rootfs** in Yocto: `IMAGE_FEATURES += "read-only-rootfs"`, separate ext4 **data** partition in the `.wks`, `/var/log` to tmpfs or the data partition, overlayfs for `/etc` if needed.
4. Optional: put U-Boot in SPI NOR and boot the rootfs from SD (makes the SD card hot-swappable for the rest of the course).

**Exit checks**
```sh
$ touch /usr/test        # fails: Read-only file system
$ mount | grep data      # data partition rw
$ cat /proc/mtd          # NOR partitions listed
$ mount | grep ubifs     # UBIFS mounted
```

---

### M9 — Updating software in the field (Week 11) · Chapter 10

**Reading:** Chapter 10.

**Objectives**
- What to update, update strategies (symmetric A/B, asymmetric/recovery, atomic file updates), OTA architectures, Mender (local and OTA), balena, rollback and boot counting.

**Labs**
1. Book path: Mender on QEMU with Yocto (`meta-mender`, Scarthgap), local update with `mender-update install`.
2. OPiZ3 port: integrate `meta-mender-core` into your image: U-Boot integration (boot counting, `bootlimit`, environment redundancy), A/B rootfs + data partition in the image. Expect U-Boot integration work — this is the real-world part.
3. Perform an OTA update from a Mender server (hosted trial or self-hosted open source server on the lab network) to a new image that changes `/etc/issue`.
4. **Rollback test:** deploy an image whose application service fails its health check (or kernel that panics); verify automatic rollback.
5. balena: read and discuss (OPiZ3 is not a balenaOS device type). If a Raspberry Pi 4 is available, run the book's exercise on it.
6. Short comparison note: Mender vs RAUC vs SWUpdate for the company's IoT products.

**Exit checks**
- Evidence log of a successful A→B update and of an automatic B→A rollback (`fw_printenv` showing partition/boot count changes).

---

### M10 — Device drivers & add-on boards (Week 12) · Chapters 11 & 12

**Reading:** Chapters 11 and 12 (apply errata pp. 359–360: module renamed `dummy-char`).

**Objectives**
- Character/block/network devices, `/dev`, sysfs, finding drivers at runtime, user-space drivers (GPIO via `libgpiod`, LEDs, I2C via `i2c-dev`, SPI via `spidev`), writing and loading a kernel module, DT binding a driver.
- Reading schematics/pinouts, wiring add-on peripherals, DT overlays, writing test programs.

**Labs**
1. Get the OPiZ3 schematic and 26-pin header pinout. Produce a pin map for I2C3, SPI1, UART5 and free GPIOs in your notes.
2. **GPIO:** `gpiodetect`, `gpioinfo`, `gpioset`/`gpiomon` with LED + button; then a C program using the libgpiod v2 API. (Zephyr engineers: compare with `gpio_pin_configure_dt`.)
3. **I2C:** wire the BME280, `i2cdetect -y <bus>`; read chip ID from user space. Then switch to the **kernel IIO driver** (`bmp280` driver supports BME280) through a DT node and read `/sys/bus/iio/devices/iio:device0/in_temp_input`. Discuss user-space vs kernel driver trade-offs.
4. **SPI:** enable `spidev` (or the proper driver) via DT, talk to the SPI device with a C test program.
5. **UART add-on:** GNSS module on UART5, read NMEA sentences (`cat /dev/ttyS5` or `gpsd`) — mirrors the book's add-on example.
6. **Kernel module:** build the book's `dummy-char` module out-of-tree via a Yocto recipe in `meta-opiz3-apps` (`inherit module`), autoload it, `echo hello > /dev/dummy0`.
7. **DT overlays:** turn the sensor/SPI/UART enablement into overlays (`.dtso`) applied by U-Boot (`fdt apply`) and packaged by Yocto.

**Exit checks**
- LED toggles from your C program; button event printed.
- IIO temperature reading in m°C plausible for the room.
- `modprobe dummy-char && lsmod | grep dummy` and `dmesg` output.
- Overlay toggled on/off without rebuilding the base DTB.

---

### M11 — init & power management (Week 13) · Chapters 13 & 14

**Reading:** Chapters 13 and 14.

**Objectives**
- BusyBox init, System V init, systemd (units, targets, dependencies, `systemd-analyze`); power: CPU frequency scaling, CPU idle states, device runtime PM, system sleep states.

**Labs — init**
1. Build three image variants on OPiZ3: BusyBox init (Buildroot), SysV (Yocto), systemd (Yocto, your distro). Compare boot time (`systemd-analyze`, serial timestamps with `grabserial` or `picocom` timestamps).
2. Write a systemd service for a sensor-reading daemon with `Restart=on-failure`, `WatchdogSec=` (`sd_notify`), dependencies on `network-online.target`.
3. Enable the hardware watchdog (`/dev/watchdog`, `RuntimeWatchdogSec=` in systemd) and prove that a hung system reboots.

**Labs — power**
1. Inspect `/sys/devices/system/cpu/cpu*/cpufreq` and `cpuidle`. **If cpufreq is absent on 6.6 for the H618**, find in the kernel Git history when H616/H618 cpufreq/OPP support landed — a real "read the kernel log" exercise — and document it.
2. Measure idle vs `stress-ng` load current with the USB power meter; repeat with CPUs offlined (`echo 0 > /sys/devices/system/cpu/cpu3/online`).
3. Try `s2idle` (`echo freeze > /sys/power/state`) with a wakeup source; document what works and what doesn't on this SoC with mainline.
4. Runtime PM: inspect `/sys/devices/.../power/runtime_status` for USB and MMC.

**Exit checks**
- `systemd-analyze blame` output + boot-time comparison table.
- Watchdog reboot captured on serial.
- Power table (idle / load / CPUs offlined) in notes.

---

### M12 — Python & containers (Week 14) · Chapters 15 & 16

**Reading:** Chapters 15 and 16 (errata p.452: install `docker-ce` on the host, not `docker.io`).

**Objectives**
- Python packaging: pip, venv, `pyproject.toml`, conda vs pip, packaging Python for embedded targets with Yocto. Containers: Docker on the edge, building multi-arch images, deploying and updating containers.

**Labs — Python**
1. Write a small Python package `opiz3-sensor` (reads the BME280 via IIO sysfs, publishes MQTT with `paho-mqtt`), with `pyproject.toml`.
2. Write its Yocto recipe (`inherit python_setuptools_build_meta` or `python_hatchling` depending on backend) and runtime dependencies from `meta-python`.
3. Compare image sizes: Python app via recipes vs `pip install` on target vs a container.

**Labs — containers**
1. Add `meta-virtualization` and Docker to a variant of your image (`DISTRO_FEATURES += "virtualization"`).
2. Build an **arm64** container on the host with `docker buildx`, push to a local registry, pull and run it on the OPiZ3.
3. Run Mosquitto in a container and your Python app on the host OS (or vice versa); persist data on the data partition from M8.
4. Discuss: containers vs Yocto packages vs Mender application updates — when does each make sense for an IoT fleet?

**Exit checks**
- `mosquitto_sub` on the host receives sensor readings from the board.
- `docker ps` on target shows the container; it restarts after a reboot.

---

### M13 — Processes, threads & memory (Week 15) · Chapters 17 & 18

**Reading:** Chapters 17 and 18.

**Objectives**
- Processes vs threads, `fork`/`exec`, daemons, IPC (pipes, message queues, shared memory, sockets), pthreads, mutexes/condvars, scheduling policies and CPU affinity.
- Virtual memory, kernel vs user memory, `/proc/meminfo`, `/proc/<pid>/smaps`, `smem`, `mmap`, memory leaks (`mtrace`, Valgrind), the OOM killer.

**Labs**
1. Port a Zephyr producer/consumer (threads + `k_msgq`) to: (a) pthreads + condvar, (b) two processes + POSIX message queue. Compare.
2. Pin threads with `pthread_setaffinity_np`; observe with `htop`/`ps -eLo pid,tid,psr,cls,rtprio,comm`.
3. Use `SCHED_FIFO` for one thread; measure jitter (prepares M15).
4. Memory: run the book's examples, measure PSS/USS with `smem`; find an injected leak with Valgrind on target (add `valgrind` to the image).
5. Trigger the OOM killer with a cgroup memory limit (systemd `MemoryMax=`) and read the kernel log.

**Exit checks**
- Both IPC versions working; written comparison.
- Valgrind report pinpointing the leak's file:line.
- OOM kill message captured in `journalctl -k`.

---

### M14 — Debugging, profiling & tracing (Week 16) · Chapters 19 & 20

**Reading:** Chapters 19 and 20.

**Objectives**
- GDB: remote debugging with `gdbserver`, debug symbols in Yocto (`dbg-pkgs`, `IMAGE_GEN_DEBUGFS`), core dumps, GDB in IDEs, kernel debugging (kgdb).
- Profiling and tracing: `top`, `perf` (record, report, flame graphs), ftrace (`trace-cmd`, KernelShark), LTTng, eBPF (BCC, bpftrace, ply), Valgrind (Callgrind, Helgrind), `strace`.

**Labs**
1. Remote debug your sensor daemon from the Yocto SDK GDB through `gdbserver` on target; set breakpoints, inspect variables.
2. Make the daemon crash; collect a core dump (`systemd-coredump`) and analyze it on the host with matching symbols.
3. kgdb over the serial console: break into the kernel, inspect `dummy-char` state.
4. `perf record -g` on a CPU-heavy workload; generate a flame graph on the host.
5. ftrace: trace I2C transactions while reading the BME280 (`trace-cmd record -e i2c`); view in KernelShark.
6. eBPF: enable BPF in the kernel config, add `bpftrace`/`bcc` to the image, count syscalls per process; trace `openat` of your daemon.
7. LTTng: instrument the daemon with a tracepoint and correlate with kernel events.

**Exit checks**
- GDB session transcript with breakpoint hit.
- Flame graph SVG in evidence.
- `bpftrace` one-liner output showing your daemon's syscalls.

---

### M15 — Real-time programming (Week 17) · Chapter 21

**Reading:** Chapter 21.

**Objectives**
- What real-time means, sources of non-determinism, kernel preemption models, PREEMPT_RT, threaded interrupts, high-resolution timers, avoiding page faults (`mlockall`), measuring latency, interrupt shielding.

**Labs**
1. Build two images: `linux-yocto` 6.6 (standard) and `linux-yocto-rt` 6.6 (`PREFERRED_PROVIDER_virtual/kernel = "linux-yocto-rt"`) for `opiz3`.
2. Run `cyclictest -m -S -p 90 -i 1000 -l 1000000` on both, idle and under `stress-ng` + network load; produce latency histograms.
3. Isolate a CPU (`isolcpus=3`, IRQ affinity) and pin the RT task; repeat the measurement.
4. Write an RT application toggling a GPIO at 1 kHz using `clock_nanosleep` with `SCHED_FIFO` and `mlockall`; measure jitter with the logic analyzer. Compare against the same task on a Zephyr board (the trainees know how to make this comparison meaningful — encourage it).

**Exit checks**
- Latency table (max/avg) for: standard idle, standard load, RT idle, RT load, RT load + isolated CPU.
- Logic analyzer capture of the 1 kHz GPIO with measured jitter.

**Review question**
- For an IoT product needing <100 µs response, when do you use PREEMPT_RT and when do you put a Zephyr MCU next to the Linux SoC?

---

### Capstone — IoT gateway on Orange Pi Zero 3 (Week 18)

Build, from your own layers, a production-style IoT gateway image. Requirements:

| Area | Requirement | Chapters |
|---|---|---|
| Build | Reproducible kas/manifest build, Scarthgap, `MACHINE = "opiz3"`, `DISTRO = "opiz3-iot"` | 6–8 |
| Boot | Own TF-A + U-Boot + `linux-yocto` 6.6 + custom DTS/overlays | 3, 4 |
| Storage | Read-only rootfs, A/B partitions, persistent data partition | 9 |
| Updates | Mender OTA with automatic rollback, demonstrated live | 10 |
| Hardware | BME280 via kernel IIO driver + one more peripheral (SPI or UART) | 11, 12 |
| Application | Python or C daemon publishing MQTT; systemd unit with watchdog | 13, 15 |
| Containers | Optional: broker or a second service as a container | 16 |
| Robustness | Hardware watchdog, journald limits, no leaks under Valgrind | 13, 18 |
| Observability | Debug image variant with gdbserver, perf, bpftrace | 19, 20 |
| Security basics | No root password, SSH keys only, firewall rules, license manifest | 1, 7 |

**Demo (30 min):** flash from scratch → boot → data in MQTT → OTA update → induced failure → rollback → `bpftrace` live investigation of the daemon.

**Stretch goals:** SPI LoRa radio module driver/integration; secure boot discussion for sunxi; CI pipeline that builds the image and runs `oeqa` tests on a board in the lab.

---

## 7. Validation framework

### 7.1 Three levels of validation

1. **Exit checks** (per lab, listed above): exact commands + expected output. Trainee stores output under `evidence/`.
2. **Automated on-target tests** (from M6 onward): Yocto's `oeqa` runtime tests against the real board over SSH:
   ```
   # local.conf
   IMAGE_CLASSES += "testimage"
   TEST_TARGET = "simpleremote"
   TEST_TARGET_IP = "192.168.x.y"
   TEST_SERVER_IP = "192.168.x.1"
   TEST_SUITES = "ping ssh date python opiz3_hw"
   ```
   Then `bitbake -c testimage opiz3-iot-image`. Trainees write their own test module `opiz3_hw.py` in `meta-opiz3-apps/lib/oeqa/runtime/cases/` that checks: device tree model, kernel version, I2C bus present, IIO device readable, LED class device present, systemd service active.
3. **Instructor review** (weekly): code review of layers (Yocto style: `oelint-adv` lint clean, no hardcoded paths, proper `LICENSE`/`LIC_FILES_CHKSUM`), notes, and review-question answers.

### 7.2 Example on-target check script (pre-Yocto modules)

```sh
#!/bin/sh
# labs/common/check-target.sh — run on the board, paste output to evidence/
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

grep -q "OrangePi Zero3" /proc/device-tree/model && pass "DT model" || fail "DT model"
uname -r | grep -q '^6\.6\.' && pass "kernel 6.6" || fail "kernel version"
[ "$(uname -m)" = "aarch64" ] && pass "aarch64" || fail "arch"
mount | grep -q ' / ' && pass "rootfs mounted" || fail "rootfs"
[ -e /dev/i2c-3 ] && pass "i2c-3 present" || echo "SKIP: i2c-3 (before M10)"
exit ${FAILED:-0}
```

### 7.3 Grading rubric (per module)

| Score | Meaning |
|---|---|
| 0 | Exit checks not passed |
| 1 | Exit checks passed with instructor help |
| 2 | Exit checks passed independently; notes complete |
| 3 | As 2, plus can explain *why* every step was needed (review questions answered well) and found/handled an issue on their own |

Target to graduate: ≥2 in every module, ≥3 in M5–M9 (Yocto + storage + OTA are the core of the company's IoT work), capstone demo passed.

---

## 8. Instructor notes & known pitfalls

- **Host must be x86-64** (book errata, p.15). Apple Silicon users need an x86-64 VM.
- **Apply all repo errata** before the relevant module (p.68, 159, 175, 185, 344, 359–360, 452). Most affect BeaglePlay steps, which trainees read but don't run; the `dummy-char` and Docker ones directly affect our labs.
- **Power supply problems masquerade as software bugs.** First question on any random crash: which PSU and cable?
- **Never power the board from the serial adapter's VCC.**
- **TF-A version:** H618 needs TF-A with H618-aware `sun50i_h616` platform support. If BL31 hangs right after SPL, check this first.
- **U-Boot version in Scarthgap:** if the Poky U-Boot recipe lacks `orangepi_zero3_defconfig` or misbehaves, add a `u-boot_2024.04.bb` in `meta-opiz3-bsp` (matches the book's version anyway).
- **Ethernet:** interface may be named `end0` (predictable names) rather than `eth0`. Write network configs accordingly.
- **SD card detect is broken by design** — reboot after swapping cards.
- **Wi-Fi:** on-board chip is not mainline — use the USB dongle path (see §2.4).
- **Yocto build times:** set up the shared `DL_DIR`/sstate mirror before Week 7 or the module schedule will slip.
- **Keep FEL recovery handy** (`sunxi-fel`): any trainee who bricks the SD boot chain is back in minutes.
- **Zephyr reflexes to unlearn:** polling registers from user space, assuming a single address space, assuming `printf` timing is deterministic, expecting the whole system to be one binary.

---

## Appendix A — Starting skeletons for `meta-opiz3-bsp`

These are deliberately incomplete starting points. Completing and debugging them **is** the M5 lab.

### A.1 `conf/machine/opiz3.conf`

```bitbake
#@TYPE: Machine
#@NAME: Orange Pi Zero 3 (Allwinner H618)
#@DESCRIPTION: Training BSP for Orange Pi Zero 3, mainline U-Boot + linux-yocto

require conf/machine/include/arm/armv8a/tune-cortexa53.inc

MACHINE_FEATURES = "ext2 vfat usbhost serial"

SERIAL_CONSOLES = "115200;ttyS0"

# Kernel
PREFERRED_PROVIDER_virtual/kernel ?= "linux-yocto"
PREFERRED_VERSION_linux-yocto ?= "6.6%"
KERNEL_IMAGETYPE = "Image"
KERNEL_DEVICETREE = "allwinner/sun50i-h618-orangepi-zero3.dtb"

# Bootloader chain
PREFERRED_PROVIDER_virtual/bootloader = "u-boot"
UBOOT_MACHINE = "orangepi_zero3_defconfig"
SPL_BINARY = "u-boot-sunxi-with-spl.bin"
EXTRA_IMAGEDEPENDS += "trusted-firmware-a u-boot"

# Image
IMAGE_FSTYPES += "wic.bz2 wic.bmap"
WKS_FILE = "opiz3-sdimage.wks"
IMAGE_BOOT_FILES = "${KERNEL_IMAGETYPE} sun50i-h618-orangepi-zero3.dtb boot.scr"
do_image_wic[depends] += "u-boot:do_deploy trusted-firmware-a:do_deploy"
```

### A.2 `recipes-bsp/trusted-firmware-a/trusted-firmware-a_%.bbappend`

```bitbake
COMPATIBLE_MACHINE:opiz3 = "opiz3"
TFA_PLATFORM:opiz3 = "sun50i_h616"
TFA_BUILD_TARGET:opiz3 = "bl31"
TFA_INSTALL_TARGET:opiz3 = "bl31"
TFA_DEBUG:opiz3 = "0"
```

### A.3 `recipes-bsp/u-boot/u-boot_%.bbappend`

```bitbake
DEPENDS:append:opiz3 = " trusted-firmware-a"
do_compile[depends] += "trusted-firmware-a:do_deploy"
EXTRA_OEMAKE:append:opiz3 = " BL31=${DEPLOY_DIR_IMAGE}/bl31.bin SCP=/dev/null"

# boot.scr from boot.cmd (written in M2)
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:opiz3 = " file://boot.cmd"
DEPENDS:append:opiz3 = " u-boot-mkimage-native"
do_compile:append:opiz3() {
    uboot-mkimage -A arm64 -O linux -T script -C none -d ${WORKDIR}/boot.cmd ${WORKDIR}/boot.scr
}
do_deploy:append:opiz3() {
    install -m 0644 ${WORKDIR}/boot.scr ${DEPLOYDIR}/boot.scr
}
```

### A.4 `recipes-kernel/linux/linux-yocto_6.6.bbappend`

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
COMPATIBLE_MACHINE:opiz3 = "opiz3"
KMACHINE:opiz3 = "opiz3"
KBUILD_DEFCONFIG:opiz3 = "defconfig"
KCONFIG_MODE:opiz3 = "alldefconfig"
SRC_URI:append:opiz3 = " file://opiz3-training.cfg"
# M4/M10: add your custom DTS and overlays here as patches or via KERNEL_DEVICETREE
```

### A.5 `wic/opiz3-sdimage.wks`

```
# SPL+U-Boot at 8 KiB, read by the H618 Boot ROM
part u-boot --source rawcopy --sourceparams="file=u-boot-sunxi-with-spl.bin" --no-table --align 8
part /boot --source bootimg-partition --fstype=vfat --label boot --active --align 4096 --size 64M
part /     --source rootfs --fstype=ext4 --label root --align 4096
```

(In M8/M9 this grows into: boot, rootfs A, rootfs B, data.)

---

## Appendix B — References

- Book: *Mastering Embedded Linux Development*, 4th ed., Vasquez & Simmonds, Packt 2025.
- Book code & errata: https://github.com/PacktPublishing/Mastering-Embedded-Linux-Development
- linux-sunxi wiki, Orange Pi Zero3: https://linux-sunxi.org/Xunlong_Orange_Pi_Zero3
- linux-sunxi mainlining status: https://linux-sunxi.org/Linux_mainlining_effort
- Yocto Project documentation (Scarthgap 5.0): https://docs.yoctoproject.org/5.0/
- Buildroot manual: https://buildroot.org/downloads/manual/manual.html
- U-Boot sunxi documentation: https://docs.u-boot.org/en/latest/board/allwinner/sunxi.html
- TF-A Allwinner platform docs: https://trustedfirmware-a.readthedocs.io/en/latest/plat/allwinner.html
- meta-sunxi: https://github.com/linux-sunxi/meta-sunxi
- meta-mender: https://github.com/mendersoftware/meta-mender
- kas: https://kas.readthedocs.io/
