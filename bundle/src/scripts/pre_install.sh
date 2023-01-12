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

echo 'This is pre install'

cur=$(dirname "$(readlink -f "$0")")
echo "current dir is $cur"

# https://xmlstarlet.readthedocs.io/en/latest/usage.html
# pip install xmlstarlet

# https://unix.stackexchange.com/questions/627048/use-xmlstarlet-to-remove-an-entire-element-that-matches-an-attribute-value
# install xq, yq include xq
# sudo pip3 install yq
# sudo pip install install xmlstarlet

OS=$(awk '/DISTRIB_ID=/' /etc/*-release | sed 's/DISTRIB_ID=//' | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
VERSION=$(awk '/DISTRIB_RELEASE=/' /etc/*-release | sed 's/DISTRIB_RELEASE=//' | sed 's/[.]0/./')
# CPU_MODE=core  # auto or manually

if [ -z "$OS" ]; then
  OS=$(awk '{print $1}' /etc/*-release | tr '[:upper:]' '[:lower:]')
fi

if [ -z "$VERSION" ]; then
  VERSION=$(awk '{print $3}' /etc/*-release)
fi

echo "$OS", "$ARCH", "$VERSION"

# if [[ ${OS} == "ubuntu" ]]
# then
#   sudo apt-get update
#   sudo apt-get install xmlstarlet
# else
#   sudo yum -y install xmlstarlet
# fi

# delete PLMN
# xmlstarlet ed -L -N x="urn:com:radisys:fgc:yang:upf-function" -d "//*/x:plmnList[x:mcc[contains(text(),460)] and x:mnc[contains(text(),11)]]" test.xml
# xq: -i/--in-place can only be used with -y/-Y
# xq -x --arg ep "0.0.0.0" 'del(."upf-function"."upf-profile".plmnList[] | select(.mcc | contains("460")) | select(.mnc | contains("11")))' b.xml

delete_plmn()
{
MCC=${1:0:3}
MNC=${1:3:5}
cat <<EOF | python3
import xmlstarlet
xmlstarlet.edit(
  "-L", "-N", "x=urn:com:radisys:fgc:yang:upf-function",
  "-d", "//*/x:plmnList[x:mcc[contains(text(),$MCC)] and x:mnc[contains(text(),$MNC)]]",
  "./test.xml")
EOF
}

# Hardcode here
${cmd:-source} /tmp/pwek/bundle/radisys/env.sh

TMP_INS=/tmp/"$VENDOR"/installer
mkdir -p "$TMP_INS" 
tar -xzvf "$DEP_PATH"/package/tar/yq_linux_amd64.tar.gz -C "$TMP_INS"
# tar -xzvf "$DEP_PATH"/package/tar/yq_linux_amd64.tar.gz -O | bash install-man-page.sh
mv "$TMP_INS"/yq_linux_amd64 /usr/local/bin/yq
cd "$TMP_INS" && ./install-man-page.sh 
cd - || exit
pip3 install "$DEP_PATH"/package/python3/*.whl
