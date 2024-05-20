#!/usr/bin/env python
from optparse import OptionParser
import shlex
import subprocess
import os
import sys
import re
import json
import ast
import pprint

ENABLE_LOG = False


def log(string):
    if ENABLE_LOG:
        print string


def main():
    event_names = fetch_event_names()
    # print event_names

    filtered_event_names = filter_event_names(event_names)
    log(filtered_event_names)

    start = "20150228"
    end = "20150302"

    for event_name in filtered_event_names:
        print fetch_events(event_name, start, end)


def fetch_event_names():
    oxctl_path = "/postmates/virtualenv.d/system/bin/oxctl"
    host = "10.1.254.174:3513"

    # get event names using oxctl in json format
    cmd_line = "{0} -H {1} -r".format(oxctl_path, host)
    cmd_output = os.popen(cmd_line).read().strip()

    json_obj = ast.literal_eval(cmd_output)
    event_names = json_obj['events'].keys()

    return event_names


def filter_event_names(event_names):
    skip_event_type = set([

    ])

    match_event_type = set([
        '^postmates.evt.metrics'])

    def matches_in_set(name, match_set):
        for match in match_set:
            if re.match(match, name) is False:
                return False

        return True

    return_event_names = []

    for event_name in event_names:
        should_include = True

        for skip_type in skip_event_type:
            if re.match(skip_type, event_name):
                should_include = False
                break

        if should_include:
            for etype in match_event_type:
                if re.match(etype, event_name):
                    return_event_names.append(event_name)
                    break

    return return_event_names


def fetch_events(event_name, start, end):
    postal_ox_path = "python /postmates/sbin/postal-ox-logs"
    oxstash_path = "/postmates/virtualenv.d/system/bin/oxstash"

    fetch_cmd = "{} cat {} --start={} --end={}".format(
        postal_ox_path, event_name, start, end)
    log("Fetching logs for {} event".format(event_name))
    log("Command line to fetch logs {}".format(fetch_cmd))

    cmd_output = os.popen(fetch_cmd).read().strip()
    return cmd_output


if __name__ == "__main__":
    main()
