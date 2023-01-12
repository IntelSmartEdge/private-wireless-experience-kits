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


# This script is used to artifacts infomation in pwek sriov sriovnetworknodestate.
# copy this file to /usr/local/bin/ before use.
# usage:
#   kubectl sriov sriovnetworknodestate get ~[resource]
# or
#   kubectl sriov sriovnetworknodestate get [resource]
# Note:
#   for autocompletion, please ref: https://github.com/kubernetes/kubernetes/issues/74178
#   for template, please ref: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
#   for jq keys and values, please ref: https://stackoverflow.com/questions/34226370/jq-print-key-and-value-for-each-entry-in-an-object
#   for pattern argument: There is a prefix "~" and sufix with substring. It does not support regular expression.


echo "This is a plugin to lable node with interface purpose."

NS=sriov-network-operator

du_f2="intel_sriov_10G_RRU"
cu_f1="intel_sriov_CU"
du_f1="intel_sriov_DU"
ran_ngu="intel_sriov_10G_NGU"
core_ngu="intel_sriov_UPF_IN"
cn_app="intel_sriov_10G_VEDIOSTREAM"
core_n6="intel_sriov_UPF_OUT"

lable_node(){
resource="$1"
label="$2"
nodes=$(kubectl get SriovNetworkNodeState -n ${NS:-default} -o jsonpath="{.items[].metadata.name}")
for i in $nodes; do
  echo "node: $i"
  pfs=$(kubectl get SriovNetworkNodeState -n ${NS:-default} "$i" -o jsonpath="{.spec.interfaces}")
  pfinfo=$(jq ".[]| select((.vfGroups[].policyName | \
           contains(\"$resource\")) or (.vfGroups[].resourceName | contains(\"$resource\"))) | .name" <<< "$pfs")
  nics=$(uniq <<< "$pfinfo")
  nics=${nics//\"/}
  nics=$(tr "\n"  "," <<< "$nics")
  nics=${nics%,}
  if [ -n "$nics" ]; then
    echo "label node: $i with nic.intel.com/${label}=true"
    kubectl label nodes "$i" nic.intel.com/"$label"=true
    echo "annotate node: $i with nic.intel.com/${label}=$nics"
    kubectl annotate node "$i" nic.intel.com/"$label"="$nics"
  else
    echo "not find resource: $resource on node $i, not label and annotate"
  fi
done
}

lable_node "$du_f2" "du_f2"
lable_node "$cu_f1" "cu_f1"
lable_node "$du_f1" "du_f1"
lable_node "$ran_ngu" "ran_ngu"
lable_node "$core_ngu" "core_ngu"
lable_node "$cn_app" "cn_app"
lable_node "$core_n6" "core_n6"
