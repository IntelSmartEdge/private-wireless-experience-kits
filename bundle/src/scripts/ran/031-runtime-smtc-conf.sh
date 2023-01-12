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

namespace=pwek-rdc

echo "This is an smtc runtime config plugin."
# echo "Echo env value VENDOR_SCRIPTS: $VENDOR_SCRIPTS"

spec=$(kubectl -n "$namespace" get ssbmtcs.pwek.smart.edge.org common -o=jsonpath="{.spec}")
retVal=$?
if [ "$retVal" -ne 0 ]; then
  echo "No 'ssbmtcs' define, exit"
  exit 0
fi
periodicity=$(jq ".periodicity" <<< "$spec" | tr -d '"')
croffset=$(jq ".offset" <<< "$spec")
crbitmapv=$(jq ".duration.tomeasure" <<< "$spec"| tr -d '"')
crdurvalue=$(jq ".duration.value" <<< "$spec")
len=$(wc -c <<< "$crbitmapv")
if (( len > 9 )); then
  crbitmapt=longBitmap
elif (( len > 5 )); then
  crbitmapt=mediumBitmap
else
  crbitmapt=shortBitmap
fi

echo "The CRD smtc conifigure is: ${periodicity}: $croffset, duration: $crdurvalue, ${crbitmapt}: $crbitmapv."

# f $elm $nelm $val $cur $f
sub_xml_elm_val (){
  sed -i -e ':a;N;$!ba; s/<'"$1"'>.*\(<\/'"$1"'>\)/'"<$2>$3<\/$2>"'/'"$4"'' "$5"
}

# V2.5.2
# CONF="$VENDOR_HELM"/cu/config/RLCAMoam_3gpp_cu_sa_1du_1cell.xml
# V3.2.2
CONF="$VENDOR_HELM"/cu/config/oam_3gpp_cu_sa_1du_1cell_flexran.xml
vsData=$(sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$CONF" | \
  xq -j '.rpc."edit-config".config.ME.GNBCUFunction.NRCellCU.vsDataContainer.vsData')
smtc=$(grep -Po "(?<=<sf)[0-9]{1,3}.*(?=</sf[0-9])" <<< "$vsData")
period="sf${smtc%>*}"
offset=${smtc#*>}
tomeasure=$(grep -Po "(?<=Bitmap>).*(?=Bitmap>)" <<< "$vsData")
bitmapv=${tomeasure%</*}
bitmapt=${tomeasure#*</}
durvalue=$(grep -Po "(?<=<duration>)[0-9]*(?=</duration>)" <<< "$vsData")

echo "---- Get smtc for ${CONF} ----"
echo "$period: $offset, duration: $durvalue, ${bitmapt}Bitmap: ${bitmapv}"

echo "---- change smtc in $CONF from ----"
grep -n -e "<sf[0-9]*>" -e "<[a-zA-Z]*Bitmap>" -e "<duration>" "$CONF"
elm="$period"
val="$croffset"
f="$CONF"
cur=$(grep -c "<${elm}>" "$f")
nelm="$periodicity"
sub_xml_elm_val "$elm" "$nelm" "$val" "$cur" "$f"

elm="${bitmapt}Bitmap"
val="$crbitmapv"
cur=$(grep -c "<${elm}>" "$f")
nelm="$crbitmapt"
sub_xml_elm_val "$elm" "$nelm" "$val" "$cur" "$f"

elm="duration"
val="$crdurvalue"
cur=$(grep -c "<${elm}>" "$f")
nelm="duration"
sub_xml_elm_val "$elm" "$nelm" "$val" "$cur" "$f"
echo "---- to ----"
grep -n -e "<sf[0-9]*>" -e "<[a-zA-Z]*Bitmap>" -e "<duration>" "$CONF"


CONF="$VENDOR_HELM"/cu/config/oam_3gpp_cu_sa_1du_1cell.xml
vsData=$(sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$CONF" | \
  xq -j '.rpc."edit-config".config.ME.GNBCUFunction.NRCellCU.vsDataContainer.vsData')
smtc=$(grep -Po "(?<=<sf)[0-9]{1,3}.*(?=</sf[0-9])" <<< "$vsData")
period="sf${smtc%>*}"
offset=${smtc#*>}
tomeasure=$(grep -Po "(?<=Bitmap>).*(?=Bitmap>)" <<< "$vsData")
bitmapv=${tomeasure%</*}
bitmapt=${tomeasure#*</}
durvalue=$(grep -Po "(?<=<duration>)[0-9]*(?=</duration>)" <<< "$vsData")
echo "---- Get smtc for ${CONF} ----"
echo "$period: $offset, duration: $durvalue, ${bitmapt}Bitmap: ${bitmapv}"

echo "---- change smtc in $CONF from ----"
grep -n -e "<sf[0-9]*>" -e "<[a-zA-Z]*Bitmap>" -e "<duration>" "$CONF"
elm="$period"
val="$croffset"
f="$CONF"
cur=$(grep -c "<${elm}>" "$f")
nelm="$periodicity"
sub_xml_elm_val "$elm" "$nelm" "$val" "$cur" "$f"

elm="${bitmapt}Bitmap"
val="$crbitmapv"
cur=$(grep -c "<${elm}>" "$f")
nelm="$crbitmapt"
sub_xml_elm_val "$elm" "$nelm" "$val" "$cur" "$f"

elm="duration"
val="$crdurvalue"
cur=$(grep -c "<${elm}>" "$f")
nelm="duration"
sub_xml_elm_val "$elm" "$nelm" "$val" "$cur" "$f"
echo "---- to ----"
grep -n -e "<sf[0-9]*>" -e "<[a-zA-Z]*Bitmap>" -e "<duration>" "$CONF"
