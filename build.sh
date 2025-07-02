#!/bin/bash

sudo chmod +x type-alma/*

(
 cd ./type-alma || exit 1
 sudo ./build.sh
)

mv ./type-alma/rootfs.ext4 .
