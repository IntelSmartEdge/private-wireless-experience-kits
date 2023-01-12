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


# preparation on pure K8S platform
NOTE: PWEK platform does not need these preparation

## Create Core and RAN CRD

create namespace
```
kubectl create namespace pwek-rdc
```

clone PWEK and change to WPEK directory

```
kubectl apply -f roles/applications/pwek_common/templates/profile_ran_crd.yaml.j2
kubectl apply -f roles/applications/pwek_common/templates/profile_core_crd.yaml.j2
```
##  Create Core and RAN CR
```
pip3 install jinja2

# create RAN
vendor=radisys
fduif0=vf1
mduif=vf2
mcuif=vf3
bduif=vf4
bupfif=vf5
harbor_host=127.0.0.1
harbor_port=30000
fe810=False
yfile=./roles/applications/pwek_common/templates/vendor_ran.yaml.j2

gen_ran_cr(){
yf=$1
[[ "$yf" != ./* && "$yf" != /* ]] && yf="./$yf"
tmplp=${yf%/*}
tmpl=${yf##*/}
cat <<EOF | python3
from jinja2 import Environment, FileSystemLoader

content={
  "pwek_vendor": "$vendor",
  "fronthaul": {
    "du_side": {
      "resourceName": ["$fduif0"]
    }
  },
  "midhaul": {
    "du_side": {
      "resourceName": "$mduif"
    },
    "cu_side": {
      "resourceName": "$mcuif"
    }
  },
  "backhaul": {
    "cu_side": {
      "resourceName": "$bduif"
    },
    "upf_side": {
      "resourceName": "$bupfif"
    }
  },
  "_registry_ip_address": "${harbor_host}",
  "docker_registry_port": "${harbor_port}",
  "fronthaul_e810_enable": $fe810,
}
file_loader = FileSystemLoader("$tmplp")
env = Environment(loader=file_loader)

template = env.get_template("$tmpl")
output=template.render(content)

print(output)
EOF
}

gen_ran_cr $yfile | kubectl apply -f -

# create core
harbor_host=127.0.0.1
harbor_port=30000
yfile=roles/applications/pwek_common/templates/vendor_core.yaml.j2
sed -e "s/{{ pwek_vendor }}/radisys/" \
    -e "s/{{ _registry_ip_address }}/$harbor_host/" \
    -e "s/{{ docker_registry_port }}/$harbor_port/" $yfile | \
    kubectl apply -f -
kubectl get core common
```

# copy heml charts to bundle
after copy
```
ls helm/

```
the output looks as follow:
`cn  cu  du  du-host`

# build
First time build

```
./build.sh
```

NOTE: Second time build, you can use '-i' option to ignore dependency package.

```
./build.sh -i image
```

# install the bundle
```
./installer.sh
```

# show the CLI the bundle provide
```
ls /usr/local/bin/kubectl-*
```
`kubectl ran start` and `kubectl ran stop` are used to start/stop RAN.

`kubectl core start` and `kubectl core stop` are used to start/stop core.

`kubectl push cnf radisys $docker-image` is used to push docker image to harbor. 

# push docker image to harbor
```
kubectl push cnf radisys cu_3.0.5.tar.gz
kubectl push cnf radisys flexran-du-3.0.5.tar.gz
kubectl push cnf radisys flexran-du-oam-3.0.5.tar.gz
kubectl push cnf radisys l1-cpu-2111.tar.gz
kubectl push cnf radisys oamcu_3.0.5.tar.gz
```
