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

# config file directory
CDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "The script path is: ""$CDIR"
${cmd:-source} "$CDIR"/env.sh
DIR=${VENDOR_HELM}
DIR=${DIR:-$CDIR}
echo "Directory is ""$DIR"
helm_charts_home="$DIR"
AMFCFG=${AMFCFG:-$helm_charts_home/cn/charts/amf/config/oam_amf_config.xml}
SMFCFG=${SMFCFG:-$helm_charts_home/cn/charts/smf/config/oam_smf_config.xml}
NS=${PWEKNS:-default}

XML="$AMFCFG"
# $1 element tag, $2 element value, $3 the n time occurrent, $4 file name
function sub_xml_val ()
{
  sed -i -e ':a;N;$!ba; s/[^>]*\(<\/'"$1"'>\)/'"$2"'\1/'"$3"'' "$4"
}

ueInfo=$(
sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$AMFCFG" | \
  xq -j '.rpc."edit-config".config.amf.ue_authsec_config')
echo "---- The original EMSI list ----"
jq <<< "$ueInfo"
len=$(jq '. | length' <<< "$ueInfo")

if (( len > 0 )); then
  echo "Update '$len' IMSIs for AMF in '$AMFCFG':"
  for i in $(kubectl -n "$NS" get imsi --no-headers=true -o name | grep ".*/ue-[0-9]*")
  do
    ue=$(kubectl -n "$NS" get "$i" -o jsonpath='{.spec.ue}')
    id=${i##*-}
    supi=$(jq .supi <<< "$ue" | tr -d '"')
    orgsupi=$(jq .["$id"].supi <<<  "$ueInfo" | tr -d '"' | tr -d " ")
    if [[ "$orgsupi" != "$supi" ]]; then
      echo "The supi of imsi '$id' is updated to '$supi' in $SMFCFG"
      sed -i -e "s/$orgsupi/$supi/" "$SMFCFG"
    fi
    supi=$(python -c "print(' '.join('$supi'))")
    opc_key=$(jq .opc <<< "$ue"| tr -d '"')
    op_key="$opc_key"
    auth_key=$(jq .ueUsimKey <<< "$ue" | tr -d '"')

    XEL=supi VAL="$supi" CUR=$((id+1))
    sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
    XEL=opc_key VAL="$opc_key" CUR=$((id+1))
    sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
    XEL=op_key VAL="$op_key" CUR=$((id+1))
    sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
    XEL=auth_key VAL="$auth_key" CUR=$((id+1))
    sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
    echo "Update IMSI ""$id"", done"
  done
else
  echo "NOTE: Do not support insert a new IMSI in this version!"
fi

ueInfo=$(
sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$AMFCFG" | \
  xq -j '.rpc."edit-config".config.amf.ue_authsec_config')
echo "---- The Updated  EMSI list----"
jq <<< "$ueInfo"
