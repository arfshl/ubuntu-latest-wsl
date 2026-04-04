#!/bin/sh

# export the env
export RELEASE=questing
export ARCH=$(dpkg --print-architecture)
echo "RELEASE=$RELEASE" >> "$GITHUB_ENV"
echo "ARCH=$ARCH" >> "$GITHUB_ENV"

# install depedencies
sudo apt update && sudo apt install -yq curl libarchive-tools
curl -L -o /tmp/mmdebstrap.deb http://ftp.us.debian.org/debian/pool/main/m/mmdebstrap/mmdebstrap_1.5.7-3_all.deb
sudo apt install -yq /tmp/mmdebstrap.deb
curl -L -o /tmp/keyring.deb http://ftp.us.debian.org/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2025.1_all.deb
sudo apt install -yq /tmp/keyring.deb

# start build with mmdebstrap and sprays some WD-40 to get rid of rust on coreutils
dist_version="$RELEASE"

sudo mmdebstrap \
--arch=$ARCH \
--variant=apt \
--components="main,universe,multiverse" \
--include=locales,passwd,software-properties-common,ca-certificates \
--format=directory \
${dist_version} \
ubuntu \
http://archive.ubuntu.com/ubuntu

cat <<-EOF | sudo unshare -mpf bash -e -
sudo mount --bind /dev ./ubuntu/dev
sudo mount --bind /proc ./ubuntu/proc
sudo mount --bind /sys ./ubuntu/sys
sudo echo 'nameserver 1.1.1.1' >> ./ubuntu/etc/resolv.conf

sudo chroot ./ubuntu apt update
sudo chroot ./ubuntu apt purge -yq --allow-remove-essential coreutils-from-uutils
sudo chroot ./ubuntu apt purge -yq --allow-remove-essential rust-coreutils
sudo chroot ./ubuntu apt install -yq coreutils-from-gnu
sudo chroot ./ubuntu apt install -yq gnu-coreutils
sudo chroot ./ubuntu apt clean

sudo rm -rf ./ubuntu/var/lib/apt/lists/*
sudo rm -rf ./ubuntu/var/tmp*
sudo rm -rf ./ubuntu/tmp*
EOF

cd ubuntu
sudo tar --exclude=dev/* --warning=no-file-changed -czpvf ../rootfs.tar.gz .

# combine wsldl and rootfs
cd ../
if [ $ARCH = amd64 ]; then 
   curl -L https://github.com/yuk7/wsldl/releases/download/26032000/icons.zip -o icons.zip
   bsdtar -xf icons.zip
   mv Ubuntu.exe ubuntu.exe
   bsdtar -a -cf ubuntu.zip rootfs.tar.gz ubuntu.exe
else
   curl -L https://github.com/yuk7/wsldl/releases/download/26032000/icons_arm64.zip -o icons.zip
   bsdtar -xf icons.zip
   mv Ubuntu.exe ubuntu.exe
   bsdtar -a -cf ubuntu.zip rootfs.tar.gz ubuntu.exe
fi