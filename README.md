# Embedded Linux training — Orange Pi Zero 3

Trainee repository for the [Embedded Linux Training Plan — Orange Pi Zero 3 Edition](embedded-linux-training-plan-opiz3.md),
based on *Mastering Embedded Linux Development*, 4th ed. (Vasquez & Simmonds, Packt 2025).

Clone it to `~/el-training` inside the `elt` VM (plan §2.5.3). All builds happen in the VM,
under `/work`, never in this repo.

## Layout (plan §1.3)

```
.
├── notes/          # chapter notes, answers to review questions (e.g. notes/m0-board-tour.md)
├── labs/
│   ├── common/     # check-target.sh and other shared helpers
│   ├── m00-onboarding/ … m15-realtime/
│   └── capstone/
├── evidence/       # serial logs, command outputs for exit checks (e.g. evidence/m0-host-check.log)
├── layers/         # meta-opiz3-bsp + meta-opiz3-apps, created in M5 with bitbake-layers
├── kas/            # opiz3.yml — reproducible Yocto (Scarthgap) setup
└── host/           # lima-elt.yaml + bootstrap-vm.sh — build host setup (plan §2.5)
```

| Lab directory | Module | Book chapters |
|---|---|---|
| `m00-onboarding` | M0 — Onboarding & board tour | 1 |
| `m01-toolchain` | M1 — Toolchains | 2 |
| `m02-bootloader` | M2 — Bootloaders | 3 |
| `m03-kernel` | M3 — Kernel | 4 |
| `m04-rootfs` | M4 — Root filesystem | 5 |
| `m05-build-systems` | M5 — Build systems | 6 |
| `m06-yocto-dev` | M6 — Developing with Yocto | 7 |
| `m07-yocto-internals` | M7 — Yocto under the hood | 8 |
| `m08-storage` | M8 — Storage | 9 |
| `m09-ota` | M9 — Updating software in the field | 10 |
| `m10-drivers` | M10 — Device drivers & add-on boards | 11, 12 |
| `m11-init-power` | M11 — init & power management | 13, 14 |
| `m12-python-containers` | M12 — Python & containers | 15, 16 |
| `m13-processes-memory` | M13 — Processes, threads & memory | 17, 18 |
| `m14-debug-tracing` | M14 — Debugging, profiling & tracing | 19, 20 |
| `m15-realtime` | M15 — Real-time programming | 21 |
| `capstone` | Capstone — IoT gateway | — |

## Quick start

On the Mac mini (plan §2.5.2):

```sh
limactl create --name=elt host/lima-elt.yaml && limactl start elt
```

Inside the VM (plan §2.5.3):

```sh
git clone <this repo> ~/el-training
~/el-training/host/bootstrap-vm.sh "ssh-ed25519 AAAA... you@macbook"
```

Yocto, from M5 on (once `layers/meta-opiz3-*` exist):

```sh
cd ~/el-training && kas build kas/opiz3.yml
```

## Conventions

- Every lab is done when its exit check passes and the output is committed under `evidence/`.
- Commit logs and checksums, not images or build output (see `.gitignore`).
- The book PDF stays local; `*.pdf` is ignored because it's copyrighted.
