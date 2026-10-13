#!/usr/bin/env bash
# bootstrap-vm.sh — turn the "elt" Ubuntu 24.04 VM into the course build host.
#
# Run once inside the VM (as the normal user, it uses sudo):
#   ./bootstrap-vm.sh "ssh-ed25519 AAAA... you@macbook"
# The argument is the MacBook's public key (cat ~/.ssh/id_ed25519.pub on the MacBook),
# so the MacBook can SSH straight to the VM's LAN IP.
#
# Safe to re-run.
set -euo pipefail

MACBOOK_PUBKEY="${1:-}"
KAS_VERSION="${KAS_VERSION:-4.7}"   # pin to the version you validated
TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-aarch64-aarch64-none-linux-gnu.tar.xz"
USER_NAME="$(id -un)"

echo "==> Host packages (Yocto Scarthgap + Buildroot + kernel/U-Boot/TF-A + lab services)"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential chrpath cpio debianutils diffstat file gawk gcc git \
  iputils-ping libacl1 lz4 locales python3 python3-git python3-jinja2 \
  python3-pexpect python3-pip python3-subunit socat texinfo unzip wget \
  xz-utils zstd \
  bc bison flex libssl-dev libncurses-dev libgnutls28-dev libelf-dev \
  device-tree-compiler u-boot-tools swig python3-dev python3-setuptools \
  python3-pyelftools python3-venv pipx rsync patch perl bzip2 \
  ca-certificates curl vim less tmux tree jq kmod htop \
  openssh-server avahi-daemon libnss-mdns \
  bmap-tools mtools dosfstools e2fsprogs parted \
  qemu-system-arm qemu-utils \
  tftpd-hpa nfs-kernel-server

echo "==> UTF-8 locale (BitBake requires it)"
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

echo "==> kas ${KAS_VERSION}"
pipx install --force "kas==${KAS_VERSION}"
pipx ensurepath

echo "==> AArch64 cross toolchain for M1-M4 (Arm GNU 13.2.Rel1, AArch64-hosted)"
# Bootlin's toolchain from the book ships for x86-64 hosts only.
if [ ! -x /opt/toolchain/bin/aarch64-none-linux-gnu-gcc ]; then
  sudo mkdir -p /opt/toolchain
  curl -fL "${TOOLCHAIN_URL}" -o /tmp/tc.tar.xz
  sudo tar -xf /tmp/tc.tar.xz -C /opt/toolchain --strip-components=1
  rm -f /tmp/tc.tar.xz
fi

echo "==> Work tree on the VM's ext4 disk"
sudo mkdir -p /work/cache/downloads /work/cache/sstate /work/build
sudo chown -R "${USER_NAME}:${USER_NAME}" /work

echo "==> Shell environment"
BASHRC_MARK="# >>> elt environment >>>"
if ! grep -q "${BASHRC_MARK}" ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
# >>> elt environment >>>
export PATH=/opt/toolchain/bin:$HOME/.local/bin:$PATH
export CROSS_COMPILE=aarch64-none-linux-gnu-
export ARCH=arm64
export KAS_WORK_DIR=/work
export DL_DIR=/work/cache/downloads
export BR2_DL_DIR=/work/cache/downloads/buildroot
# <<< elt environment <<<
EOF
fi

echo "==> TFTP server (M3/M4): serves /srv/tftp"
sudo mkdir -p /srv/tftp
sudo chown -R "${USER_NAME}:${USER_NAME}" /srv/tftp
sudo sed -i 's|^TFTP_DIRECTORY=.*|TFTP_DIRECTORY="/srv/tftp"|' /etc/default/tftpd-hpa
sudo systemctl enable --now tftpd-hpa
sudo systemctl restart tftpd-hpa

echo "==> NFS server (M4): exports /srv/nfs/rootfs to the home LAN"
sudo mkdir -p /srv/nfs/rootfs
LAN_CIDR="$(ip -4 -o route show scope link | awk '!/lima|docker/ {print $1; exit}')"
EXPORT_LINE="/srv/nfs/rootfs ${LAN_CIDR:-192.168.0.0/16}(rw,sync,no_subtree_check,no_root_squash)"
grep -qF "/srv/nfs/rootfs" /etc/exports || echo "${EXPORT_LINE}" | sudo tee -a /etc/exports >/dev/null
sudo exportfs -ra
sudo systemctl enable --now nfs-kernel-server

echo "==> SSH access from the MacBook"
if [ -n "${MACBOOK_PUBKEY}" ]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  grep -qF "${MACBOOK_PUBKEY}" ~/.ssh/authorized_keys 2>/dev/null || echo "${MACBOOK_PUBKEY}" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
fi
sudo systemctl enable --now ssh

echo
echo "Done. VM LAN address(es):"
ip -4 -o addr show scope global | awk '{print "  " $2 ": " $4}'
echo "Open a new shell (or 'source ~/.bashrc') and run the host check from plan §2.5.6."
