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

MIMO=common
key="purpose"
label="${key}=${1}"

# config file directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "The script path is: ""$DIR"
${cmd:-source} "$DIR"/env.sh

helm_charts_home=${VENDOR_HELM}
echo "Directory is $helm_charts_home"
DUCFG=$helm_charts_home/du/du1-l2config/oam_3gpp_cell_cfg_mu1_1cell_flexran.xml

NS=${PWEKNS:-default}
if [ -n "$1" ]; then
  echo "Get mimo config by label: $label"
  values=$(kubectl -n "$NS" get mimo -l "${label}" -o jsonpath="{.items[0].spec}" 2> /dev/null)
else
  echo "No special mimo configure for ${1:-du1}."
fi
if [ -z "$values" ]; then
  echo "Use common config for ${1:-du1}"
  values=$(kubectl get mimo "$MIMO" -n "$NS" -o=jsonpath="{.spec}")
fi

DLRANK=$(jq .dlrank <<< "$values")
DLANTPORT=$(jq .dlnumofantports <<< "$values")
ULRANK=$(jq .ulrank <<< "$values")
ULANTPORT=$(jq .ulnumofantports <<< "$values")

echo "setting MIMO for DU in $DUCFG from:"
grep -e "[du]lNum[Of]*AntPorts" -e "[du]lRank"  "$DUCFG"

# $1 element tag, $2 element value, $3 the n time occurrent, $4 file name
function sub_xml_val ()
{
  sed -i -e ':a;N;$!ba; s/[^>]*\(<\/'"$1"'>\)/'"$2"'\1/'"$3"'' "$4"
}

XEL=dlRank VAL="$DLRANK" CUR=1
XML="$DUCFG"
sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"

XEL=dlNumAntPorts VAL="$DLANTPORT" CUR=1
sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"

XEL=ulRank VAL="$ULRANK" CUR=1
sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"

XEL=ulNumOfAntPorts VAL="$ULANTPORT" CUR=1
sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"

echo "setting MIMO for DU in $DUCFG to:"
grep -e "[du]lNum[Of]*AntPorts" -e "[du]lRank"  "$DUCFG"

echo "please run the follow command to setup du:"
echo "  helm install vdu ./du"
# helm del vcu vdu
