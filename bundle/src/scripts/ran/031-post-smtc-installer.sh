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

NS=${PWEKNS:-default}

# RAN_SCRIPTS="src/scripts/ran"
# CUCFG=helm/cu/config/oam_3gpp_cu_sa_1du_1cell.xml
CUCFG="$VENDOR_HELM"/cu/config/oam_3gpp_cu_sa_1du_1cell.xml


echo "This is an smtc post installer plugin."
# echo "Echo env value VENDOR_SCRIPTS: \"$VENDOR_SCRIPTS\""

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

# mtcs
kubectl get ssbmtcs
retVal=$?
if [ "$retVal" -ne 0 ]; then
  kubectl apply -f "$RAN_SCRIPTS"/crd/gnb_ssb-mtc_crd.yaml
fi

vsData=$(sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$CUCFG" | \
  xq -j '.rpc."edit-config".config.ME.GNBCUFunction.NRCellCU.vsDataContainer.vsData')
# echo "$vsData"
smtc=$(grep -Po "(?<=<sf)[0-9]{1,3}.*(?=</sf[0-9])" <<< "$vsData")
period="sf${smtc%>*}"
offset=${smtc#*>}
tomeasure=$(grep -Po "(?<=Bitmap>).*(?=Bitmap>)" <<< "$vsData")
bitmapv=${tomeasure%</*}
bitmapt=${tomeasure#*</}
durvalue=$(grep -Po "(?<=<duration>)[0-9]*(?=</duration>)" <<< "$vsData")

echo "---- Get smtc for ${CUCFG} ----"
echo "$period: $offset, duration: $durvalue, ${bitmapt}Bitmap: ${bitmapv}"

jinji2_render "$RAN_SCRIPTS"/crd/gnb_ssb-mtc.yaml.j2 "$(jq <<EOF
{
  "periodicity": "\"$period\"",
  "offset": "$offset",
  "duration": {
    "value": "$durvalue",
    "tomeasure": "\"$bitmapv\""
  }
}
EOF
)"| kubectl apply -f -

kubectl -n "$NS" get ssbmtc common -o json | jq .spec
