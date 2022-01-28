#!/usr/bin/python

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

"""
Update AMF/SMF PFD configuration and SM Policy data
"""

import argparse
import logging
import sys
import xml.etree.ElementTree as ET

LOGGER_LEVEL = logging.DEBUG
LOGGER = logging.getLogger(__name__)

def update_pfd_config(filename, local_dn_subnet, app_id):
    """ Update PFD configuration """
    try:
        tree = ET.parse(filename)
    except ET.ParseError as ex:
        logging.error("XML parsing error occurred after loading of %s xml file: %s", filename, ex)

    root = tree.getroot()

    app = root.find(".//*[@applicationId='"+str(app_id)+"']")
    app_parent = root.find(".//*[@applicationId='"+str(app_id)+"']/..")
    app_parent.remove(app)

    new_app_settings = ET.SubElement(app_parent, 'application')
    new_app_settings.set('applicationId', str(app_id))
    new_app_settings.set('pfd-size', '1')

    new_pfd = ET.SubElement(new_app_settings, 'pfd')
    new_pfd.set('pfdContent-size', '4')

    flow_descriptions = [
        'permit out 17 from 0.0.0.0 2000-9000 to '+local_dn_subnet+' 2000-9000',
        'permit in 17 from '+local_dn_subnet+' 2000-9000 to 0.0.0.0 2000-9000',
        'permit out 1 from 0.0.0.0 to '+local_dn_subnet,
        'permit in 1 from '+local_dn_subnet+' to 0.0.0.0'
    ]

    for pfd_id in range(4):
        new_pfd_content = ET.SubElement(new_pfd, 'pfdContent')
        new_pfd_content.set('pfdId', str(pfd_id+1))
        new_pfd_content.set('flowDescriptions', str(flow_descriptions[pfd_id]))

    tree.write(filename)

def update_sm_policy_data(filename, app_id):
    """ Update SM Policy data """
    try:
        tree = ET.parse(filename)
    except ET.ParseError as ex:
        logging.error("XML parsing error occurred after loading of %s xml file: %s", filename, ex)

    root = tree.getroot()

    pcc = root.find(".//pcc[@appId='"+str(app_id)+"']")
    pcc.attrib['tcListId'] = 'tcList1'

    tree.write(filename)

def parse_arguments():
    """ Parse argument passed to function """
    parser = argparse.ArgumentParser(
        description="Script will modify AMF/SMF configuration to match user setup")
    parser.add_argument("-p", "--pfd-config-file",
                        help="Path to the XML file that contains PFD configuration",
                        required=True)
    parser.add_argument("-s", "--sm-policy-data-file",
                        help="Path to the XML file that contains SM Policy Data",
                        required=True)
    parser.add_argument("-l", "--local-dn-subnet",
                        help="IP subnet assigned to Local Data Network pod",
                        required=True)
    parser.add_argument("-a", "--app-id",
                        help="Application ID that should be routed to the Local Data Network",
                        required=True)
    return parser.parse_args()

def main(args):
    """ Update AMF/SMF PFD configuration and SM Policy data """
    logging.basicConfig(level=LOGGER_LEVEL, format='%(levelname)s - %(message)s')
    update_pfd_config(args.pfd_config_file, args.local_dn_subnet, args.app_id)
    update_sm_policy_data(args.sm_policy_data_file, args.app_id)

    return 0

if __name__ == '__main__':
    sys.exit(main(parse_arguments()))
