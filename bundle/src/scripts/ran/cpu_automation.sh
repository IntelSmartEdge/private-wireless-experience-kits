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

#Setting CPU nums for CPU management
#get cpu info for CRD
namespace=$1
upf_core_num=$(kubectl -n "$namespace" get cpus.pwek.smart.edge.org common -o=jsonpath="{.spec.upf_core_num}"|jq)
cu_core_num=$(kubectl -n "$namespace" get cpus.pwek.smart.edge.org common -o=jsonpath="{.spec.cu_core_num}"|jq)
phy_core_num=$(kubectl -n "$namespace" get cpus.pwek.smart.edge.org common -o=jsonpath="{.spec.phy_core_num}"|jq)
du_core_num=$(kubectl -n "$namespace" get cpus.pwek.smart.edge.org common -o=jsonpath="{.spec.du_core_num}"|jq)
du_core_num=${du_core_num:-8100m}

echo upf_core_num "$upf_core_num"
echo cu_core_num "$cu_core_num"
echo phy_core_num "$phy_core_num"
echo du_core_num "$du_core_num"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo ""
${cmd:-source} "$DIR"/env.sh
echo "$VENDOR_HELM"
helm_charts_home=${VENDOR_HELM:-$DIR}
dir_suffix=$(date +%Y%m%d%H%M%S)
backup=helm_$dir_suffix

VENDOR_PATH=${VENDOR_SCRIPTS:-$helm_charts_home}
cp -rf "$VENDOR_PATH" /tmp/"$backup"
upf_des_path=$helm_charts_home/cn/charts/upf/config/
cu_des_path=$helm_charts_home/cu/config/
phy_des_path=$helm_charts_home/du/du1-l1config/
du_des_path=$helm_charts_home/du/du1-l2config/

#copy wrapper.sh to config dir
cp -Lrf "$VENDOR_PATH"/upf.*  "$upf_des_path"/wrapper.sh
cp -Lrf "$VENDOR_PATH"/cu.*   "$cu_des_path"/wrapper.sh
cp -Lrf "$VENDOR_PATH"/phy.*  "$phy_des_path"/wrapper.sh
cp -Lrf "$VENDOR_PATH"/du.*   "$du_des_path"/wrapper.sh

#upf setting
sed -i -e "/name: upfdp/, \$s/\(limits:$\)/\1\n                cpu: $upf_core_num/" "$helm_charts_home"/cn/charts/upf/templates/deployment.yaml
sed -i -e "/name: upfdp/, \$s/\(requests:$\)/\1\n                cpu: $upf_core_num/" "$helm_charts_home"/cn/charts/upf/templates/deployment.yaml
sed -i -e "s/.*command.*start_upfdp.sh.*$/          command: [ '\/bin\/bash', '\/root\/config_map\/wrapper.sh' ]/g"  "$helm_charts_home"/cn/charts/upf/templates/deployment.yaml
sed -i -e  '/upfcp$/a\
          resources:\
            limits:\
              cpu: 900m\
              memory: 10Gi\
            requests:\
              cpu: 900m\
              memory: 10Gi
' "$helm_charts_home"/cn/charts/upf/templates/deployment.yaml

#cu setting
sed -i -e "/limits:/a\                cpu: $cu_core_num" "$helm_charts_home"/cu/templates/deployment.yaml
sed -i -e "/requests:/a\                cpu: $cu_core_num" "$helm_charts_home"/cu/templates/deployment.yaml
sed -i -e 's/.*args:*/#&/g' "$helm_charts_home"/cu/templates/deployment.yaml
sed -i -e 's/.*\/bin\/bash.*\-\-/#&/g' "$helm_charts_home"/cu/templates/deployment.yaml
sed -i -e  "s/\(.*\)\(imagePullPolicy.*\)/\1\2\n\1command: [ '\/bin\/bash', '\/root\/config_map\/wrapper.sh' ]/g" "$helm_charts_home"/cu/templates/deployment.yaml
sed -i -e  '/volumeMounts:/a\
           - name: bins\
             mountPath: /opt/bins\
             readOnly: false\
           - name: fs\
             mountPath: /sys/fs/cgroup\
             readOnly: false
' "$helm_charts_home"/cu/templates/deployment.yaml

sed -i -e  '/volumes:/a\
        - name: bins\
          hostPath:\
            path: /usr/bin\
        - name: fs\
          hostPath:\
            path: /sys/fs/cgroup
' "$helm_charts_home"/cu/templates/deployment.yaml

#Phy and du setting
#  '0,/a/s/a/e/'
sed -i -e 's/.*cpu:*/#&/g' "$helm_charts_home"/du/values.yaml
sed -i -e '/.*#memory:/s/#//g'  "$helm_charts_home"/du/values.yaml
sed -i -e "/l1:/{n;n;n;s|$|\n      cpu: $phy_core_num|}" "$helm_charts_home"/du/values.yaml
sed -i -e "/l1:/{n;n;n;n;n;n;n;n;s|$|\n      cpu: $phy_core_num|}" "$helm_charts_home"/du/values.yaml

sed -i -e "/l2:/{n;n;n;n;s|$|\n      cpu: $du_core_num|}" "$helm_charts_home"/du/values.yaml
sed -i -e "/l2:/{n;n;n;n;n;n;n;n;n;s|$|\n      cpu: $du_core_num|}" "$helm_charts_home"/du/values.yaml
#ed -i -e "0,/l2:/s/\(.*\)\(hugepages-1Gi.*\)/\1\2\n\1cpu: \"$du_core_num\"/g" "$helm_charts_home"/du/values.yaml
#ed -i -e "0,/l2:/s/\(.*\)\(cpu.*\)/\1\2\n\1memory: 25Gi/g" "$helm_charts_home"/du/values.yaml
sed -i -e 's/.*args:*/#&/g'  "$helm_charts_home"/du/templates/deployment.yaml
sed -i -e 's/.*\/bin\/bash.*\-\-/#&/g' "$helm_charts_home"/du/templates/deployment.yaml
sed -i -e  "s/\(.*\)\(imagePullPolicy.*\)/\1\2\n\1command: [ '\/bin\/bash', '\/mnt\/configs\/wrapper.sh' ]/g" "$helm_charts_home"/du/templates/deployment.yaml
sed -i -e  '1,/\/mnt\/configs\/wrapper.sh/s/\/mnt\/configs\/wrapper.sh/\/root\/config_map\/wrapper.sh/' "$helm_charts_home"/du/templates/deployment.yaml
sed -i -e  '/volumeMounts:/a\
           - name: bins\
             mountPath: /opt/bins\
             readOnly: false\
           - name: fs\
             mountPath: /sys/fs/cgroup\
             readOnly: false
' "$helm_charts_home"/du/templates/deployment.yaml

sed -i -e  '/volumes:/a\
        - name: fs\
          hostPath:\
            path: /sys/fs/cgroup\
        - name: bins\
          hostPath:\
            path: /usr/bin
' "$helm_charts_home"/du/templates/deployment.yaml
