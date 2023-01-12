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

# MIMO=common

key="purpose"
label="${key}=${1}"
crd=freq

# config file directory
DIR="$( cd "$( dirname "${0}" )" && pwd )"
echo "The script path is: $DIR"
${cmd:-source} "$DIR"/env.sh
helm_charts_home=${VENDOR_HELM:-$DIR}
echo "Directory is $helm_charts_home"
DUCFG=${DUCFG:-$helm_charts_home/du/du1-l2config/oam_3gpp_cell_cfg_mu1_1cell_flexran.xml}
NS=${PWEKNS:-default}

dlFreqInfo=$(
sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$DUCFG" | \
  xq -j '.rpc."edit-config".config.ME.GNBDUFunction.NRCellDU.vsDataContainer.vsData' | \
  xq -j .gnbvs.gnbDuCfg.gnbCellDuVsCfg.dlCfgCmn.dlFreqInfo)
echo "The original dlFreqInfo:"
echo "$dlFreqInfo" | jq

ulFreqInfo=$(
sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$DUCFG" | \
  xq -j '.rpc."edit-config".config.ME.GNBDUFunction.NRCellDU.vsDataContainer.vsData' | \
  xq -j .gnbvs.gnbDuCfg.gnbCellDuVsCfg.ulCfgCmn.ulFreqInfo)
echo "The original ulFreqInfo:"
echo "$ulFreqInfo" | jq

echo "setting frequence for DU in $DUCFG:"

# $1 element tag, $2 element value, $3 the n time occurrent, $4 file name
sub_xml_val ()
{
  sed -i -e ':a;N;$!ba; s/[^>]*\(<\/'"$1"'>\)/'"$2"'\1/'"$3"'' "$4"
}

XML="$DUCFG"

# set -o pipefail
FREQ=dlcommon
kubectl get freq "$FREQ" -n "$NS"
retVal=$?
if [ "$retVal" -eq 0 ]; then
  if [ -n "$1" ]; then
    echo "Get dl freq config by label: $label"
    values=$(kubectl -n pwek-rdc get $crd  -l "${label},type=dl" -o jsonpath="{.items[0].spec}" 2> /dev/null)
  else
    echo "No special dl freq configure for ${1:-du1}."
  fi
  if [ -z "$values" ]; then
    echo "Use dlcommon config for ${1:-du1}"
    values=$(kubectl get freq "$FREQ" -n "$NS" -o=jsonpath="{.spec}")
  fi
  echo "---- Set frequence for DL ----"
  absFreqPointA=$(echo "$values" | jq .absFreqPointA)
  absArfcnPointA=$(echo "$values" | jq .absArfcnPointA)
  nrFreqBand=$(echo "$values" | jq .nrFreqBand)
  offsetToCarrier=$(echo "$values" | jq .offsetToCarrier)
  subCarrierSpacing=$(echo "$values" | jq .subCarrierSpacing)
  subCarrierSpacing=${subCarrierSpacing%\"} subCarrierSpacing=${subCarrierSpacing#\"}
  carrierBw=$(echo "$values" | jq .carrierBw)
  # Special for DL
  absFreqSsb=$(echo "$values" | jq .absFreqSsbDl)
  absArfcnSsb=$(echo "$values" | jq .absArfcnSsbDl)
  # NOTE: NRCellDU also configure this option, value is 1.
  bSChannelBwDL=$(echo "$values" | jq .bSChannelBw)
  bSChannelBwDL=${bSChannelBwDL%\"} bSChannelBwDL=${bSChannelBwDL#\"}
  dlEarfcn=$(echo "$values" | jq .earfcn)
  
  # <absFreqPointA>3700560</absFreqPointA>
  XEL=absFreqPointA VAL="$absFreqPointA" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <absArfcnPointA>646704</absArfcnPointA>
  XEL=absArfcnPointA VAL="$absArfcnPointA" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <absFreqSsb>3708480</absFreqSsb>
  XEL=absFreqSsb VAL="$absFreqSsb" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <absArfcnSsb>647232</absArfcnSsb>
  XEL=absArfcnSsb VAL="$absArfcnSsb" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <nrFreqBand>78</nrFreqBand>
  XEL=nrFreqBand VAL="$nrFreqBand" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <offsetToCarrier>0</offsetToCarrier>
  XEL=offsetToCarrier VAL="$offsetToCarrier" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <subCarrierSpacing>KHz30</subCarrierSpacing>
  XEL=subCarrierSpacing VAL="$subCarrierSpacing" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <carrierBw>273</carrierBw>
  XEL=carrierBw VAL="$carrierBw" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <bSChannelBwDL>100MHZ</bSChannelBwDL>
  XEL=bSChannelBwDL VAL="$bSChannelBwDL" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <dlEarfcn>649980</dlEarfcn>
  XEL=dlEarfcn VAL="$dlEarfcn" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  dlFreqInfo=$(
  sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$DUCFG" | \
    xq -j '.rpc."edit-config".config.ME.GNBDUFunction.NRCellDU.vsDataContainer.vsData' | \
    xq -j .gnbvs.gnbDuCfg.gnbCellDuVsCfg.dlCfgCmn.dlFreqInfo)
  echo "$dlFreqInfo" | jq
fi


echo ""
FREQ=ulcommon
kubectl get freq "$FREQ" -n "$NS"
retVal=$?
if [ "$retVal" -eq 0 ]; then
  if [ -n "$1" ]; then
    echo "Get the ul freq config by label: $label"
    values=$(kubectl -n pwek-rdc get $crd  -l "${label},type=ul" -o jsonpath="{.items[0].spec}" 2> /dev/null)
  else
    echo "No special ul freq configure for ${1:-du1}."
  fi
  if [ -z "$values" ]; then
    echo "Use ulcommon config for ${1:-du1}"
    values=$(kubectl get freq "$FREQ" -n "$NS" -o=jsonpath="{.spec}")
  fi
  values=$(kubectl get freq "$FREQ" -n "$NS" -o=jsonpath="{.spec}")
  echo "---- Set frequence for UL ----"
  absFreqPointA=$(echo "$values" | jq .absFreqPointA)
  absArfcnPointA=$(echo "$values" | jq .absArfcnPointA)
  # NOTE: No need for UL
  # absFreqSsb=3708480
  # absArfcnSsb=3708480
  nrFreqBand=$(echo "$values" | jq .nrFreqBand)
  offsetToCarrier=$(echo "$values" | jq .offsetToCarrier)
  subCarrierSpacing=$(echo "$values" | jq .subCarrierSpacing)
  subCarrierSpacing=${subCarrierSpacing%\"} subCarrierSpacing=${subCarrierSpacing#\"}
  carrierBw=$(echo "$values" | jq .carrierBw)
  # Special for UL
  bSChannelBwUl=$(echo "$values" | jq .bSChannelBw)
  bSChannelBwUl=${bSChannelBwUl%\"} bSChannelBwUl=${bSChannelBwUl#\"}
  dlEarfcn=$(echo "$values" | jq .earfcn)
  ulEarfcn=$(echo "$values" | jq .earfcn)
  pMax=$(echo "$values" | jq .pMaxUl)
  freqShft7p5khz=$(echo "$values" | jq .freqShft7p5khzUl)
  freqShft7p5khz=${freqShft7p5khz%\"} freqShft7p5khz=${freqShft7p5khz#\"}
  addtionalSpectrumEmission=$(echo "$values" | jq .addtionalSpectrumEmissionUl)

  # <absFreqPointA>3700560</absFreqPointA>
  XEL=absFreqPointA VAL="$absFreqPointA" CUR=2
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <absArfcnPointA>646704</absArfcnPointA>
  XEL=absArfcnPointA VAL="$absArfcnPointA" CUR=2
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # No need for UL
  # # <absFreqSsb>3708480</absFreqSsb>
  # XEL=absFreqSsb VAL="$absFreqSsb" CUR=?
  # sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  #
  # # <absArfcnSsb>647232</absArfcnSsb>
  # XEL=absArfcnSsb VAL="$absArfcnSsb" CUR=?
  # sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <nrFreqBand>78</nrFreqBand>
  XEL=nrFreqBand VAL="$nrFreqBand" CUR=2
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <offsetToCarrier>0</offsetToCarrier>
  XEL=offsetToCarrier VAL="$offsetToCarrier" CUR=2
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <subCarrierSpacing>KHz30</subCarrierSpacing>
  XEL=subCarrierSpacing VAL="$subCarrierSpacing" CUR=2
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <carrierBw>273</carrierBw>
  XEL=carrierBw VAL="$carrierBw" CUR=2
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <bSChannelBwDL>100MHZ</bSChannelBwDL>
  XEL=bSChannelBwUl VAL="$bSChannelBwUl" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <pMax>23</pMax>
  XEL=pMax VAL="$pMax" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <freqShft7p5khz>7P5KHZ_DISBL</freqShft7p5khz>
  XEL=freqShft7p5khz VAL="$freqShft7p5khz" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <addtionalSpectrumEmission>0</addtionalSpectrumEmission>
  XEL=addtionalSpectrumEmission VAL="$addtionalSpectrumEmission" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  # <dlEarfcn>649980</dlEarfcn>
  XEL=ulEarfcn VAL="$ulEarfcn" CUR=1
  sub_xml_val "$XEL" "$VAL" "$CUR" "$XML"
  
  ulFreqInfo=$(
  sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$DUCFG" | \
    xq -j '.rpc."edit-config".config.ME.GNBDUFunction.NRCellDU.vsDataContainer.vsData' | \
    xq -j .gnbvs.gnbDuCfg.gnbCellDuVsCfg.ulCfgCmn.ulFreqInfo)
  echo "$ulFreqInfo" | jq
fi

# set +o pipefail
