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
sudo ip addr add 192.179.96.18/24 dev "$N6_INT"
sudo pkill -9 tcpdump
ping -c 5 192.179.96.180 
sudo tcpdump -i $N6_INT -nn
