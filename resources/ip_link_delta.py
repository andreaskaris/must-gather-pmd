#!/usr/bin/python
# Usage:
# ./ip_link_delta.py $f1 $f2 $interval
# where:
# $f1 - file name of the first sample that was taken with ip -s -s --json link
# $f2 - file name of the second sample that was taken with ip -s -s --json link
# $interval - time (in seconds) elapsed between the 2 samples

import sys
import os
import json


def read_args() -> list:
    """ Parse args and return from file, to file and interval (as an int) """
    if len(sys.argv) != 4:
        raise Exception("Invalid argument length. Provide before file, after "
                        "file and interval in seconds between both samples")
    for i in [1, 2]:
        if not os.path.isfile(sys.argv[i]):
            raise Exception("Invalid file name. '{}' is not a valid file".
                            format(sys.argv[i]))
    try:
        interval = int(sys.argv[3])
    except Exception:
        raise Exception("Invalid interval provided. '{}' must be numeric.".
                        format(sys.argv[3]))
    return [sys.argv[1], sys.argv[2], interval]


def get_interface(interfaces: list, interface_name: str) -> list:
    """Skim the provided list of interfaces for interface_name and return the
    entry.
    """
    for interface in interfaces:
        if interface['ifname'] == interface_name:
            return interface
    return []


def get_delta(before_interface_list: list, after_interface_list: list,
              interval: int) -> list:
    """Calculate the delta of interface counters between 2 lists which are
    the result from ip -s -s --json link and return both the total delta and
    the average

    Keyword arguments:
    before_interface_list -- the first sample that was taken with
                             ip -s -s --json link
    after_interface_list  -- the second sample that was taken with
                             ip -s -s --json link
    interval              -- the time in seconds elapsed between the 2 samples
    """
    delta = {}
    for before_interface in before_interface_list:
        # Get before and after interface.
        interface_name = before_interface['ifname']
        after_interface = get_interface(after_interface_list, interface_name)
        if len(after_interface) == 0:
            continue

        # Get before and after interface stats.
        before_interface_stats = before_interface["stats64"]
        after_interface_stats = after_interface["stats64"]

        delta[interface_name] = {}
        for direction in ["rx", "tx"]:
            # Make sure that direction can be found in both before and after.
            if (direction not in before_interface_stats or
                    direction not in after_interface_stats):
                continue
            delta[interface_name][direction] = {}

            for counter, value in before_interface_stats[direction].items():
                # Make sure that counter can be found in both before and after.
                if counter not in after_interface_stats[direction]:
                    continue

                diff = after_interface_stats[direction][counter] - value
                delta[interface_name][direction][counter] = {
                        "delta_total": diff,
                        "delta_average": diff / interval,
                        }
    return delta


try:
    before_filename, after_filename, interval = read_args()
except Exception as e:
    print("Could not parse args: {}".format(e))
    exit(1)

before_file = open(before_filename)
after_file = open(after_filename)
before_interface_list = json.load(before_file)
after_interface_list = json.load(after_file)
before_file.close()
after_file.close()


print(json.dumps(get_delta(before_interface_list, after_interface_list,
                           interval)))
