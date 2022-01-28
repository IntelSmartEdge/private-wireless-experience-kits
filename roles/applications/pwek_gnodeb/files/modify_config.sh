#!/bin/bash
# INTEL CONFIDENTIAL
#
# Copyright 2020-2021 Intel Corporation.
#
# This software and the related documents are Intel copyrighted materials, and your use of
# them is governed by the express license under which they were provided to you ("License").
# Unless the License provides otherwise, you may not use, modify, copy, publish, distribute,
# disclose or transmit this software or the related documents without Intel's prior written permission.
#
# This software and the related documents are provided as is, with no express or implied warranties,
# other than those that are expressly stated in the License.

#CONF="/home/flexRAN_preBuild/flexran_e2e/rsys_cu/config/sys_config.txt"
qat_tmp=/tmp/pci_addr
((n=1 + "$1"))
CONF=$2

function sed_nextline_after_match ()
{
  sed -i -e  "/$1/{n;s/$2/$3/}" "$4"
}
#read pid file to determine to value of vars
pci1=$(awk -v n="$n" 'NR==n' $qat_tmp)
pci2=$(tail -"$n" $qat_tmp|head -n 1)

CONDITION=FAST_CRYPTO_PORT_0
PATTERN="PCI_ADDRESS.*"
VALUE="PCI_ADDRESS= $pci1"
# Second time currence, set CU IP
sed_nextline_after_match $CONDITION "$PATTERN" "$VALUE" "$CONF"

CONDITION=FAST_CRYPTO_PORT_1
PATTERN="PCI_ADDRESS.*"
VALUE="PCI_ADDRESS= $pci2"

# Third time currence, set amf IP
sed_nextline_after_match $CONDITION "$PATTERN" "$VALUE" "$CONF"
