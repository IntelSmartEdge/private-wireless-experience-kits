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

echo "This is an plmn post installer plugin."
# echo "Echo env value VENDOR_SCRIPTS: $VENDOR_SCRIPTS"

jinji2_render(){
yf="$1"
[[ "$yf" != ./* && "$yf" != /* ]] && yf="./$yf"
tmplp=${yf%/*}
tmpl=${yf##*/}
content=${2:-{\}}
cat <<EOF | python3
from jinja2 import Environment, FileSystemLoader

content=$content

file_loader = FileSystemLoader("$tmplp")
env = Environment(loader=file_loader)

template = env.get_template("$tmpl")
output=template.render(content)

print(output)
EOF
}

# plmn
kubectl get gnbplmns
retVal=$?
if [ "$retVal" -ne 0 ]; then
  kubectl apply -f "$RAN_SCRIPTS"/crd/gnb_plmn_crd.yaml
fi

CUCFG="$VENDOR_HELM"/cu/config/oam_3gpp_cu_sa_1du_1cell_flexran.xml
MCC_MNC=$(sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$CUCFG" | \
  xq -j '.rpc."edit-config".config.ME.GNBCUFunction.pLMNId')

MCC=$(jq .MCC <<< "$MCC_MNC" | tr -d '"')
MNC=$(jq .MNC <<< "$MCC_MNC" | tr -d '"')

echo "Get pLMNId from ${CUCFG}. MCC: $MCC, MNC: $MNC"
jinji2_render "$RAN_SCRIPTS"/crd/gnb_plmn.yaml.j2 "$(jq <<EOF
{
  "mcc": "\"$MCC\"",
  "mnc": "\"$MNC\""
}
EOF
)"| kubectl apply -f -
