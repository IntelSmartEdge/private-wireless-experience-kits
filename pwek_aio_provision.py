#!/usr/bin/env python3

# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2021 Intel Corporation

""" Provision Smart Edge Private Wireless Experience Kits All in One """

import os
import sys

if __name__ == "__main__":
    sys.path.insert(
        1, os.path.join(os.path.dirname(os.path.realpath(__file__)), "opendek", "scripts", "deploy_esp"))
    import deploy_esp # pylint: disable=import-error
    deploy_esp.run_main("./pwek_aio_config.yml", "Private Wireless Experience Kits All in One")
