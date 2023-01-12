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

CUCFG="$VENDOR_HELM"/cu/config/oam_3gpp_cu_sa_1du_1cell_flexran.xml
DUCFG="$VENDOR_HELM"/du/du1-l2config/oam_3gpp_cell_cfg_mu1_1cell_flexran.xml
namespace=pwek-rdc


echo "This is an plmn runtime config plugin."
# echo "Echo env value VENDOR_SCRIPTS: $VENDOR_SCRIPTS"

MCC=$(kubectl -n "$namespace" get plmn.pwek.smart.edge.org common -o=jsonpath="{.spec.mcc}")
MNC=$(kubectl -n "$namespace" get plmn.pwek.smart.edge.org common -o=jsonpath="{.spec.mnc}")
# plmn="$MCC""$MNC"

function sub_xml_val ()
{
  sed -i -e ':a;N;$!ba; s/[^>]*\(<\/'"$1"'>\)/'"$2"'\1/'"$3"'' "$4"
}

# CU configure
XML="$CUCFG"

echo "---- Change MNC and MCC in $XML from: ----"
grep -n -e  "<MNC>" -e "<MCC>" "$XML"
CUR=1
ELM=MCC VAL="$MCC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=MNC VAL="$MNC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

CUR=2
ELM=MCC VAL="$MCC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=MNC VAL="$MNC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

CUR=10
ELM=MCC VAL="$MCC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=MNC VAL="$MNC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

CUR=11
ELM=MCC VAL="$MCC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=MNC VAL="$MNC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"
echo "---- to: ----"
grep -n -e  "<MNC>" -e "<MCC>" "$XML"

# DU configure
XML="$DUCFG"

echo "---- Change MNC and MCC in $XML from: ----"
grep -n -e  "<MNC>" -e "<MCC>" "$XML"
CUR=1
ELM=MCC VAL="$MCC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=MNC VAL="$MNC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

CUR=2
ELM=MCC VAL="$MCC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=MNC VAL="$MNC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

CUR=3
ELM=MCC VAL="$MCC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=MNC VAL="$MNC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

CUR=4
ELM=MCC VAL="$MCC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"

ELM=MNC VAL="$MNC"
sub_xml_val "$ELM" "$VAL" "$CUR" "$XML"
echo "---- to: ----"
grep -n -e  "<MNC>" -e "<MCC>" "$XML"
