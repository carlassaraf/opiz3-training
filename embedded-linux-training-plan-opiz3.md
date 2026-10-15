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
6. **One build host, reached over the network.** All compiling (toolchain labs, U-Boot, kernel, BusyBox, Buildroot, Yocto) happens in the **`elt` VM** (Ubuntu 24.04 arm64, the book's host OS) on the Mac mini M4. The MacBook only connects to it over SSH. Board-facing USB tasks (serial console, SD card reader, FEL) are attached to the Mac mini and also used over SSH. See §2.5.

### 1.2 Duration and cadence

| Mode | Duration | Notes |
|---|---|---|
| Recommended: 50% allocation (~20 h/week) | **18 weeks** | Leaves room for real project work |
| Full-time | ~9 weeks | Fine on the Mac mini VM once sstate is warm |

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
│   ├── meta-opiz3-bsp/    # machine, bootloader, kernel, wks (from Module 5)
│   └── meta-opiz3-apps/   # distro, images, apps, drivers (from Module 5)
├── kas/                   # reproducible Yocto setup (kas files)
└── host/                  # lima-elt.yaml + bootstrap-vm.sh (build host setup, §2.5)
```

---

## 2. Lab setup

### 2.1 Host machines

This edition runs on one person's home setup. All building happens on a **Mac mini M4** that acts as a headless build server; the daily-driver **MacBook** is only a thin client that connects over the network.

| Machine | Role | Resources used |
|---|---|---|
| **Mac mini M4** (16 GB RAM, 256 GB internal) | Always-on host. Runs the **`elt` Ubuntu 24.04 VM** (Lima, Apple Virtualization, native arm64). The Orange Pi's serial adapter, an SD card reader and the FEL cable plug into it. | VM: 8 of 10 cores, 10 GB RAM (+8 GB swap inside the VM). macOS keeps ~6 GB. |
| **External SSD, 1 TB** (on the Mac mini) | Shared drive: a 400 GB APFS partition `ELT-SSD` holds the VM disk (sparse, 350 GiB ceiling) and Lima's state; a 600 GB exFAT partition `KINGSTON` keeps personal files. The 256 GB internal disk is left alone. | Expect ~100–250 GB in real use (see §2.5.7). |
| **MacBook Pro M3 Pro** (daily driver) | Editor and terminal only: SSH / VS Code Remote-SSH into the VM, serial console through the Mac mini. Nothing is built on it. | Negligible |
| Orange Pi Zero 3 (4 GB) | Target, on the home LAN via Ethernet | — |

Everything sits on the same home LAN. The VM is **bridged** onto that LAN with its own IP, so the Orange Pi can reach it directly (TFTP, NFS root, package feeds, Mender server) and the MacBook can SSH straight into it.

### 2.2 Hardware kit

| Item | Purpose |
|---|---|
| Orange Pi Zero 3, 4 GB | Target |
| 5 V / 3 A USB-C power supply | Stable power (undervoltage causes "random" crashes) |
| 3.3 V USB-to-TTL serial adapter (FTDI/CP2102) | Debug UART (UART0, 115200 8N1), plugged into the Mac mini — **mandatory** |
| 2× microSD 16–32 GB (A1, good brand) + USB reader | One "known good", one for experiments; reader stays plugged into the Mac mini |
| Ethernet cable + lab switch | Primary network (onboard Gigabit, Motorcomm YT8531 PHY) |
| USB-A ↔ USB-C data cable | Orange Pi OTG → Mac mini, for FEL recovery |
| Wi-Fi smart plug with a local HTTP API (Shelly / Tasmota) — optional | Power-cycle the board remotely from the MacBook |
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

### 2.5 Build host: Mac mini M4 + `elt` VM, driven from the MacBook

#### 2.5.1 Topology

```
 MacBook Pro (daily driver)                      Home LAN (Ethernet / Wi-Fi)
 ├─ ssh elt / VS Code Remote-SSH ───────────────────────────┐
 └─ ssh macmini (serial, SD writer, power) ──────────┐      │
                                                     │      │
 Mac mini M4 (macOS, headless) ◄─────────────────────┘      │
 ├─ USB: serial adapter ── Orange Pi UART0                  │
 ├─ USB: SD card reader                                     │
 ├─ USB: OTG cable ─────── Orange Pi (FEL, last resort)     │
 └─ External SSD 1 TB (ELT-SSD APFS 400 GB)                 │
     └─ Lima VM "elt" (Ubuntu 24.04 arm64, bridged) ◄───────┘
         builds · TFTP · NFS root · package feed · Mender server
                         ▲
 Orange Pi Zero 3 ── Ethernet (LAN) ──┘
```

| Task | Runs on | Reached from the MacBook by |
|---|---|---|
| All builds: toolchain labs, TF-A, U-Boot, kernel, BusyBox, Buildroot, Yocto/kas/devtool/SDK | `elt` VM | `ssh elt`, VS Code Remote-SSH |
| `runqemu` (QEMU labs) | `elt` VM (`nographic slirp`) | `ssh elt` |
| TFTP, NFS root, package feed (HTTP), Mender server, MQTT broker | `elt` VM (LAN IP) | the Orange Pi reaches them directly |
| Serial console (logged) | Mac mini macOS (`tio` in `tmux`) | `ssh -t macmini tmux attach -t serial` |
| Writing SD cards (first boot, recovery) | Mac mini macOS (SD reader) | `ssh macmini` + `dd` |
| Re-flashing SD cards (normal case) | The Orange Pi itself, net-booted from the VM | serial console (§2.5.5) |
| FEL recovery (`sunxi-fel`) | Mac mini macOS | `ssh macmini` |
| `testimage`, `devtool deploy-target`, `scp` to the board | `elt` VM → board over the LAN | `ssh elt` |

#### 2.5.2 Mac mini (macOS) one-time setup

1. **Server behaviour**
   - System Settings → General → Sharing → **Remote Login** on.
   - Never sleep, restart after power loss: `sudo pmset -a sleep 0 disksleep 0 autorestart 1` (display sleep is fine).
   - If FileVault is on, a reboot waits for the password at the physical console. For planned reboots use `sudo fdesetup authrestart`.
2. **External SSD**: Lima needs an APFS volume (exFAT has no Unix sockets, sparse files or clones), named `ELT-SSD`; case-sensitivity doesn't matter, since the VM's ext4 filesystem lives inside a disk-image file. This edition shares the 1 TB drive with personal files:
   ```sh
   sudo diskutil partitionDisk disk4 GPT APFS ELT-SSD 400g ExFAT KINGSTON R   # ERASES the whole drive
   ```
   **Back up the drive and verify the copy before running this.** macOS can't shrink an exFAT partition, so there is no non-destructive path. If the drive is already APFS, add a volume to its container instead (`sudo diskutil apfs addVolume diskN APFS ELT-SSD -reserve 300g`), which keeps existing files. Keep `disk:` in `host/lima-elt.yaml` below the volume size. Exclude `ELT-SSD` from indexing and backups: `sudo mdutil -i off /Volumes/ELT-SSD` and add it to Time Machine's exclusions. The drive must stay plugged into the Mac mini; stop the VM (`limactl stop elt`) before ever ejecting it.
3. **Tools**: `brew install lima tio tmux socat`. Build `sunxi-tools` for FEL: `brew install libusb pkg-config dtc`, clone `linux-sunxi/sunxi-tools`, `make tools`, put `sunxi-fel` on the `PATH`.
4. **Bridged networking for Lima**: install `socket_vmnet` from source as root into `/opt/socket_vmnet` (Lima's docs advise against the Homebrew build), then install Lima's sudoers file: `limactl sudoers > /tmp/lima && sudo install -o root /tmp/lima /etc/sudoers.d/lima`. In `$LIMA_HOME/_config/networks.yaml`, set the `bridged` network's `interface` to the Mac mini's LAN interface (`en0` for Ethernet).
5. **Shell environment, including for remote commands**: `ssh macmini <cmd>` runs a non-login, non-interactive zsh that reads only `~/.zshenv`, not `~/.zprofile` or `~/.zshrc`. Homebrew's PATH and the Lima state location therefore go in `~/.zshenv`. Without this, `ssh -t macmini tmux attach …` fails with `command not found: tmux`, and `ssh macmini 'limactl …'` uses the wrong `LIMA_HOME`:
   ```sh
   cat >> ~/.zshenv <<'EOF'
   eval "$(/opt/homebrew/bin/brew shellenv)"
   export LIMA_HOME=/Volumes/ELT-SSD/lima
   EOF
   ```
   Check from the MacBook: `ssh macmini 'command -v tmux tio limactl; echo $LIMA_HOME'`.
6. **Create the VM** from `host/lima-elt.yaml` (shipped with this plan):
   ```sh
   limactl create --name=elt host/lima-elt.yaml
   limactl start elt
   limactl shell elt          # first login, from the Mac mini itself
   ```
   If `limactl` rejects `lima: bridged` with `vmType: vz` on your Lima version, change the YAML to `vmType: qemu` (HVF-accelerated, somewhat slower).
7. **Serial console as a persistent, logged session** (USB-serial adapter on the Mac mini):
   ```sh
   mkdir -p ~/serial
   tmux new -d -s serial "tio -b 115200 --log --log-file ~/serial/opiz3-\$(date +%F).log /dev/cu.usbserial-*"
   ```
   The log files are your evidence for exit checks; copy them into the repo's `evidence/`.
8. **Optional, recommended: remote power cycling.** Power the Orange Pi through a Wi-Fi smart plug with a local HTTP API (Shelly, or anything running Tasmota) so a hung board can be reset from the MacBook with one `curl`. Without it, a hung board means walking to the desk.

#### 2.5.3 `elt` VM setup

From the Mac mini, inside `limactl shell elt`:

```sh
git clone <your training repo> ~/el-training
~/el-training/host/bootstrap-vm.sh "$(cat <<'EOF'
ssh-ed25519 AAAA...your MacBook public key...
EOF
)"
```

`bootstrap-vm.sh` (shipped with this plan) installs:

- the Yocto Scarthgap host packages, plus Buildroot, kernel, U-Boot and TF-A build dependencies, the book's Chapter 2 package list (Autotools, CMake, `gperf`, …), filesystem-image tools for Chapters 5 and 9 (`genext2fs`, `mtd-utils`, `squashfs-tools`), QEMU, `kas`, and an mDNS responder (the VM answers as `lima-elt.local`). Docker (Chapter 16) is installed in M12;
- the **Arm GNU Toolchain 14.2.Rel1** (GCC 14.2), AArch64-hosted, in `/opt/toolchain`, with `CROSS_COMPILE=aarch64-none-linux-gnu-` and `ARCH=arm64` exported. The book's Bootlin toolchain only ships for x86-64 hosts, and Arm publishes no AArch64-hosted Linux-target build before 14.2. That makes it GCC 14 instead of the book's GCC 13.2; the concepts are the same, but expect some new GCC 14 warnings (some are now errors) when building older code;
- a **TFTP server** on `/srv/tftp` and an **NFS server** exporting `/srv/nfs/rootfs` to the LAN (M3/M4);
- `/work` for build trees and caches (`/work/cache/downloads`, `/work/cache/sstate`, `/work/build`), all on the VM's ext4 disk;
- your MacBook's SSH key.

The VM YAML also adds 8 GB of swap and sets `kernel.apparmor_restrict_unprivileged_userns = 0`. Ubuntu 24.04 blocks unprivileged user namespaces by default, and BitBake fails with "User namespaces are not usable by BitBake" without this setting. The book's Ubuntu 24.04 host needs the same fix.

Give the VM a **DHCP reservation** on your router (it keeps the same MAC address), so its IP stays fixed for U-Boot `serverip` and NFS `bootargs`.

#### 2.5.4 MacBook setup

`~/.ssh/config`:

```
Host macmini
    HostName mini.local             # <LocalHostName>.local (`scutil --get LocalHostName` on the mini), or its reserved IP
    User <your macOS user on the mini>

Host elt
    HostName lima-elt.local         # or the VM's reserved IP
    User <same username as on the mini; Lima reuses it>
    ForwardAgent yes                # use your GitHub key from inside the VM
    ServerAliveInterval 30
```

Daily use:

```sh
ssh elt                              # build shell (use tmux inside for long builds)
code --remote ssh-remote+elt /home/homemac.guest/el-training   # VS Code on the VM's files
ssh -t macmini tmux attach -t serial         # Orange Pi console; detach: Ctrl-b d
ssh macmini 'limactl start elt'              # after a Mac mini reboot
```

Run long builds inside `tmux` on the VM (`tmux new -A -s build`), so closing the MacBook lid doesn't kill a three-hour first build.

#### 2.5.5 Flashing without touching the board

The SD card only has to be moved by hand for the very first boots (M0, M2). After that:

1. **M2:** write your own U-Boot to the **16 MB SPI NOR** as well (`sf probe; sf update ...`). If the SD card's SPL is broken or missing, the Boot ROM falls back to SPI NOR, so you always reach a U-Boot prompt over serial.
2. **M3/M4:** add a `netboot` U-Boot environment that TFTPs `Image` + DTB from the VM and mounts the root filesystem over NFS from `/srv/nfs/rootfs`. Most kernel and rootfs iterations then don't touch the SD card at all.
3. **From M5 on, re-flash the SD card from the board itself.** `run netboot` (the root filesystem is on NFS, so the SD card is idle), then on the board:
   ```sh
   bmaptool copy http://lima-elt.local:8000/opiz3-iot-image-opiz3.rootfs.wic.bz2 /dev/mmcblk0
   reboot
   ```
   On the VM, serve the deploy directory with `python3 -m http.server 8000 -d /work/build/tmp/deploy/images/opiz3`. NFS-root image: any small Buildroot or Yocto image with `bmaptool`, extracted into `/srv/nfs/rootfs`.
4. **M6 onward:** `devtool deploy-target` and the opkg package feed push changes without re-flashing. **M9 onward:** Mender OTA becomes the normal update path.
5. **Last resort:** SD and SPI NOR both broken → the Boot ROM drops into FEL → `ssh macmini sunxi-fel -v uboot u-boot-sunxi-with-spl.bin`.

Writing a card in the Mac mini's reader, when needed:

```sh
scp elt:/work/build/tmp/deploy/images/opiz3/opiz3-iot-image-opiz3.rootfs.wic.bz2 macmini:/tmp/
ssh macmini
diskutil list external                       # find the card, e.g. /dev/disk5
diskutil unmountDisk /dev/disk5
bunzip2 -c /tmp/opiz3-iot-image-opiz3.rootfs.wic.bz2 | sudo dd of=/dev/rdisk5 bs=4m
diskutil eject /dev/disk5
```

#### 2.5.6 Host check (part of M0)

On the VM (`ssh elt`):

```sh
uname -m                                       # aarch64
grep PRETTY_NAME /etc/os-release               # Ubuntu 24.04.x LTS
${CROSS_COMPILE}gcc --version | head -1        # Arm GNU Toolchain 14.2.Rel1
kas --version                                  # kas 4.x
sysctl kernel.apparmor_restrict_unprivileged_userns   # = 0
free -h; swapon --show                         # ~10 GB RAM, 8 GB swap
df -h /work                                    # hundreds of GB free (sparse disk)
systemctl is-active tftpd-hpa nfs-kernel-server ssh   # active ×3
ip -4 addr show | grep 'inet '                 # an address on your home LAN
```

From the MacBook:

```sh
ssh elt true && ssh macmini 'ls /dev/cu.usbserial-*' && ping -c1 lima-elt.local
```

Save the output as `evidence/m0-host-check.log`.

#### 2.5.7 Keeping resources in check

| Item | Typical size | How to keep it small |
|---|---|---|
| Downloads (`/work/cache/downloads`) | 10–25 GB | Shallow Git clones are enabled in the kas file; shared by all builds |
| sstate (`/work/cache/sstate`) | 10–40 GB | Shared by all builds; prune occasionally with `sstate-cache-management.py` |
| One Yocto build (`/work/build/tmp`) | 20–50 GB with `rm_work` | Delete `tmp/` between modules; sstate rebuilds it in minutes |
| Buildroot output | 5–15 GB | `make clean` after M5/M11 |
| Kernel / U-Boot / TF-A trees (M2–M4) | ~5 GB | — |

- **Memory:** the kas file sets `BB_NUMBER_THREADS = "6"` and `PARALLEL_MAKE = "-j 8"` for 10 GB + 8 GB swap. If the OOM killer appears (`dmesg | grep -i oom` in the VM), lower `PARALLEL_MAKE` first. Big C++ recipes and links are the peaks.
- **Disk:** the VM disk is sparse, so it only grows as you fill it. Deleting files inside the VM doesn't necessarily shrink the image file; `sudo fstrim -av` in the VM can return space to the SSD if your Lima version passes discards through. Check with `du -h $LIMA_HOME/elt/diffdisk` on the Mac mini.
- **Expected speed:** a first `core-image-minimal` in roughly 1–2 hours on this VM; later rebuilds take minutes thanks to sstate. Keep the Mac mini plugged in and ventilated.
- **Snapshot before risky changes:** `limactl stop elt && cp -c $LIMA_HOME/elt/diffdisk /Volumes/ELT-SSD/backup-elt-diffdisk` (APFS clone, near-instant, no extra space until the files diverge).

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

Each module lists: **Reading**, **Objectives**, **Labs** (book exercise first, then the OPiZ3 port), **Exit checks** (what must be demonstrated), and **Review questions**. Reading, labs, exit checks and review questions are checklists: tick `- [x]` as you go and commit the plan with your evidence. A module is done when all its exit checks are ticked; then tick it below.

**Progress**
- [ ] M0 — Onboarding & board tour (Week 1) · Chapter 1
- [ ] M1 — Toolchains (Week 2) · Chapter 2
- [ ] M2 — Bootloaders (Week 3) · Chapter 3
- [ ] M3 — Configuring and building the kernel (Week 4) · Chapter 4
- [ ] M4 — Building a root filesystem (Week 5) · Chapter 5
- [ ] M5 — Selecting a build system (Weeks 6–7) · Chapter 6
- [ ] M6 — Developing with Yocto (Week 8) · Chapter 7
- [ ] M7 — Yocto under the hood (Week 9) · Chapter 8
- [ ] M8 — Creating a storage strategy (Week 10) · Chapter 9
- [ ] M9 — Updating software in the field (Week 11) · Chapter 10
- [ ] M10 — Device drivers & add-on boards (Week 12) · Chapters 11 & 12
- [ ] M11 — init & power management (Week 13) · Chapters 13 & 14
- [ ] M12 — Python & containers (Week 14) · Chapters 15 & 16
- [ ] M13 — Processes, threads & memory (Week 15) · Chapters 17 & 18
- [ ] M14 — Debugging, profiling & tracing (Week 16) · Chapters 19 & 20
- [ ] M15 — Real-time programming (Week 17) · Chapter 21
- [ ] Capstone — IoT gateway on Orange Pi Zero 3 (Week 18)

---

### M0 — Onboarding & board tour (Week 1) · Chapter 1

- [x] **Reading:** Chapter 1 + the repo README (errata).

**Objectives**
- Understand when (and when not) to choose Linux; the four elements: toolchain, bootloader, kernel, root filesystem.
- Understand GPL v2/v3, LGPL, permissive licenses and their product implications.
- Provision the Ubuntu 24.04 host as the book describes (here: the arm64 `elt` VM on the Mac mini).

**Labs**
- [x] 1. Provision the host: set up the Mac mini, the `elt` VM and the MacBook (§2.5.2–2.5.4). Chapter 1 has no host package list: the book installs packages chapter by chapter, starting with the full list in Chapter 2's *Technical requirements*. Search the book for every `apt install` / `apt-get install` run on the host and compare with `host/bootstrap-vm.sh`; every package must be either installed by the script or listed in `notes/m0-host-packages.md` with the reason it's not needed (e.g. crosstool-NG-only dependencies, or a renamed package). Pass the host check (§2.5.6).
- [x] 2. Wire the serial adapter (GND, TX, RX — **never** connect VCC). Plug the adapter into the Mac mini and start the logged `tio` session (§2.5.2, step 7); attach from the MacBook with `ssh -t macmini tmux attach -t serial`.
- [ ] 3. Flash the vendor Debian/Ubuntu image, boot it, and do a **board tour**: `cat /proc/cpuinfo`, `cat /proc/device-tree/model`, `lsblk`, `ip link`, `cat /proc/mtd` (if enabled), `dmesg | less`.
- [ ] 4. License audit: list the kernel version and bootloader of the vendor image and find where its sources are published. Write a one-page note on what the company would need to provide if it shipped that image in a product.

**Exit checks**
- [ ] Serial log in `evidence/m0-vendor-boot.log` showing the full boot from SPL to login prompt.
- [ ] `notes/m0-board-tour.md` with SoC, RAM, storage devices, network interfaces, kernel version.
- [ ] License note reviewed by the instructor.

**Review questions**
- [ ] What are the four elements of embedded Linux, and which one does the Boot ROM load?
- [ ] Why does GPLv3 matter for locked-down IoT devices?

---

### M1 — Toolchains (Week 2) · Chapter 2

- [ ] **Reading:** Chapter 2.

**Objectives**
- Toolchain anatomy: binutils, GCC, C library, kernel headers; tuple naming; sysroot.
- Static vs dynamic linking, shared library versioning, `pkg-config`, cross-compiling Make/Autotools/CMake projects.

**Labs**
- [ ] 1. Use the toolchain installed by `bootstrap-vm.sh` in `/opt/toolchain`: **Arm GNU Toolchain 14.2.Rel1** (GCC 14.2), AArch64-hosted (`aarch64-none-linux-gnu-`). The book uses the Bootlin aarch64 toolchain 2024.02-1 (GCC 13.2), which only ships for x86-64 hosts. Read the book's installation steps, reproduce them by hand with the Arm tarball in a scratch directory, and note in your M1 notes how the tuple and sysroot layout differ from Bootlin's (`aarch64-buildroot-linux-gnu-`).
- [ ] 2. Do every book exercise: `-v` / `-print-sysroot`, build the `Chapter02/library` example as static and shared library.
- [ ] 3. OPiZ3 port: cross-compile a `hello` and the library example, `scp` them to the vendor image, run them.
- [ ] 4. Cross-compile a real Autotools project and a CMake project (e.g. `libgpiod` and a small CMake app) using a CMake toolchain file you write yourself.
- [ ] 5. Break it on purpose: run a dynamically linked binary whose libc doesn't match the target. Capture and explain the error.

**Exit checks**
- [ ] The commands below give the expected output (saved under `evidence/`).

```sh
$ file hello
hello: ELF 64-bit LSB executable, ARM aarch64, ...
# on target:
$ ./hello            # prints expected output
$ ldd ./hello-dyn    # (or readelf -d) shows expected NEEDED libs
```
- [ ] CMake toolchain file committed to `labs/m01-toolchain/`.

**Review questions**
- [ ] What is the sysroot and why must it match the target's libraries?
- [ ] Why is glibc vs musl a product decision, not just a technical one?

---

### M2 — Bootloaders (Week 3) · Chapter 3

- [ ] **Reading:** Chapter 3.

**Objectives**
- Boot sequence phases; device tree basics (Zephyr engineers: compare!); U-Boot build, environment, commands, boot scripts, FIT images; porting U-Boot to a new board.

**Labs**
- [ ] 1. Book path: build U-Boot for QEMU and boot it.
- [ ] 2. Read the BeaglePlay sections and draw both boot chains (BeaglePlay vs OPiZ3) side by side in your notes.
- [ ] 3. OPiZ3 port — build your own boot chain:
  - [ ] Build **TF-A** BL31: `make CROSS_COMPILE=aarch64-none-linux-gnu- PLAT=sun50i_h616 DEBUG=0 bl31` (use a TF-A release with H618 support; verify on the linux-sunxi wiki).
  - [ ] Build **U-Boot v2024.04** (book version): `make orangepi_zero3_defconfig && make BL31=<path>/bl31.bin SCP=/dev/null CROSS_COMPILE=aarch64-none-linux-gnu-`.
  - [ ] Write `u-boot-sunxi-with-spl.bin` to the SD card at 8 KiB: copy it to the Mac mini and `sudo dd if=u-boot-sunxi-with-spl.bin of=/dev/rdiskN bs=1k seek=8` (§2.5.5). Then also write it to the SPI NOR from the U-Boot prompt, so you always have a fallback U-Boot.
- [ ] 4. FEL boot: put the board in FEL (no SD card), then `sunxi-fel -v uboot u-boot-sunxi-with-spl.bin`. This is your recovery path for the rest of the course.
- [ ] 5. U-Boot hands-on: `printenv`, `setenv`/`saveenv`, `mmc info`, `md`, `fdt` commands, `sf probe` on the SPI NOR, write a `boot.cmd` → `boot.scr` with `mkimage`.
- [ ] 6. Porting exercise (book's "nova" equivalent): create a custom board defconfig `opiz3_training_defconfig` that changes the prompt to `opiz3 => ` and sets a custom default environment.

**Exit checks**
- [ ] Serial log showing `U-Boot SPL 2024.04...`, `NOTICE: BL31: ...`, and the custom `opiz3 =>` prompt.
- [ ] FEL boot log.
- [ ] `boot.cmd` committed.

**Review questions**
- [ ] Why does the H618 need TF-A before U-Boot proper? What does BL31 provide to Linux (hint: PSCI)?
- [ ] What is the difference between the U-Boot DT and the kernel DT?

---

### M3 — Configuring and building the kernel (Week 4) · Chapter 4

- [ ] **Reading:** Chapter 4.

**Objectives**
- Choosing a kernel (mainline vs vendor vs LTS), Kconfig/Kbuild, building `Image`, modules and DTBs, booting, early-boot debugging, porting to a new board via DT.

**Labs**
- [ ] 1. Book path: build Linux 6.6 for QEMU AArch64 and boot it.
- [ ] 2. OPiZ3 port: clone mainline `v6.6.y` (stable), `make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- defconfig`, build `Image`, `modules`, `dtbs`. Confirm `arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dtb` exists.
- [ ] 3. Boot from U-Boot: load `Image` + DTB from the SD card FAT partition (`load mmc 0:1 ...`) and `booti`. Expect the "VFS: Unable to mount root fs" panic — that's success for this lab.
- [ ] 4. Boot over the network: TFTP `Image` + DTB from the `elt` VM (`/srv/tftp`), and save a `netboot` environment you'll keep using (§2.5.5).
- [ ] 5. Kernel config: use `menuconfig` to enable a feature, then produce a minimal **config fragment** (`.cfg`) — you'll reuse this format in Yocto.
- [ ] 6. DT exercise: create `sun50i-h618-orangepi-zero3-training.dts` that includes the upstream DTS, changes `model`, enables `i2c3` on the 26-pin header, and adds a `gpio-leds` node for an LED on a header GPIO. Boot it and check.

**Exit checks**
- [ ] The commands below give the expected output (saved under `evidence/`).

```sh
# kernel panic log captured, then later (after M4):
$ uname -r                    # 6.6.x
$ cat /proc/device-tree/model # your custom model string
$ ls /sys/class/leds/         # your LED appears
```

**Review questions**
- [ ] What happens between `booti` and `init`? Name the console-related bootargs and why `earlycon` helps.
- [ ] Why is mainline support for the H618 a business advantage over the vendor 6.1 BSP kernel?

---

### M4 — Building a root filesystem (Week 5) · Chapter 5

- [ ] **Reading:** Chapter 5 (apply errata for p.159: rebuild the kernel **without** built-in initramfs before NFS root).

**Objectives**
- Rootfs directory layout, BusyBox (vs ToyBox), libraries, device nodes, `proc`/`sysfs`, kernel modules, initramfs (standalone and built-in), init with `inittab`, user accounts, `devtmpfs`/`mdev`, network config, TFTP/NFS workflow.

**Labs**
- [ ] 1. Build the staging rootfs exactly as the book does (BusyBox, libs copied from the toolchain sysroot with the repo's `list-libs` helper).
- [ ] 2. QEMU boot with initramfs (book path).
- [ ] 3. OPiZ3: boot the same rootfs as initramfs, then from the SD card ext4 partition, then via **NFS root** from the `elt` VM (`/srv/nfs/rootfs`).
- [ ] 4. Add an `inittab`, user accounts, `mdev`, and static network config. Mount `proc`, `sys`, `devtmpfs`.
- [ ] 5. Install your kernel modules into the rootfs and load one with `modprobe`.

**Exit checks**
- [ ] Three boot logs: initramfs, SD rootfs, NFS rootfs.
- [ ] On NFS: create a file on the host's export, `cat` it on the target without rebooting.
- [ ] `ls -l /lib/modules/$(uname -r)` populated; `lsmod` shows a loaded module.

**Review questions**
- [ ] Why is building rootfs by hand a bad idea for products — and why did we do it anyway?
- [ ] What does `devtmpfs` give you that a static `/dev` doesn't?

---

### M5 — Selecting a build system (Weeks 6–7) · Chapter 6

- [ ] **Reading:** Chapter 6.

**Objectives**
- Build system concepts, package formats, Buildroot (configs, custom board, packages, licenses), Yocto intro (Poky, layers, BitBake, images, `MACHINE`), creating a BSP.

**Labs — Buildroot (Week 6)**
- [ ] 1. Buildroot 2024.02 LTS (book version): `make orangepi_zero3_defconfig && make`. Flash `output/images/sdcard.img`, boot.
- [ ] 2. Book "nova" equivalent: create `BR2_EXTERNAL` tree `br2-opiz3-training` with your own board directory, `post-image.sh`, genimage config, defconfig pointing to **your** custom U-Boot defconfig and DTS from M2/M3.
- [ ] 3. Add a custom package (your `hello` from M1) and generate the license manifest (`make legal-info`).

**Labs — Yocto (Week 7) — start of the Yocto spine**
- [ ] 1. Book path: build `core-image-minimal` for `qemuarm64` on Scarthgap and run it with `runqemu`.
- [ ] 2. Create the team layers with `bitbake-layers create-layer`: `meta-opiz3-bsp` and `meta-opiz3-apps`. Set up the build reproducibly with **kas** (or a repo manifest) pinned to Scarthgap: `poky`, `meta-openembedded`, `meta-arm` (for TF-A).
- [ ] 3. Write the **machine** `opiz3.conf` (see Appendix A for a starting skeleton):
  - [ ] TF-A from `meta-arm` (`TFA_PLATFORM = "sun50i_h616"`),
  - [ ] U-Boot with a `.bbappend` passing `BL31=` and `SCP=/dev/null`, using your training defconfig,
  - [ ] `linux-yocto` 6.6 with `defconfig` + your fragments and DTS,
  - [ ] a `.wks` file placing `u-boot-sunxi-with-spl.bin` at 8 KiB.
- [ ] 4. Before writing it, check whether the community `meta-sunxi` layer (Scarthgap branch) has an Orange Pi Zero 3 machine. If it does, build it too and write a diff-style review comparing it with yours. If it doesn't, note that you just did what a BSP vendor does.

**Exit checks**
- [ ] The commands below give the expected output (saved under `evidence/`).

```sh
$ bitbake core-image-minimal        # MACHINE = "opiz3", completes with no errors
$ bmaptool copy http://lima-elt.local:8000/...wic.bz2 /dev/mmcblk0   # on the net-booted board (§2.5.5)
# on target:
$ cat /etc/os-release               # Poky / scarthgap
$ uname -r                          # 6.6.x-yocto-standard
$ cat /proc/device-tree/model       # your custom model
```
- [ ] Buildroot `legal-info` output and Yocto `tmp/deploy/licenses/` reviewed in notes.

**Review questions**
- [ ] Buildroot vs Yocto: when would you pick each for an IoT product?
- [ ] Why does the bootloader need to be in `EXTRA_IMAGEDEPENDS` / `do_image_wic[depends]`?

---

### M6 — Developing with Yocto (Week 8) · Chapter 7

- [ ] **Reading:** Chapter 7.

**Objectives**
- Layers and BSPs in practice, Wi-Fi/Bluetooth via BSP, `devtool` workflow (add, modify, upgrade, finish), package-based workflow and package feeds, extensible SDK, custom distro and image recipes.

**Labs**
- [ ] 1. Create a **custom distro** `opiz3-iot` (`conf/distro/opiz3-iot.conf`): systemd, `ipv6`, `wifi`, package management (ipk or rpm), `INIT_MANAGER = "systemd"`.
- [ ] 2. Create an image recipe `opiz3-iot-image` (start from `core-image-base`) with SSH, `libgpiod-tools`, `i2c-tools`, `iw`.
- [ ] 3. **Wi-Fi:** enable the USB dongle driver with a kernel config fragment, add the firmware package from `linux-firmware`, configure `wpa_supplicant` (or `iwd`) via a recipe that installs a config template + systemd unit.
- [ ] 4. `devtool` workflow: `devtool add` a small C or Rust app from a Git repo; `devtool modify` `linux-yocto` to add a DT change; `devtool deploy-target` to the board; `devtool finish` into your layers.
- [ ] 5. Package feed: serve `tmp/deploy/ipk` over HTTP from the `elt` VM, configure `opkg` on target, install a package without reflashing.
- [ ] 6. Extensible SDK: `bitbake opiz3-iot-image -c populate_sdk_ext`, install it, build an app outside BitBake.

**Exit checks**
- [ ] On target: `iw dev` shows the interface; `ping` works over Wi-Fi.
- [ ] `opkg install <pkg>` from your feed succeeds.
- [ ] Git history of `meta-opiz3-*` shows the `devtool finish` result (patches + bbappend).

---

### M7 — Yocto under the hood (Week 9) · Chapter 8

- [ ] **Reading:** Chapter 8.

**Objectives**
- Build workflow (fetch → unpack → patch → configure → compile → install → package), metadata syntax, variable assignment/override rules, `bitbake-getvar`, `bitbake -e`, task logs in `tmp/work`, dependency graphs, `buildhistory`, sstate.

**Labs**
- [ ] 1. Instructor provides **five deliberately broken recipes** (wrong `SRC_URI` checksum, missing `DEPENDS`, wrong `FILES:${PN}`, override precedence bug, `do_install` path error). Trainee fixes each and writes a 3-line root-cause note.
- [ ] 2. Use `bitbake-getvar` / `bitbake -e` to trace where `IMAGE_INSTALL` gets each value.
- [ ] 3. Enable `buildhistory`, change one package, and diff image contents between builds.
- [ ] 4. `bitbake -g` + `oe-depends-dot` (or `task-depends.dot`) — explain why changing a kernel config rebuilds what it rebuilds.
- [ ] 5. Measure the sstate effect: time a build from an empty `tmp/` with the sstate cache present, then with an empty `SSTATE_DIR` pointed at a scratch directory (start that one before going to bed).

**Exit checks**
- [ ] All five broken recipes build; root-cause notes reviewed.
- [ ] Buildhistory diff committed to evidence.

---

### M8 — Creating a storage strategy (Week 10) · Chapter 9

- [ ] **Reading:** Chapter 9.

**Objectives**
- Flash types (NOR, raw NAND, managed flash), MTD, filesystems (ext4, F2FS, UBIFS, SquashFS, tmpfs), read-only rootfs, wear considerations, partition layout.

**Labs**
- [ ] 1. Inspect the SD card with `mmc-utils`-style tooling and `/sys/block/mmcblk0/`; discuss SD card endurance for IoT (a frequent field failure).
- [ ] 2. **SPI NOR:** enable MTD + SPI NOR in kernel and DT, inspect `/proc/mtd`, `mtdinfo`; create a UBI volume and mount **UBIFS** on the 16 MB NOR; write a JFFS2 image for comparison.
- [ ] 3. **Read-only rootfs** in Yocto: `IMAGE_FEATURES += "read-only-rootfs"`, separate ext4 **data** partition in the `.wks`, `/var/log` to tmpfs or the data partition, overlayfs for `/etc` if needed.
- [ ] 4. Optional: put U-Boot in SPI NOR and boot the rootfs from SD (makes the SD card hot-swappable for the rest of the course).

**Exit checks**
- [ ] The commands below give the expected output (saved under `evidence/`).

```sh
$ touch /usr/test        # fails: Read-only file system
$ mount | grep data      # data partition rw
$ cat /proc/mtd          # NOR partitions listed
$ mount | grep ubifs     # UBIFS mounted
```

---

### M9 — Updating software in the field (Week 11) · Chapter 10

- [ ] **Reading:** Chapter 10.

**Objectives**
- What to update, update strategies (symmetric A/B, asymmetric/recovery, atomic file updates), OTA architectures, Mender (local and OTA), balena, rollback and boot counting.

**Labs**
- [ ] 1. Book path: Mender on QEMU with Yocto (`meta-mender`, Scarthgap), local update with `mender-update install`.
- [ ] 2. OPiZ3 port: integrate `meta-mender-core` into your image: U-Boot integration (boot counting, `bootlimit`, environment redundancy), A/B rootfs + data partition in the image. Expect U-Boot integration work — this is the real-world part.
- [ ] 3. Perform an OTA update from a Mender server (hosted trial, or the open-source server self-hosted on the `elt` VM; it needs Docker there) to a new image that changes `/etc/issue`.
- [ ] 4. **Rollback test:** deploy an image whose application service fails its health check (or kernel that panics); verify automatic rollback.
- [ ] 5. balena: read and discuss (OPiZ3 is not a balenaOS device type). If a Raspberry Pi 4 is available, run the book's exercise on it.
- [ ] 6. Short comparison note: Mender vs RAUC vs SWUpdate for the company's IoT products.

**Exit checks**
- [ ] Evidence log of a successful A→B update and of an automatic B→A rollback (`fw_printenv` showing partition/boot count changes).

---

### M10 — Device drivers & add-on boards (Week 12) · Chapters 11 & 12

- [ ] **Reading:** Chapters 11 and 12 (apply errata pp. 359–360: module renamed `dummy-char`).

**Objectives**
- Character/block/network devices, `/dev`, sysfs, finding drivers at runtime, user-space drivers (GPIO via `libgpiod`, LEDs, I2C via `i2c-dev`, SPI via `spidev`), writing and loading a kernel module, DT binding a driver.
- Reading schematics/pinouts, wiring add-on peripherals, DT overlays, writing test programs.

**Labs**
- [ ] 1. Get the OPiZ3 schematic and 26-pin header pinout. Produce a pin map for I2C3, SPI1, UART5 and free GPIOs in your notes.
- [ ] 2. **GPIO:** `gpiodetect`, `gpioinfo`, `gpioset`/`gpiomon` with LED + button; then a C program using the libgpiod v2 API. (Zephyr engineers: compare with `gpio_pin_configure_dt`.)
- [ ] 3. **I2C:** wire the BME280, `i2cdetect -y <bus>`; read chip ID from user space. Then switch to the **kernel IIO driver** (`bmp280` driver supports BME280) through a DT node and read `/sys/bus/iio/devices/iio:device0/in_temp_input`. Discuss user-space vs kernel driver trade-offs.
- [ ] 4. **SPI:** enable `spidev` (or the proper driver) via DT, talk to the SPI device with a C test program.
- [ ] 5. **UART add-on:** GNSS module on UART5, read NMEA sentences (`cat /dev/ttyS5` or `gpsd`) — mirrors the book's add-on example.
- [ ] 6. **Kernel module:** build the book's `dummy-char` module out-of-tree via a Yocto recipe in `meta-opiz3-apps` (`inherit module`), autoload it, `echo hello > /dev/dummy0`.
- [ ] 7. **DT overlays:** turn the sensor/SPI/UART enablement into overlays (`.dtso`) applied by U-Boot (`fdt apply`) and packaged by Yocto.

**Exit checks**
- [ ] LED toggles from your C program; button event printed.
- [ ] IIO temperature reading in m°C plausible for the room.
- [ ] `modprobe dummy-char && lsmod | grep dummy` and `dmesg` output.
- [ ] Overlay toggled on/off without rebuilding the base DTB.

---

### M11 — init & power management (Week 13) · Chapters 13 & 14

- [ ] **Reading:** Chapters 13 and 14.

**Objectives**
- BusyBox init, System V init, systemd (units, targets, dependencies, `systemd-analyze`); power: CPU frequency scaling, CPU idle states, device runtime PM, system sleep states.

**Labs — init**
- [ ] 1. Build three image variants on OPiZ3: BusyBox init (Buildroot), SysV (Yocto), systemd (Yocto, your distro). Compare boot time (`systemd-analyze`, serial timestamps with `grabserial` or `picocom` timestamps).
- [ ] 2. Write a systemd service for a sensor-reading daemon with `Restart=on-failure`, `WatchdogSec=` (`sd_notify`), dependencies on `network-online.target`.
- [ ] 3. Enable the hardware watchdog (`/dev/watchdog`, `RuntimeWatchdogSec=` in systemd) and prove that a hung system reboots.

**Labs — power**
- [ ] 1. Inspect `/sys/devices/system/cpu/cpu*/cpufreq` and `cpuidle`. **If cpufreq is absent on 6.6 for the H618**, find in the kernel Git history when H616/H618 cpufreq/OPP support landed — a real "read the kernel log" exercise — and document it.
- [ ] 2. Measure idle vs `stress-ng` load current with the USB power meter; repeat with CPUs offlined (`echo 0 > /sys/devices/system/cpu/cpu3/online`).
- [ ] 3. Try `s2idle` (`echo freeze > /sys/power/state`) with a wakeup source; document what works and what doesn't on this SoC with mainline.
- [ ] 4. Runtime PM: inspect `/sys/devices/.../power/runtime_status` for USB and MMC.

**Exit checks**
- [ ] `systemd-analyze blame` output + boot-time comparison table.
- [ ] Watchdog reboot captured on serial.
- [ ] Power table (idle / load / CPUs offlined) in notes.

---

### M12 — Python & containers (Week 14) · Chapters 15 & 16

- [ ] **Reading:** Chapters 15 and 16 (errata p.452: install `docker-ce` on the host, not `docker.io`; here, install it in the `elt` VM if you didn't already for the Mender server in M9).

**Objectives**
- Python packaging: pip, venv, `pyproject.toml`, conda vs pip, packaging Python for embedded targets with Yocto. Containers: Docker on the edge, building multi-arch images, deploying and updating containers.

**Labs — Python**
- [ ] 1. Write a small Python package `opiz3-sensor` (reads the BME280 via IIO sysfs, publishes MQTT with `paho-mqtt`), with `pyproject.toml`.
- [ ] 2. Write its Yocto recipe (`inherit python_setuptools_build_meta` or `python_hatchling` depending on backend) and runtime dependencies from `meta-python`.
- [ ] 3. Compare image sizes: Python app via recipes vs `pip install` on target vs a container.

**Labs — containers**
- [ ] 1. Add `meta-virtualization` and Docker to a variant of your image (`DISTRO_FEATURES += "virtualization"`).
- [ ] 2. Build an **arm64** container on the host with `docker buildx`, push to a local registry, pull and run it on the OPiZ3.
- [ ] 3. Run Mosquitto in a container and your Python app on the host OS (or vice versa); persist data on the data partition from M8.
- [ ] 4. Discuss: containers vs Yocto packages vs Mender application updates — when does each make sense for an IoT fleet?

**Exit checks**
- [ ] `mosquitto_sub` on the host receives sensor readings from the board.
- [ ] `docker ps` on target shows the container; it restarts after a reboot.

---

### M13 — Processes, threads & memory (Week 15) · Chapters 17 & 18

- [ ] **Reading:** Chapters 17 and 18.

**Objectives**
- Processes vs threads, `fork`/`exec`, daemons, IPC (pipes, message queues, shared memory, sockets), pthreads, mutexes/condvars, scheduling policies and CPU affinity.
- Virtual memory, kernel vs user memory, `/proc/meminfo`, `/proc/<pid>/smaps`, `smem`, `mmap`, memory leaks (`mtrace`, Valgrind), the OOM killer.

**Labs**
- [ ] 1. Port a Zephyr producer/consumer (threads + `k_msgq`) to: (a) pthreads + condvar, (b) two processes + POSIX message queue. Compare.
- [ ] 2. Pin threads with `pthread_setaffinity_np`; observe with `htop`/`ps -eLo pid,tid,psr,cls,rtprio,comm`.
- [ ] 3. Use `SCHED_FIFO` for one thread; measure jitter (prepares M15).
- [ ] 4. Memory: run the book's examples, measure PSS/USS with `smem`; find an injected leak with Valgrind on target (add `valgrind` to the image).
- [ ] 5. Trigger the OOM killer with a cgroup memory limit (systemd `MemoryMax=`) and read the kernel log.

**Exit checks**
- [ ] Both IPC versions working; written comparison.
- [ ] Valgrind report pinpointing the leak's file:line.
- [ ] OOM kill message captured in `journalctl -k`.

---

### M14 — Debugging, profiling & tracing (Week 16) · Chapters 19 & 20

- [ ] **Reading:** Chapters 19 and 20.

**Objectives**
- GDB: remote debugging with `gdbserver`, debug symbols in Yocto (`dbg-pkgs`, `IMAGE_GEN_DEBUGFS`), core dumps, GDB in IDEs, kernel debugging (kgdb).
- Profiling and tracing: `top`, `perf` (record, report, flame graphs), ftrace (`trace-cmd`, KernelShark), LTTng, eBPF (BCC, bpftrace, ply), Valgrind (Callgrind, Helgrind), `strace`.

**Labs**
- [ ] 1. Remote debug your sensor daemon from the Yocto SDK GDB through `gdbserver` on target; set breakpoints, inspect variables.
- [ ] 2. Make the daemon crash; collect a core dump (`systemd-coredump`) and analyze it on the host with matching symbols.
- [ ] 3. kgdb over the serial console: break into the kernel, inspect `dummy-char` state.
- [ ] 4. `perf record -g` on a CPU-heavy workload; generate a flame graph on the host.
- [ ] 5. ftrace: trace I2C transactions while reading the BME280 (`trace-cmd record -e i2c`); view in KernelShark.
- [ ] 6. eBPF: enable BPF in the kernel config, add `bpftrace`/`bcc` to the image, count syscalls per process; trace `openat` of your daemon.
- [ ] 7. LTTng: instrument the daemon with a tracepoint and correlate with kernel events.

**Exit checks**
- [ ] GDB session transcript with breakpoint hit.
- [ ] Flame graph SVG in evidence.
- [ ] `bpftrace` one-liner output showing your daemon's syscalls.

---

### M15 — Real-time programming (Week 17) · Chapter 21

- [ ] **Reading:** Chapter 21.

**Objectives**
- What real-time means, sources of non-determinism, kernel preemption models, PREEMPT_RT, threaded interrupts, high-resolution timers, avoiding page faults (`mlockall`), measuring latency, interrupt shielding.

**Labs**
- [ ] 1. Build two images: `linux-yocto` 6.6 (standard) and `linux-yocto-rt` 6.6 (`PREFERRED_PROVIDER_virtual/kernel = "linux-yocto-rt"`) for `opiz3`.
- [ ] 2. Run `cyclictest -m -S -p 90 -i 1000 -l 1000000` on both, idle and under `stress-ng` + network load; produce latency histograms.
- [ ] 3. Isolate a CPU (`isolcpus=3`, IRQ affinity) and pin the RT task; repeat the measurement.
- [ ] 4. Write an RT application toggling a GPIO at 1 kHz using `clock_nanosleep` with `SCHED_FIFO` and `mlockall`; measure jitter with the logic analyzer. Compare against the same task on a Zephyr board (the trainees know how to make this comparison meaningful — encourage it).

**Exit checks**
- [ ] Latency table (max/avg) for: standard idle, standard load, RT idle, RT load, RT load + isolated CPU.
- [ ] Logic analyzer capture of the 1 kHz GPIO with measured jitter.

**Review question**
- [ ] For an IoT product needing <100 µs response, when do you use PREEMPT_RT and when do you put a Zephyr MCU next to the Linux SoC?

---

### Capstone — IoT gateway on Orange Pi Zero 3 (Week 18)

Build, from your own layers, a production-style IoT gateway image. Requirements:

- [ ] **Build:** Reproducible kas/manifest build, Scarthgap, `MACHINE = "opiz3"`, `DISTRO = "opiz3-iot"` (Ch. 6–8)
- [ ] **Boot:** Own TF-A + U-Boot + `linux-yocto` 6.6 + custom DTS/overlays (Ch. 3, 4)
- [ ] **Storage:** Read-only rootfs, A/B partitions, persistent data partition (Ch. 9)
- [ ] **Updates:** Mender OTA with automatic rollback, demonstrated live (Ch. 10)
- [ ] **Hardware:** BME280 via kernel IIO driver + one more peripheral (SPI or UART) (Ch. 11, 12)
- [ ] **Application:** Python or C daemon publishing MQTT; systemd unit with watchdog (Ch. 13, 15)
- [ ] **Containers:** Optional: broker or a second service as a container (Ch. 16)
- [ ] **Robustness:** Hardware watchdog, journald limits, no leaks under Valgrind (Ch. 13, 18)
- [ ] **Observability:** Debug image variant with gdbserver, perf, bpftrace (Ch. 19, 20)
- [ ] **Security basics:** No root password, SSH keys only, firewall rules, license manifest (Ch. 1, 7)

- [ ] **Demo (30 min):** flash from scratch → boot → data in MQTT → OTA update → induced failure → rollback → `bpftrace` live investigation of the daemon.

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

- **Build only in the `elt` VM** (§2.5). The book's errata (p.15) asks for an x86-64 Ubuntu host for verbatim steps; the VM is Ubuntu 24.04 on arm64, so the only verbatim difference is the M1 toolchain (Arm GNU instead of Bootlin).
- **Never build on macOS's own filesystem** (e.g. a folder shared into the VM). Case-insensitive APFS breaks the kernel and Yocto in confusing ways (`xt_mark.h` vs `xt_MARK.h`). Builds stay on the VM's ext4 disk.
- **OOM in the VM** is the most likely "random" Yocto failure with 10 GB of RAM. Lower `PARALLEL_MAKE`, then `BB_NUMBER_THREADS`, in `kas/opiz3.yml`.
- **"User namespaces are not usable by BitBake"** means the AppArmor sysctl from `lima-elt.yaml` didn't apply: `sudo sysctl kernel.apparmor_restrict_unprivileged_userns=0`.
- **Board can't reach the VM** (TFTP/NFS timeouts): the VM isn't bridged, or its IP changed. Check `ip -4 addr` in the VM and the router's DHCP reservation.
- **Apply all repo errata** before the relevant module (p.68, 159, 175, 185, 344, 359–360, 452). Most affect BeaglePlay steps, which trainees read but don't run; the `dummy-char` and Docker ones directly affect our labs.
- **Power supply problems masquerade as software bugs.** First question on any random crash: which PSU and cable?
- **Never power the board from the serial adapter's VCC.**
- **TF-A version:** H618 needs TF-A with H618-aware `sun50i_h616` platform support. If BL31 hangs right after SPL, check this first.
- **U-Boot version in Scarthgap:** if the Poky U-Boot recipe lacks `orangepi_zero3_defconfig` or misbehaves, add a `u-boot_2024.04.bb` in `meta-opiz3-bsp` (matches the book's version anyway).
- **Ethernet:** interface may be named `end0` (predictable names) rather than `eth0`. Write network configs accordingly.
- **SD card detect is broken by design** — reboot after swapping cards.
- **Wi-Fi:** on-board chip is not mainline — use the USB dongle path (see §2.4).
- **Yocto build times:** start the first full Yocto build (M5) overnight in `tmux` on the VM; everything after it reuses sstate.
- **Keep FEL recovery handy** (`sunxi-fel` on the Mac mini): a bricked SD *and* SPI NOR boot chain is back in minutes, without leaving the MacBook.
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
