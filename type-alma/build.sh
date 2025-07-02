#!/bin/bash
set -e

# Check if root
if [[ $EUID -ne 0 ]]; then
 echo "This script must be run as root"
 exit 1
fi

SCRIPT_DIR="$(
 cd "$(dirname "$0")" >/dev/null 2>&1
 pwd -P
)"

MNT_DIR="/mnt/alma/rootfs"

mkdir -p "$SCRIPT_DIR/temp"
RPATH="$SCRIPT_DIR/temp/rootfs.ext4"

usage() {
 echo "\
Usage: $0 [-t]
    -s don't generate a sparse file
"
}

SPARSE=1 # 1 if creating sparse file, 0 if not

while getopts "h?s" opt; do
 case "$opt" in
 h | \?)
  usage
  exit 0
  ;;
 s)
  echo "Disabled sparse file creation."
  SPARSE=0
  shift
  ;;
 esac
done

# Clean up old files
if [[ -f "$RPATH" ]]; then
 rm -rf "$RPATH"
fi

export SPARSE="$SPARSE"

"./init-rootfs.sh" "$RPATH"
"./run-container.sh" "$RPATH"


mkdir -p $MNT_DIR
mount -o loop $RPATH $MNT_DIR
rm "$MNT_DIR/etc/resolv.conf"
ln -s /proc/net/pnp "$MNT_DIR/etc/resolv.conf"
cp -v ../id_rsa.pub "$MNT_DIR/root/.ssh/authorized_keys"
mkdir -p "$MNT_DIR/usr/local/bin"
cp -v ../examiner "$MNT_DIR/usr/local/bin/examiner"
mkdir -p "$MNT_DIR/opt/synnefo-labs/examiner/checks.d"
cp -v ../opt/synnefo-labs/examiner/checks.d/test-container "$MNT_DIR/opt/synnefo-labs/examiner/checks.d/"
cp -v ../opt/synnefo-labs/examiner/checks.d/docker1 "$MNT_DIR/opt/synnefo-labs/examiner/checks.d/"
cp -v ../opt/synnefo-labs/examiner/checks.d/docker2 "$MNT_DIR/opt/synnefo-labs/examiner/checks.d/"
mkdir -p "$MNT_DIR/etc/systemd/system"
cp -v ../examiner.service "$MNT_DIR/etc/systemd/system/examiner.service"
ln -s /etc/systemd/system/examiner.service "$MNT_DIR/etc/systemd/system/multi-user.target.wants/examiner.service"

# Build readonly fs
mkdir -p "$MNT_DIR/overlay/root" \
 "$MNT_DIR/overlay/work" \
 "$MNT_DIR/mnt" \
 "$MNT_DIR/rom"

cp ../overlay-init "$MNT_DIR/sbin/overlay-init"

chmod +x "$MNT_DIR/sbin/overlay-init"
chown root:root "$MNT_DIR/sbin/overlay-init"

mksquashfs $MNT_DIR "$SCRIPT_DIR/rootfs.ext4" -noappend

umount $MNT_DIR
