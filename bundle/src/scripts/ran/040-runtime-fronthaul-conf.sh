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

L1CFG="$VENDOR_HELM"/du/du1-l1config/xrancfg_sub6.xml
DUCHARTF="$VENDOR_HELM"/du/values.yaml

echo "This is an fronthaul runtime config plugin."
# echo "Echo env value VENDOR_SCRIPTS: $VENDOR_SCRIPTS"

if [ -n "$1" ]; then
  RRU=RRU${1#vd}
else
  RRU=RRU
fi
echo "Set fronthaul interface with $RRU"

NETNS=sriov-network-operator
resource=intel_sriov_10G_${RRU}_VF
node=
fronthaul=$(kubectl get SriovNetworkNodeState -n ${NETNS:-default} -o json |  \
  jq ".items[$node].spec.interfaces[] | select( .vfGroups[].resourceName | contains(\"$resource\"))|.name" |
  uniq | tr -d '"' | head -n 1)
if [ -z "$fronthaul" ]; then
  echo "Not find ${resource}[0-9] for fronthaul interface"
  exit 0
fi
iface="$fronthaul"
driver=$(kubectl get SriovNetworkNodeState -n ${NETNS:-default} -o json | \
  jq ".items[$node].status.interfaces[] | select( .name | contains(\"$iface\")) | .driver" |tr -d '"')

# pid=$(kubectl get SriovNetworkNodeState -n ${NETNS:-default} -o json | \
#   jq ".items[$node].status.interfaces[] | select( .name | contains(\"$iface\")) | .deviceID" |tr -d '"')

if [[ "$driver" == i40e ]] ; then
echo "Fronthaul interface type is: X710"
uplaneResourceName=intel_sriov_10G_${RRU}_VF1
nicType=X710
fhVf=0
uplaneVlan=2
fi

if [[ "$driver" == ice ]] ; then
echo "Fronthaul interface type is: E810"
uplaneResourceName=intel_sriov_10G_${RRU}_VF0
nicType=E810
fhVf=1
uplaneVlan=1
fi

uplaneResourceName=${uplaneResourceName:-intel_sriov_10G_${RRU}_VF0}
nicType=${nicType:-E810}
fhVf=${fhVf:-1}
uplaneVlan=${uplaneVlan:-1}

function sub_xml_val ()
{
  sed -i -e ':a;N;$!ba; s/[^>]*\(<\/'"$1"'>\)/'"$2"'\1/'"$3"'' "$4"
}

XML="$L1CFG"

echo "---- Change u_plane_vlan_tag and oRuCUon1Vf in $XML from: ----"
grep -n -e "<u_plane_vlan_tag>" -e "<oRuCUon1Vf>" "$XML"

ELM=u_plane_vlan_tag VAL="$uplaneVlan" CUR=1
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=oRuCUon1Vf VAL="$fhVf" CUR=1
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

echo "---- to : ----"
grep -n -e "<u_plane_vlan_tag>" -e "<oRuCUon1Vf>" "$XML"


echo "---- update chart values in $DUCHARTF from: ----"
yq -o json '{"nicType": .nicType}' "$DUCHARTF"
yq -o json '.l1.appConfig.fronthaulInterfaces' "$DUCHARTF"
yq -o json '.l1.appConfig | {"uplaneVlan": .uplaneVlan}' "$DUCHARTF"

yq -i '.l1.appConfig.fhVf = '"$fhVf" "$DUCHARTF"
yq -i '.l1.appConfig.fronthaulInterfaces[0].uplaneResourceName = '"\"$uplaneResourceName\"" "$DUCHARTF"
yq -i '.nicType = '"\"$nicType\"" "$DUCHARTF"
yq -i '.l1.appConfig.uplaneVlan = '"$uplaneVlan" "$DUCHARTF"

echo "---- to ----"
yq -o json '{"nicType": .nicType}' "$DUCHARTF"
yq -o json '.l1.appConfig.fronthaulInterfaces' "$DUCHARTF"
yq -o json '.l1.appConfig | {"uplaneVlan": .uplaneVlan}' "$DUCHARTF"
