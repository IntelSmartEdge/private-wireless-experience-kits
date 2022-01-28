#!/usr/bin/python

# INTEL CONFIDENTIAL
#
# Copyright 2020-2020 Intel Corporation.
#
# This software and the related documents are Intel copyrighted materials, and your use of
# them is governed by the express license under which they were provided to you ("License").
# Unless the License provides otherwise, you may not use, modify, copy, publish,
# distribute, disclose or transmit this software
# or the related documents without Intel's prior written permission.
#
# This software and the related documents are provided as is, with no express or implied warranties,
# other than those that are expressly stated in the License.

"""
Update gNodeB configuration
"""

import argparse
import logging
import os
import sys
import xml.etree.ElementTree as ET
import re
from collections import namedtuple

LOGGER_LEVEL = logging.DEBUG
LOGGER = logging.getLogger(__name__)

ENV_PREFIX = "ENV"

def load_config(path, node):
    """Load configuration from XML file"""
    try:
        tree = ET.parse(path)
    except ET.ParseError as ex:
        logging.error("XML parsing error occurred after loading of %s xml file: %s", path, ex)

    cfg = tree.getroot().find(node)
    return cfg
#

def create_list_from_node(root, tags_list, root_tag):
    """Create list of nested tags from given node"""
    if not list(root):
        tags_list.append(root_tag)

    for child in list(root):
        create_list_from_node(child, tags_list, (root.tag + "/" + child.tag))
#

def update_xml_config_file(src_path, dest_path, node):
    """Update xml configuration"""

    src_cfg = load_config(src_path, node)

    src_cfg_tags = []
    create_list_from_node(src_cfg, src_cfg_tags, src_cfg.tag)

    CfgTag = namedtuple("CfgTag", "xml txt")
    cfg_tags = []
    for tag in src_cfg_tags:
        cfg_tags.append(CfgTag(tag, tag.split('/')[-1]))

    with open(dest_path, "r") as cfg_xml_file:
        xml_content = cfg_xml_file.read()

    for tag in cfg_tags:
        element = src_cfg.find(tag.xml).text
        if ENV_PREFIX in element:
            # Get env variable name from config file
            env_var = os.environ[element.split('.')[1]]
            # Set first occurrence in env var
            element = env_var.split(',')[0]
        full_tag_element_old = "<" + tag.txt + ">.*<"
        full_tag_element_new = ("<" + tag.txt + ">" +
                                element +
                                "<")
        xml_content = re.sub(full_tag_element_old, full_tag_element_new,
                             xml_content, 1)

    with open(dest_path, "w") as cfg_xml_file:
        cfg_xml_file.write(xml_content)
#

def parse_arguments():
    """Parse argument passed to function"""
    parser = argparse.ArgumentParser(
        description="Script will modify gNodeB configuration to match user setup")
    parser.add_argument("-f", "--config-file",
                        help="Path to the XML file that contains gNodeB configuration",
                        required=True)
    parser.add_argument("-p", "--phycfg-xran-file",
                        help="Path to the phycfg_xran.xml file",
                        required=True)
    parser.add_argument("-x", "--xrancfg-sub6-file",
                        help="Path to the xrancfg_sub6.xml file",
                        required=True)
    return parser.parse_args()
#

def main(args):
    """Update gNodeB configuration"""
    logging.basicConfig(level=LOGGER_LEVEL, format='%(levelname)s - %(message)s')
    update_xml_config_file(args.config_file, args.xrancfg_sub6_file, "xrancfg_sub6")
    update_xml_config_file(args.config_file, args.phycfg_xran_file, "phycfg_xran")
    return 0
#

if __name__ == '__main__':
    try:
        sys.exit(main(parse_arguments()))
    except argparse.ArgumentTypeError as exception:
        logging.error("Error while changing gNodeB config files: %s", exception)
        sys.exit(1)
#
