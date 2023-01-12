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

CUCHARTF="$VENDOR_HELM"/cu/values.yaml

echo "This is an crypto runtime config plugin."
# echo "Echo env value VENDOR_SCRIPTS: $VENDOR_SCRIPTS"

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Pod
metadata:
  name: get-qat
  labels:
    run: get-qat
spec:
  containers:
  - image: alpine:latest
    command:
    - /bin/sh
    - "-c"
    - "sleep 60m"
    imagePullPolicy: IfNotPresent
    name: alpine
    imagePullPolicy: IfNotPresent
    resources:
      requests:
        qat.intel.com/generic: '2'
      limits:
        qat.intel.com/generic: '2'
EOF
 
kubectl wait pods -n default -l run=get-qat --for condition=Ready --timeout=90s
ret=$?
if [ $ret -ne 0 ]; then
  QATs=$(kubectl exec get-qat -it -- env |grep QAT)
  PCIs=$(echo "$QATs" | cut -d = -f 2)
  echo "$PCIs"
  echo "Error: Can not start a pod to get QAT PCI address."
  echo "You may not start CU with a right QAT PCI address."
  echo "please login the node and run the follow command to configure crypto PCI address" 
  echo "  lspci | grep 'Co-processor: Intel Corporation Device'"
  echo "Pick up 2 PCI addresses and update fastCryptoPort0Pci and fastCryptoPort1Pci in $CUCHARTF" 
  exit 1
fi
 
QATs=$(kubectl exec get-qat -it -- env |grep QAT)
PCIs=$(echo "$QATs" | cut -d = -f 2)
echo "$PCIs"
 
kubectl delete pod get-qat


echo "---- update chart values fastCryptoPort0Pci and fastCryptoPort1Pci in $CUCHARTF from: ----"
yq -o json '.appConfig.fastCryptoPort0Pci' "$CUCHARTF"
yq -o json '.appConfig.fastCryptoPort1Pci' "$CUCHARTF"
 
# 0 means QAT0
num=0
val=$(tr -d '\r' <<< "$QATs" | grep -Po "(?<=QAT${num}=)0000.*")
yq -i '.appConfig.fastCryptoPort0Pci = '"\"$val\"" "$CUCHARTF"
 
# 0 means QAT1
num=1
val=$(tr -d '\r' <<< "$QATs" | grep -Po "(?<=QAT${num}=)0000.*")
yq -i '.appConfig.fastCryptoPort1Pci = '"\"$val\"" "$CUCHARTF"
 
echo "---- to: ----"
yq -o json '.appConfig.fastCryptoPort0Pci' "$CUCHARTF"
yq -o json '.appConfig.fastCryptoPort1Pci' "$CUCHARTF"
