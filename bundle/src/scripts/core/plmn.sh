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


# need to change the plmn in these files
# deployment/helm/cu/config/RLCAMoam_3gpp_cu_sa_1du_1cell.xml
# deployment/helm/cu/config/oam_3gpp_cu_sa_1du_1cell.xml
# deployment/helm/du/l2config/oam_3gpp_cell_cfg_mu1_1cell_flexran.xml


# need to change the supi in these files
# cn/smf/recipe/config/oam_smf_config.xml
# deployment/helm/cn/charts/amf/config/oam_amf_config.xml
# deployment/helm/cn/charts/udm/config/mongo_config.js

list_append()
{
  p="$1"
  v="$2"
  f="$3"
  xq -x ''"$p"' += '"$v"'' "$f"
}

CONF=deployment/helm/cn/charts/upfoam/config/oam_upf_config_cdb.xml
# ufp_add_plmn "$plmn" "$CONF"
ufp_add_plmn()
{
  MCC=${1:0:3}
  MNC=${1:3:5}
  f="$2"
  path='."upf-function"."upf-profile".plmnList'
  val='[{"mcc": "'"$MCC"'", "mnc": "'"$MNC"'"}]'
  list_append "$path" "$val" "$CONF"
}

CONF=deployment/helm/du/du1-l2config/oam_3gpp_cell_cfg_mu1_1cell_flexran.xml
# XMLS_DIR=raidys_du_plmn_xmls
# split_multi_xmls "$CONF" "$XMLS_DIR"
split_multi_xmls(){
  remain=remain
  tmp_path=/tmp/${2:-/tmp/raidys_plmn_xmls}
  rm -rf "$tmp_path"
  mkdir -p "$tmp_path"
  i=1
  f="$1"
  while true; do
    sed '1,/]]>]]>/!d' "$f" > "$tmp_path"/"$i".xml
    echo "$tmp_path"/"$i".xml
    sed '1,/]]>]]>/d' "$f" > "$tmp_path"/${remain}.${i}.xml
    f="$tmp_path"/${remain}.${i}.xml
    echo "Check the xml file: ${f} contains multi xmls"
    grep "^]]>]]>$" "$f"
    ret=$?
    if [ "$ret" -ne 0 ]; then
      break
    fi
    i=$(( i + 1 ))
  done
}

# XMLS_DIR=raidys_du_plmn_xmls
# handle_single_files "$XMLS_DIR" mcc
handle_single_files(){
f=$(grep -i "$2" /tmp/"${1}"/[0-9]*.xml |cut -d ":" -f1 |uniq)
sed -e "/^]]>]]>$/d" "$f" | xq -j '.rpc."edit-config".config.ME.GNBDUFunction.vsDataContainer[0].vsData'
}

# NAME=oam_3gpp_cell_cfg_mu1_1cell_flexran.xml
# join_multi_xmls "$XMLS_DIR" "$NAME"
join_multi_xmls(){
rm -f /tmp/"${1}"/"${2}"
# for i in $(ls -tr /tmp/"${1}"/[0-9]*.xml); do
for i in  /tmp/"${1}"/[0-9]*.xml; do
  echo "Join $i"
  cat "$i" >> /tmp/"${1}"/"${2}"
done
}
