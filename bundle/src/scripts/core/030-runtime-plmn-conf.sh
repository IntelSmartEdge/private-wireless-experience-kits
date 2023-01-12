#!/usr/bin/env bash
# INTEL CONFIDENTIAL
#
# Copyright 2020-2022 Intel Corporation.
#
# This software and the related documents are Intel copyrighted materials, and your use of
# them is governed by the express license under which they were provided to you ("License").
# Unless the License provides otherwise, you may not use, modify, copy, publish, distribute,
# disclose or transmit this software or the related documents without Intel's prior written permission.
#
# This software and the related documents are provided as is, with no express or implied warranties,
# other than those that are expressly stated in the License.


cur=$(dirname "$(readlink -f "$0")")
${cmd:-source} "$cur"/env.sh

AMFCFG="$VENDOR_HELM"/cn/charts/amf/config/oam_amf_config.xml
namespace=pwek-rdc

echo "This is an plmn runtime config plugin."
# echo "Echo env value VENDOR_SCRIPTS: \"$VENDOR_SCRIPTS\""

MCC=$(kubectl -n "$namespace" get plmn.pwek.smart.edge.org common -o=jsonpath="{.spec.mcc}")
MNC=$(kubectl -n "$namespace" get plmn.pwek.smart.edge.org common -o=jsonpath="{.spec.mnc}")
plmn="$MCC"$MNC


function sub_xml_val ()
{
  sed -i -e ':a;N;$!ba; s/[^>]*\(<\/'"$1"'>\)/'"$2"'\1/'"$3"'' "$4"
}

XML="$AMFCFG"

echo "---- Change plmnid in ""$XML"" from: ----"
grep -n -e "<plmnid>" "$XML"
ELM=plmnid VAL="$plmn" CUR=1
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=plmnid VAL="$plmn" CUR=2
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"
echo "---- to: ----"
grep -n -e "<plmnid>" "$XML"
