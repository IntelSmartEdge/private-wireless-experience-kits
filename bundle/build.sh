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

# Readme
# This is script is used to generate bundle installer for PWEK.
# Vendors can provider more functions for it.
# Vendors can provider other build methods such as leverage makefile.

# Description:
# The directory of the vendor bundle should look like as follow:
#  ├── build.sh
#  ├── deploy
#  │   └── bundle.yaml.tmpl
#  ├── helm
#  │   └── cn
#  │       └── chart
#  ├── image
#  │   └── scripts
#  │       ├── Dockerfile
#  │       └── entrypoint.sh
#  ├── src
#  │   └── scripts
#  │       ├── core
#  │       ├── env.sh
#  │       ├── post_install.sh
#  │       ├── pre_install.sh
#  │       └── ran
# The ran start/stop/update/status and parameters configure update scripts should be in:
#   src/scripts/ran
# The core start/stop/update/status and parameters configure update scripts should be in:
#   src/scripts/ran

# Steps for tar package installation:
# 1. vendor should run build.sh to generate installer.sh
# 2. vendor deliver installer.sh to customers
# 3. Customers will run installer.sh in install the bundle

# Step for tar package installation:
# 1. vendor should run build.sh to generate container image and kubernets yaml file.
# 2. vendor deliver image and yaml file to customers.
# 3. Customers will push image to harbor registry.
# 4. Customers will run 'kubectl apply -f yaml-file-name' to install the bundle.

CONTAINERD_VERSION=
# https://github.com/containerd/nerdctl/releases/latest
NERDCTL_VERSION=

YQ_VERSION=

VENDOR=radisys
CNF_VERSION=v2.5.2
PWEKNS=pwek-rdc
PWEKPATH=/opt/smartedge/pwek
# for helm chart and offline packages
DEP_PATH="$PWEKPATH"/charts/${VENDOR}_5g_cnf/deployment
PWEK_SCRIPTS="$PWEKPATH"/scripts/
RAN_SCRIPTS="$PWEKPATH"/5gran_entry_point/"$VENDOR"/
CORE_SCRIPTS="$PWEKPATH"/5gcore_entry_point/"$VENDOR"/
CPU_MODE=core # ran, core or manually


DOWNLOAD=yes
ilist="image"
############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Add description of the script functions here."
   echo
   echo "Syntax: scriptTemplate [-h|i|V]"
   echo "options:"
   echo "h     Print this Help."
   echo "i <package>  Ignor download the packages to accelerate build proccss."
   echo "   NOTE: make sure you have download the packages last build."
   echo "V     Print software version and exit."
   echo
}
############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hVi:" option; do
   case "$option" in
      h) # display Help
         Help
         exit;;
      i) # Enter a name
         DOWNLOAD=no
         ilist="$OPTARG";;
      V) # Enter a name
         echo "CNF version is: $CNF_VERSION"
         exit;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done
echo "Need download package? $DOWNLOAD"

mkdir -p package/python3
mkdir -p package/tar

# https://wiki.ith.intel.com/display/ESSE/Containerd
get_latest_vesion() {
  KSURL="$1"
  # curl -Ls -w %{url_effective} -o /dev/null "$KSURL"
  LASTURL=""
  LASTURL=$(curl "$KSURL" -s -L -I -o /dev/null -w '%{url_effective}')
  ret=$?
  if [ $ret -ne 0 ]; then
      LASTURL=$(wget -O /dev/null --content-disposition "$KSURL"  2>&1 |awk '/^Location: /{print $2}')
      ret=$?
      if [ $ret -ne 0 ]; then
          echo "Error: Can not find the latest ksonnet version by wget."
      fi
  fi
  LATES=${LASTURL##*/}
  echo "$LATES"
}

download_url() {
  url="$1"
  echo "download file ${url##*/}"
  if ! [ -e "${url##*/}" ]; then
    wget "$url"
  fi
  if ! [ -e "${url##*/}" ]; then
    curl -L -O "$url"
  fi
}

OS=$(awk '/DISTRIB_ID=/' /etc/*-release | sed 's/DISTRIB_ID=//' | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
VERSION=$(awk '/DISTRIB_RELEASE=/' /etc/*-release | sed 's/DISTRIB_RELEASE=//' | sed 's/[.]0/./')

if [ -z "$OS" ]; then
  OS=$(awk '{print $1}' /etc/*-release | tr '[:upper:]' '[:lower:]')
fi

if [ -z "$VERSION" ]; then
  VERSION=$(awk '{print $3}' /etc/*-release)
fi

echo "$OS, $ARCH, $VERSION"

if [[ "$DOWNLOAD" == "no" ]]; then
  echo "ignore download package for build accelartion, make sure you have download the package last time."
else
  if [[ ${OS} == "ubuntu" ]]
  then
    sudo apt install -y containerd
    sudo apt install -y jq
  else
    sudo yum install -y containerd
    sudo yum install -y jq
  fi

  echo "Download yq"
  KSURL=https://github.com/mikefarah/yq/releases/latest
  lversion=$(get_latest_vesion "$KSURL")
  version=${YQ_VERSION:-$lversion}
  echo "The latest yq version is: $lversion, will download version: $version"
  url=https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_amd64.tar.gz
  download_url "$url"
  mv yq_linux_amd64.tar.gz package/tar

  echo "Download yq python package"
  pip3 download yq -d package/python3/
  echo "Download xmlstarlet python package"
  pip3 download xmlstarlet -d package/python3/
  echo "Download jinja2 python package"
  pip3 download jinja2 -d package/python3/


  echo "=============================="
  KSURL=https://github.com/containerd/containerd/releases/latest
  # wget https://github.com/containerd/containerd/releases/download/v1.6.6/containerd-1.6.6-linux-amd64.tar.gz
  lversion=$(get_latest_vesion "$KSURL")
  version=${CONTAINERD_VERSION:-$lversion}
  echo "The latest containerd version is: $lversion, will download version: $version"
  url=https://github.com/containerd/containerd/releases/download/"$version"/containerd-${version#v}-linux-amd64.tar.gz
  download_url "$url"

  echo "=============================="
  KSURL=https://github.com/containerd/nerdctl/releases/latest
  # wget https://github.com/containerd/nerdctl/releases/download/v0.22.2/nerdctl-0.22.2-linux-amd64.tar.gz
  lversion=$(get_latest_vesion "$KSURL")
  version=${NERDCTL_VERSION:-$lversion}
  echo "The latest nerdctl version is: $lversion, will download version: $version"
  url=https://github.com/containerd/nerdctl/releases/download/${version}/nerdctl-${version#v}-linux-amd64.tar.gz
  download_url "$url"
  echo "Install nerdctl:"
  tar -xzvf ${url##*/}  -C /usr/local/bin

  echo "=============================="
  KSURL=https://github.com/moby/buildkit/releases/latest
  # wget https://github.com/moby/buildkit/releases/download/v0.10.3/buildkit-v0.10.3.linux-amd64.tar.gz
  lversion=$(get_latest_vesion "$KSURL")
  version=${NERDCTL_VERSION:-$lversion}
  echo "The latest nerdctl version is: $lversion, will download version: $version"
  url=https://github.com/moby/buildkit/releases/download/${version}/buildkit-${version}.linux-amd64.tar.gz
  echo "$url"
  download_url "$url"
  echo "Install buildkit:"
  tar -xzvf ${url##*/} -C /usr/local
  # https://github.com/moby/buildkit#quick-start
  pgrep buildkitd
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "No buildkitd is running, start buildkitd"
    sudo buildkitd &
  fi
fi


mkdir -p helm src/scripts/core src/scripts/ran
touch src/scripts/pre_install.sh src/scripts/post_install.sh

echo "Build container image"
# we can leverage kustomization.yaml
VENDOR="$VENDOR" VERSION=${CNF_VERSION} \
  bash deploy/bundle.yaml.tmpl > deploy/bundle.yaml

if [[ "$ilist" == *im* ]]; then
  echo "Ignore to build bundle docker image."
else
  echo "Sometimes you need to login the docker registry, try this command:"
  echo "  nerdctl login --username \$user --password-stdin <<< \$password"
  echo '  jq .auths.\"https://index.docker.io/v1/\".auth /root/.docker/config.json'
  echo "  base64 -d <<< \$auth"
  echo "  export DOCKER_BUILDKIT=1"
  https_proxy=http://child-prc.intel.com:913 \
  http_proxy=http://child-prc.intel.com:913  \
  HTTPS_PROXY=http://child-prc.intel.com:913 \
  HTTP_PROXY=http://child-prc.intel.com:913  \
  nerdctl build -t ${VENDOR}-cnf-bundle:${CNF_VERSION} -f image/Dockerfile . \
    --build-arg PWEKPATH="$PWEKPATH" \
    --build-arg VENDOR="$VENDOR" \
    --build-arg VERSION="$VERSION" \
    --build-arg PWEK_SCRIPTS="$PWEK_SCRIPTS" \
    --build-arg DEP_PATH="$PWEKPATH"/charts/${VENDOR}_5g_cnf/deployment \
    --build-arg RAN_SCRIPTS="$PWEKPATH"/5gran_entry_point/"$VENDOR"/ \
    --build-arg CORE_SCRIPTS="$PWEKPATH"/5gcore_entry_point/"$VENDOR"/
fi

cat << EOF > src/scripts/env.sh
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

export PWEKPATH="$PWEKPATH"
export VENDOR="$VENDOR"
export PWEKNS="$PWEKNS"

export DEP_PATH=\$PWEKPATH/charts/\${VENDOR}_5g_cnf/deployment
export VENDOR_HELM=\${DEP_PATH}/helm
export PWEK_SCRIPTS=${PWEK_SCRIPTS}
export VENDOR_SCRIPTS=\${PWEK_SCRIPTS}\$VENDOR/
export RAN_SCRIPTS=\$PWEKPATH/5gran_entry_point/\$VENDOR/
export CORE_SCRIPTS=\$PWEKPATH/5gcore_entry_point/\$VENDOR/

export CPU_MODE="$CPU_MODE"
EOF

cp src/scripts/env.sh src/scripts/ran/env.sh
cp src/scripts/env.sh src/scripts/core/env.sh

echo "Build tar ball"
rm -rf bundle.tar.gz
tar -cvf bundle.tar helm
tar -uvf bundle.tar src
tar -uvf bundle.tar package
gzip -9 bundle.tar

# run make file firstly
cat << EOF > installer.sh
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

die() {
  echo "There are something wrong during installation, exit!"
  exit 1
}

installer="\$(pwd)/\$(basename \$BASH_SOURCE)"
echo "Start to install bundle by: \$installer"

archive=\$(grep -a -n "__ARCHIVE_BELOW__:\$" \$installer | cut -f1 -d:)
echo "archive is from line: \$archive"

rm -rf "$PWEK_SCRIPTS"
rm -rf "$DEP_PATH"
rm -rf "$RAN_SCRIPTS"
rm -rf "$CORE_SCRIPTS"

mkdir -p "$PWEK_SCRIPTS"/${VENDOR}
mkdir -p "$DEP_PATH"
mkdir -p "$RAN_SCRIPTS"
mkdir -p "$CORE_SCRIPTS"

# echo "setup ENV variables"
# Hardcode here
mkdir -p /tmp/pwek/bundle/radisys 
tail -n +\$((archive + 1)) \$installer | tar --strip-components=2 -xzvf - -C /tmp/pwek/bundle/radisys src/scripts/env.sh
cp /tmp/pwek/bundle/radisys/env.sh "$RAN_SCRIPTS"
cp /tmp/pwek/bundle/radisys/env.sh "$CORE_SCRIPTS"

# install offline package
tail -n +\$((archive + 1)) \$installer | tar -xzvf - -C "$DEP_PATH" package/
echo "Install offline package to $DEP_PATH"

# install scripts
tail -n +\$((archive + 1)) \$installer | tar --strip-components=2 -xzvf - -C ${PWEK_SCRIPTS}/${VENDOR}/ src/scripts/
echo "Install $VENDOR common scripts to ${PWEK_SCRIPTS}/${VENDOR}"

# tail -n +\$((archive + 1)) \$installer | gzip -vdc - | tar -xvf - > /dev/null || die
echo "Run src/scripts/pre_install.sh"
tail -n +\$((archive + 1)) \$installer | tar -xzvf - src/scripts/pre_install.sh | bash

# install helm chart
tail -n +\$((archive + 1)) \$installer | tar -xzvf - -C "$DEP_PATH" helm/
echo "Install helm chart to $DEP_PATH"

# install 5gran scripts
tail -n +\$((archive + 1)) \$installer | tar --strip-components=3 -xzvf - -C "$RAN_SCRIPTS" src/scripts/ran/
echo "Install RAN scripts to $RAN_SCRIPTS"

# install 5gcore scripts
tail -n +\$((archive + 1)) \$installer | tar --strip-components=3 -xzvf - -C "$CORE_SCRIPTS" src/scripts/core/
echo "Install CORE scripts to $CORE_SCRIPTS"

# run some post installation if any
echo "Run src/scripts/post_install.sh"
# tail -n +\$((archive + 1)) \$installer | tar -xzvf - src/scripts/post_install.sh | bash
${PWEK_SCRIPTS}/${VENDOR}/post_install.sh

echo "Installation complete!"
exit 0

__ARCHIVE_BELOW__:
EOF

cat bundle.tar.gz >> installer.sh
chmod a+x installer.sh
echo "Build successfully!"
