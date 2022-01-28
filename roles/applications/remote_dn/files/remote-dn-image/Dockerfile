# INTEL CONFIDENTIAL
#
# Copyright 2020-2020 Intel Corporation.
#
# This software and the related documents are Intel copyrighted materials, and your use of
# them is governed by the express license under which they were provided to you ("License").
# Unless the License provides otherwise, you may not use, modify, copy, publish, distribute,
# disclose or transmit this software or the related documents without Intel's prior written permission.
#
# This software and the related documents are provided as is, with no express or implied warranties,
# other than those that are expressly stated in the License.

FROM alpine:3.12.0

ENV http_proxy=$http_proxy
ENV https_proxy=$https_proxy
ENV no_proxy=$no_proxy

RUN apk update && apk upgrade && \
    apk add ethtool tcpdump sudo
ARG username=remote-dn
ARG user_dir=/home/$username

RUN adduser -h $user_dir -s /bin/bash --disabled-password $username
RUN addgroup sudo
RUN addgroup $username sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER $username
WORKDIR $user_dir
COPY run_remote_dn.sh ./run_remote_dn.sh
RUN sudo chmod +x run_remote_dn.sh
