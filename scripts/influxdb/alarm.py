import json
import socket
import requests
import pprint
from datetime import datetime

INFLUXDB_HOST = "influxdb.postmates.com"
INFLUXDB_PORT = 8086
INFLUXDB_USER = "root"
INFLUXDB_PASS = "root"
INFLUXDB_DBNAME = "production"

session = requests.Session()

ALARMS = [
    {
        "series": "postmates.evt.metrics.find_courier_request",
        "column": "value",
        "function": "count",
        "interval": "1m"
    }
]


def build_query(alarm):
    function = "{0}({1})".format(alarm['function'], alarm['column'])

    group = "group by time({0})".format(alarm["interval"])

    return "select {0} from {1} {2} limit 10".format(
        function, alarm['series'], group)


def influx_url():
    base_url = "http://{0}:{1}".format(INFLUXDB_HOST, INFLUXDB_PORT)
    return "{0}/db/{1}/series".format(base_url, INFLUXDB_DBNAME)


def query_influx(query):
    params = {
        'q': query,
        'u': INFLUXDB_USER,
        'p': INFLUXDB_PASS
    }

    response = session.request(
        method='GET',
        url=influx_url(),
        params=params)

    return response.json()

for alarm in ALARMS:
    results = query_influx(build_query(alarm))
    for result in results:
        print result['columns']
        for point in result['points']:
            print datetime.fromtimestamp(point[0]/1000)
            print point[1]
