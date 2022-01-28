#!/bin/sh

# INTEL CONFIDENTIAL
#
# Copyright 2020-2020 Intel Corporation.
#
# This software and the related documents are Intel copyrighted materials, and your use of
# them is governed by the express license under which they were provided to you ("License").
# Unless the License provides otherwise, you may not use, modify, copy, publish, distribute,
# disclose or transmit this software or the related documents without Intel's prior written permission.
#
# This software and the related documents are provided as is, with no express or implied warranties,
# other than those that are expressly stated in the License.

N6_INT="net1"
N6_IUPF=192.168.1.170
UE_IP=172.20.224.100
sudo ifconfig $N6_INT 192.168.1.18 up
sudo ping -c 5 $N6_IUPF
sudo ip route add $UE_IP via $N6_IUPF
sudo sed -i 's/geteuid/getppid/' /usr/bin/vlc
sudo cvlc -vvv rtp://@192.168.1.18:2001/ --sout '#rtp{sdp=rtsp://0.0.0.0:8554/}' --loop --sout-keep --sout-all
