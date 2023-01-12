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


# NOTE: let's we consider leverage https://jinja.palletsprojects.com/en/

echo 'This is post install'

# cur=$(dirname $(readlink -f "$0"))
cur=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# source "$cur"/env.sh
echo "current dir is $cur"
DIR=${VENDOR_SCRIPTS:-$cur}

${cmd:-source} "$DIR"/env.sh

echo "$PWEKNS"

mv "$VENDOR_HELM"/du/values.yaml "$VENDOR_HELM"/du/values.yaml.bak
cp "$VENDOR_HELM"/du/du1-values.yaml "$VENDOR_HELM"/du/values.yaml

DUCFG=${DUCFG:-$DEP_PATH/helm/du/du1-l2config/oam_3gpp_cell_cfg_mu1_1cell_flexran.xml}
AMFCFG=${AMFCFG:-$DEP_PATH/helm/cn/charts/amf/config/oam_amf_config.xml}

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

# start ran
echo "sed -i -e \"s|{{ pwek_namespace_name }}|$PWEKNS|g\" $RAN_SCRIPTS/kubectl-ran-start"
sed -i -e "s|{{ pwek_namespace_name }}|$PWEKNS|g" \
  -e "s|{{ _pwek_5gran_dir }}|$PWEKPATH/5gran_entry_point|g" \
  -e "s|ENTRY=\(.*\)|# ENTRY=\1|g" \
  -e "/^VENDOR=.*/a ENTRY=kubectl-\${VENDOR}-ran-start" "$RAN_SCRIPTS"/kubectl-ran-start

# stop ran
sed -i -e "s|{{ _pwek_5gran_dir }}|$PWEKPATH/5gran_entry_point|g" \
  -e "s|ENTRY=\(.*\)|# ENTRY=\1|g" \
  -e "/^VENDOR=.*/a ENTRY=kubectl-\${VENDOR}-ran-stop" \
  -e "s|{{ pwek_namespace_name }}|$PWEKNS|g" "$RAN_SCRIPTS"/kubectl-ran-stop

# start core
sed -i -e "s|{{ _pwek_5gcore_dir }}|$PWEKPATH/5gcore_entry_point|g" \
  -e "s|ENTRY=\(.*\)|# ENTRY=\1|g" \
  -e "/^VENDOR=.*/a ENTRY=kubectl-\${VENDOR}-core-start" \
  -e "s|{{ pwek_namespace_name }}|$PWEKNS|g" "$CORE_SCRIPTS"/kubectl-core-start

# stop core
sed -i -e "s|{{ _pwek_5gcore_dir }}|$PWEKPATH/5gcore_entry_point|g" \
  -e "s|ENTRY=\(.*\)|# ENTRY=\1|g" \
  -e "/^VENDOR=.*/a ENTRY=kubectl-\${VENDOR}-core-stop" \
  -e "s|{{ pwek_namespace_name }}|$PWEKNS|g" "$CORE_SCRIPTS"/kubectl-core-stop

# parameters in radisys files
sed -i -e "s|{{ pwek_namespace_name }}|$PWEKNS|g" \
  -e "s|{{ _pwek_5gran_dir }}|$PWEKPATH/5gran_entry_point|g" \
  -e "s|{{ _pwek_5gcore_dir }}|$PWEKPATH/5gcore_entry_point|g" \
  -e "s|{{ helm_chart_path }}|$DEP_PATH|g" \
  "$DIR"/kubectl-* "$CORE_SCRIPTS"/*.sh "$RAN_SCRIPTS"/*.sh "$CORE_SCRIPTS"/kubectl-* "$RAN_SCRIPTS"/kubectl-*

echo "Install kubectl plugin: copy plugins from $DIR to /usr/local/bin/"
rm -f /usr/local/bin/kubectl*radisys*
rm -f /usr/local/bin/kubectl-ran*
rm -f /usr/local/bin/kubectl-core*
cp "$DIR"/kubectl-*  /usr/local/bin/
cp "$RAN_SCRIPTS"/kubectl-*  /usr/local/bin/
cp "$CORE_SCRIPTS"/kubectl-*  /usr/local/bin/


# Run the common excutable files
for i in $(find "$VENDOR_SCRIPTS"/[0-9]*-post* 2>/dev/null | sort -V); do
  echo "Run $i"
  $i
done

# Run the RAN excutable files
for i in $(find "$RAN_SCRIPTS"/[0-9]*-post* 2>/dev/null | sort -V); do
  echo "Run $i"
  "$i"
done

# Run the CORE excutable files
for i in $(find "$CORE_SCRIPTS"/[0-9]*-post* 2>/dev/null | sort -V); do
  echo "Run $i"
  "$i"
done

# mimo
kubectl get gnbmimoes
retVal=$?
if [ "$retVal" -ne 0 ]; then
  kubectl apply -f "$RAN_SCRIPTS"/crd/gnb_mimo_crd.yaml
fi
kubectl apply -f "$RAN_SCRIPTS"/crd/gnb_mimo.yaml

# mcs
kubectl get gnbmcs
retVal=$?
if [ "$retVal" -ne 0 ]; then
  kubectl apply -f "$RAN_SCRIPTS"/crd/gnb_mcs_crd.yaml
fi
# kubectl apply -f "$RAN_SCRIPTS"/crd/gnb_mcs.yaml.j2

macCfgCmn=$(
  sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$DUCFG" | \
  xq -j '.rpc."edit-config".config.ME.GNBDUFunction.NRCellDU.vsDataContainer.vsData' | \
  xq -j .gnbvs.gnbDuCfg.gnbCellDuVsCfg.macCfgCmn)

dlMcs=$(jq .dlMcs <<< "$macCfgCmn" | tr -d '"')
ulMcs=$(jq .ulMcs <<< "$macCfgCmn" | tr -d '"')
rarMcs=$(jq .rarMcs <<< "$macCfgCmn" | tr -d '"')
bcchMcs=$(jq .bcchMcs <<< "$macCfgCmn" | tr -d '"')
pcchMcs=$(jq .pcchMcs <<< "$macCfgCmn" | tr -d '"')

jinji2_render "$RAN_SCRIPTS"/crd/gnb_mcs.yaml.j2 "$(jq <<EOF
{
  "dlMcs": "$dlMcs",
  "ulMcs": "$ulMcs",
  "rarMcs": "$rarMcs",
  "bcchMcs": "$bcchMcs",
  "pcchMcs": "$pcchMcs"
}
EOF
)"| kubectl apply -f -


# CPU
kubectl get cpu
retVal=$?
if [ "$retVal" -ne 0 ]; then
  kubectl apply -f "$RAN_SCRIPTS"/crd/profile_cpu_crd.yaml.j2
fi
upf_core_num=5
cu_core_num=7
phy_core_num=12
du_core_num=10
sed -e "s/{{ upf_core_num }}/$upf_core_num/"  \
  -e "s/{{ cu_core_num }}/$cu_core_num/"      \
  -e "s/{{ phy_core_num }}/$phy_core_num/"    \
  -e "s/{{ du_core_num }}/$du_core_num/" "$RAN_SCRIPTS"/crd/vendor_cpu.yaml.j2 | \
kubectl apply -f -

CPU_MODE=${CPU_MODE:-auto}
sed -i -e "s/namespace=.*/namespace=\${1:-\$PWEKNS}/" "$RAN_SCRIPTS"/cpu_automation.sh
sed -i -e "/namespace=.*/a namespace=\${namespace:-default}" "$RAN_SCRIPTS"/cpu_automation.sh
chmod a+x "$RAN_SCRIPTS"/cpu_automation.sh

rm -rf "$DIR/deployment_rdeliver" "$DIR/deployment_ipinning"
# radisys deliver release without touch by intel's CPU pinning
[ ! -d "$DIR/deployment_rdeliver" ] && mkdir -p "$DIR"/deployment_rdeliver && cp -r "$DEP_PATH"/* "$DIR"/deployment_rdeliver
# Intel's CPU pinning touch the radisys deliver release
"$RAN_SCRIPTS"/cpu_automation.sh "${PWEKNS:-default}"
# intel CPU pinning
[ ! -d "$DIR/deployment_ipinning" ] && mkdir -p "$DIR"/deployment_ipinning && cp -r "$DEP_PATH"/* "$DIR"/deployment_ipinning
# Copy Intel RAN CPU pinning back to the deployment path if need.
if [[ ! "$CPU_MODE" =~ "ran" ]]; then
  # Copy radisys CU/DU to the deployment path
  echo "Copy radisys [cd]u from $DIR/deployment_rdeliver/helm to $DEP_PATH/helm"
  [ -d "$DIR/deployment_rdeliver" ] && rm -rf "$DEP_PATH"/helm/[cd]u && cp -r "$DIR"/deployment_rdeliver/helm/[cd]u "$DEP_PATH"/helm
fi
# Copy Intel core CPU pinning back to the deployment path if need.
if [[ ! "$CPU_MODE" =~ "core" ]]; then
  # Copy radisys CU/DU to the deployment path
  echo "Copy radisys cn from $DIR/deployment_rdeliver/helm to $DEP_PATH/helm"
  [ -d "$DIR/deployment_rdeliver" ] && rm -rf "$DEP_PATH"/helm/cn && cp -r "$DIR"/deployment_rdeliver/helm/cn "$DEP_PATH"/helm
fi
# if [ "$CPU_MODE" = "auto" ]; then
#    [ ! -d "$DIR/deployment_back" ] && mkdir -p "$DIR"/deployment_back && cp -r "$DEP_PATH"/* "$DIR"/deployment_back
#    "$RAN_SCRIPTS"/cpu_automation.sh ${PWEKNS:-default}
# else
#    [ -d "$DIR/deployment_back" ] && cp -r "$DIR"/deployment_back/* "$DEP_PATH"
# fi


# frequence
kubectl get freq
retVal=$?
if [ "$retVal" -ne 0 ]; then
  kubectl apply -f "$RAN_SCRIPTS"/crd/gnb_frequence_crd.yaml
fi

echo "Please follow radisys user guide and these links to set frequence info"
echo "  https://5g-tools.com/5g-nr-gscn-calculator/"
echo "  https://www.sharetechnote.com/html/5G/5G_ResourceBlockIndexing.html#SSB_Frequency_Location_in_SA"
# FIXME: This can be optimized
values=$(
sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$DUCFG" | \
  xq -j '.rpc."edit-config".config.ME.GNBDUFunction.NRCellDU.vsDataContainer.vsData' | \
  xq -j .gnbvs.gnbDuCfg.gnbCellDuVsCfg.dlCfgCmn.dlFreqInfo)
absFreqPointA=$(jq .absFreqPointA <<< "$values")
absFreqPointA=${absFreqPointA%\"} absFreqPointA=${absFreqPointA#\"}
absArfcnPointA=$(jq .absArfcnPointA <<< "$values")
absArfcnPointA=${absArfcnPointA%\"} absArfcnPointA=${absArfcnPointA#\"}
nrFreqBand=$(jq .nrFreqBand <<< "$values")
nrFreqBand=${nrFreqBand%\"} nrFreqBand=${nrFreqBand#\"}
absFreqSsbDl=$(jq .absFreqSsb <<< "$values")
absFreqSsbDl=${absFreqSsbDl%\"} absFreqSsbDl=${absFreqSsbDl#\"}
absArfcnSsbDl=$(jq .absArfcnSsb <<< "$values")
absArfcnSsbDl=${absArfcnSsbDl%\"} absArfcnSsbDl=${absArfcnSsbDl#\"}
offsetToCarrier=$(jq .subCarrierCfg.offsetToCarrier <<< "$values")
offsetToCarrier=${offsetToCarrier%\"} offsetToCarrier=${offsetToCarrier#\"}
carrierBw=$(jq .subCarrierCfg.carrierBw <<< "$values")
carrierBw=${carrierBw%\"} carrierBw=${carrierBw#\"}
subCarrierSpacing=$(jq .subCarrierCfg.subCarrierSpacing <<< "$values")
subCarrierSpacing=${subCarrierSpacing%\"} subCarrierSpacing=${subCarrierSpacing#\"}
bSChannelBw=$(jq .bSChannelBwDL <<< "$values")
bSChannelBw=${bSChannelBw%\"} bSChannelBw=${bSChannelBw#\"}
earfcn=$(jq .dlEarfcn <<< "$values")
earfcn=${earfcn%\"} earfcn=${earfcn#\"}
echo "dlFreqInfo = "
jq <<< "$values"

sed -e "s/{{ absFreqPointA }}/$absFreqPointA/"       \
  -e "s/{{ absArfcnPointA }}/$absArfcnPointA/"       \
  -e "s/{{ nrFreqBand }}/$nrFreqBand/"               \
  -e "s/{{ offsetToCarrier }}/$offsetToCarrier/"     \
  -e "s/{{ carrierBw }}/$carrierBw/"                 \
  -e "s/{{ subCarrierSpacing }}/$subCarrierSpacing/" \
  -e "s/{{ bSChannelBw }}/$bSChannelBw/"             \
  -e "s/{{ earfcn }}/$earfcn/"                       \
  -e "s/{{ absFreqSsb }}/$absFreqSsbDl/"                       \
  -e "s/{{ absArfcnSsb }}/$absArfcnSsbDl/" "$RAN_SCRIPTS"/crd/gnb_frequence_dl.yaml.j2 | \
 kubectl apply -f -
echo "The dlcommon resource of GnbFrequency: "
kubectl -n "${PWEKNS:-default}" get freq dlcommon -o=jsonpath="{.spec}"

values=$(
sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$DUCFG" | \
  xq -j '.rpc."edit-config".config.ME.GNBDUFunction.NRCellDU.vsDataContainer.vsData' | \
  xq -j .gnbvs.gnbDuCfg.gnbCellDuVsCfg.ulCfgCmn.ulFreqInfo)
absFreqPointA=$(jq .absFreqPointA <<< "$values")
absFreqPointA=${absFreqPointA%\"} absFreqPointA=${absFreqPointA#\"}
absArfcnPointA=$(jq .absArfcnPointA <<< "$values")
absArfcnPointA=${absArfcnPointA%\"} absArfcnPointA=${absArfcnPointA#\"}
nrFreqBand=$(jq .nrFreqBand <<< "$values")
nrFreqBand=${nrFreqBand%\"} nrFreqBand=${nrFreqBand#\"}
offsetToCarrier=$(jq .subCarrierCfg.offsetToCarrier <<< "$values")
offsetToCarrier=${offsetToCarrier%\"} offsetToCarrier=${offsetToCarrier#\"}
carrierBw=$(jq .subCarrierCfg.carrierBw <<< "$values")
carrierBw=${carrierBw%\"} carrierBw=${carrierBw#\"}
subCarrierSpacing=$(jq .subCarrierCfg.subCarrierSpacing <<< "$values")
subCarrierSpacing=${subCarrierSpacing%\"} subCarrierSpacing=${subCarrierSpacing#\"}
bSChannelBw=$(jq .bSChannelBwUl <<< "$values")
bSChannelBw=${bSChannelBw%\"} bSChannelBw=${bSChannelBw#\"}
earfcn=$(jq .ulEarfcn <<< "$values")
earfcn=${earfcn%\"} earfcn=${earfcn#\"}
pMaxUl=$(jq .pMax <<< "$values")
pMaxUl=${pMaxUl%\"} pMaxUl=${pMaxUl#\"}
addtionalSpectrumEmissionUl=$(jq .addtionalSpectrumEmission <<< "$values")
addtionalSpectrumEmissionUl=${addtionalSpectrumEmissionUl%\"}
addtionalSpectrumEmissionUl=${addtionalSpectrumEmissionUl#\"}
freqShft7p5khzUl=$(jq .freqShft7p5khz <<< "$values")
freqShft7p5khzUl=${freqShft7p5khzUl%\"} freqShft7p5khzUl=${freqShft7p5khzUl#\"}
echo "ulFreqInfo = "
jq <<< "$values"

sed -e "s/{{ absFreqPointA }}/$absFreqPointA/"       \
  -e "s/{{ absArfcnPointA }}/$absArfcnPointA/"       \
  -e "s/{{ nrFreqBand }}/$nrFreqBand/"               \
  -e "s/{{ offsetToCarrier }}/$offsetToCarrier/"     \
  -e "s/{{ carrierBw }}/$carrierBw/"                 \
  -e "s/{{ subCarrierSpacing }}/$subCarrierSpacing/" \
  -e "s/{{ bSChannelBw }}/$bSChannelBw/"             \
  -e "s/{{ earfcn }}/$earfcn/"                       \
  -e "s/{{ pMaxUl }}/$pMaxUl/"                       \
  -e "s/{{ addtionalSpectrumEmissionUl }}/$addtionalSpectrumEmissionUl/"  \
  -e "s/{{ freqShft7p5khzUl }}/$freqShft7p5khzUl/" "$RAN_SCRIPTS"/crd/gnb_frequence_ul.yaml.j2 | \
 kubectl apply -f -
echo "The ulcommon resource of GnbFrequency: "
kubectl -n "${PWEKNS:-default}" get freq ulcommon -o=jsonpath="{.spec}"


# imsi
kubectl get imsi
retVal=$?
if [ "$retVal" -ne 0 ]; then
  kubectl apply -f "$CORE_SCRIPTS"/crd/imsi_crd.yaml
fi
ueInfo=$(
sed -e '1,/]]>]]>/d' -e '1,/]]>]]>/!d' -e "/^]]>]]>$/d" "$AMFCFG" | \
  xq -j '.rpc."edit-config".config.amf.ue_authsec_config')
# jq <<< "$ueInfo"
# {
#   "id": "3",
#   "supi": "3 1 1 4 8 0 1 2 3 4 5 6 7 9 0",
#   "op_key": "12 34 56 00 00 00 00 00 00 00 00 00 00 00 00 00",
#   "opc_key": "12 34 56 00 00 00 00 00 00 00 00 00 00 00 00 00",
#   "auth_key": "12 34 56 00 00 00 00 00 00 00 00 00 00 00 00 00",
#   "integrity": "NIA0",
#   "ciphering": "NEA0",
#   "amf_val": "80 00",
#   "sqn_val": "00 00 00 00 00 00"
# }

apply_k8s_emsi(){
value="$1"
tmplt=${2:-../src/scripts/core/crd/imsi.yaml.j2}
ueid=$(jq .id <<< "$value" | tr -d '"')
supi=$(jq .supi <<< "$value" | tr -d " ")
auth_key=$(jq .auth_key <<< "$value")
op_key=$(jq .op_key <<< "$value")

sed -e "s/{{ name }}/ue-$ueid/"     \
  -e "s/{{ supi }}/$supi/"          \
  -e "s/{{ auth_key }}/$auth_key/"  \
  -e "s/{{ op_key }}/$op_key/" "$tmplt" | kubectl apply -f -
# -e "s/{{ op_key }}/"$op_key"/" $2 | kubectl apply -f -
}

# echo '[{"username":"user1"},{"username":"user2"}]' | jq '. | length'
len=$(jq '. | length' <<< "$ueInfo")
len=$((len-1))
if (( len > 0 )); then
  echo "Got $len UEs"
  for i in $(seq 0 $len); do
    echo "$i"
    ue=$(jq .["$i"] <<< "$ueInfo")
    echo "$ue"
    apply_k8s_emsi "$ue" "$CORE_SCRIPTS"/crd/imsi.yaml.j2
  done
fi
