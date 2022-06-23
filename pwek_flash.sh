#!/bin/bash
#SPDX-License-Identifier: Apache-2.0
#Copyright (c) 2021 Intel Corporation

/usr/bin/sed -i "s!\${_usb\/_\${_hex}\/}-(\${_dev\/..\\\/..\\\/\/\\\/dev\/})!\${_usb\/_\${_hex}\/}-(\${_dev\/..\\\/..\\\/\\\/dev\/})!g" esp/flashusb.sh
/usr/bin/sed -i "s!\"data/usr/share/nginx/html/mbr.bin\"!\"esp/data/usr/share/nginx/html/mbr.bin\"!g" esp/flashusb.sh

if [ -z "$1" ] ;then
    echo "please input: ./pwek_flash.sh efi ./out/Smart_Edge_Open_Private_Wireless_Experience_Kit-efi.img or ./pwek_flash.sh bios ./out/Smart_Edge_Open_Private_Wireless_Experience_Kit-bios.img"
    exit
elif [[ "$1" == "efi" ]] ;then
    if [ -z "$2" ] ;then
        IMAGE="./out/Smart_Edge_Open_Private_Wireless_Experience_Kit-efi.img"
        /usr/bin/bash esp/flashusb.sh --image ${IMAGE} --bios efi
    else
        /usr/bin/bash esp/flashusb.sh --image "$2" --bios efi
    fi
elif [[ "$1" == "bios" ]] ;then
    if [ -z "$2" ] ;then
        IMAGE="./out/Smart_Edge_Open_Private_Wireless_Experience_Kit-bios.img"
        /usr/bin/bash esp/flashusb.sh --image ${IMAGE} --bios bios
    else
        /usr/bin/bash esp/flashusb.sh --image "$2" --bios bios
    fi
else
    echo "please input: ./pwek_flash.sh efi ./out/Smart_Edge_Open_Private_Wireless_Experience_Kit-efi.img or ./pwek_flash.sh bios ./out/Smart_Edge_Open_Private_Wireless_Experience_Kit-bios.img"
    exit
fi