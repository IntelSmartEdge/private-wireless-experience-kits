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

FROM alpine:3.17.0_rc1

ARG PWEKPATH=/opt/smartedge/pwek
ENV PWEKPATH=$PWEKPATH

ARG VENDOR=radisys
ENV VENDOR=$VENDOR

ARG VERSION
ENV VERSION=$VERSION

ENV PWEK_SCRIPTS=$PWEKPATH/5gran_entry_point/
ENV DEP_PATH=$PWEKPATH/charts/${VENDOR}_5g_cnf/deployment
ENV RAN_SCRIPTS=$PWEKPATH/5gran_entry_point/$VENDOR/
ENV CORE_SCRIPTS=$PWEKPATH/5gcore_entry_point/$VENDOR/

# Dockerfile will create the directory
# RUN mkdir -p $PWEKPATH \
#   && mkdir -p /$VENDOR/bin \
#   && mkdir -p $PWEK_SCRIPTS \
#   && mkdir -p $DEP_PATH/helm \
#   && mkdir -p $RAN_SCRIPTS \
#   && mkdir -p $CORE_SCRIPTS

ADD bundle.tar.gz /$VENDOR

COPY src/scripts/ $PWEK_SCRIPTS/$VENDOR
COPY helm $DEP_PATH/helm
COPY src/scripts/ran/ $RAN_SCRIPTS
COPY src/scripts/core/ $CORE_SCRIPTS
COPY src/scripts/*.sh /$VENDOR/bin
COPY image/entrypoint.sh /$VENDOR/bin
WORKDIR /$VENDOR/bin
CMD ["/bin/bash","-c","/$VENDOR/bin/entrypoint.sh"]
