#!/usr/bin/env python3

""" convert performance test figures CSV->json to upload into arangodb """
import csv
import json
import datetime as dt
import statistics
from optparse import OptionParser

from dateutil import parser as dt_parser

PARSER = OptionParser()
PARSER.add_option("-f", "--file", dest="filename",
                  help="input file", metavar="FILE")
PARSER.add_option("-V", "--version-file", dest="version_filename",
                  help="version file", metavar="FILE")
PARSER.add_option("-w", "--force-version", dest="version",
                  help="version", metavar="VERSION")
PARSER.add_option("-d", "--date", dest="date", help="iso date", metavar="DATE")
PARSER.add_option("-b", "--branch", dest="branch",
                  help="branch", metavar="BRANCH")
PARSER.add_option("-n", "--name", dest="name",
                  help="branch or tag", metavar="BRANCH-OR-TAG")
PARSER.add_option("-m", "--mode", dest="mode",
                  help="singleserver or cluster", metavar="MODE")
PARSER.add_option("-e", "--edition", dest="edition",
                  help="community or enterprise", metavar="EDITION")
PARSER.add_option("-s", "--size", dest="size",
                  help="tiny, small, medium, big", metavar="SIZE")
PARSER.add_option("-F", "--type", dest="input_type",
                  help="input format", metavar="TYPE")

PARSER.add_option("--collectionsPerDatabase", dest="collections_per_database",
                  help="number of collections created in each iteration",
                  metavar="COL_PER_DB")
PARSER.add_option("--indexesPerCollection", dest="indexes_per_collection",
                  help="number of indices per collection to be created",
                  metavar="IDX_PER_COL")
PARSER.add_option("--numberOfShards", dest="no_shards",
                  help="number of shards created on each collection",
                  metavar="NO_SHARDS")
PARSER.add_option("--replicationFactor", dest="replication_factor",
                  help="replication factor on these collections",
                  metavar="REPL_FACTOR")

(OPTIONS, ARGS) = PARSER.parse_args()

CURRENT_DATE = None
HEADLINE = []
VALUES = {}

if OPTIONS.date:
    CURRENT_DATE = dt_parser.parse(OPTIONS.date)
else:
    CURRENT_DATE = dt.datetime.now()

BRANCH = OPTIONS.branch
NAME = OPTIONS.name
MODE = OPTIONS.mode
EDITION = OPTIONS.edition
DEFAULT_SIZE = OPTIONS.size
VERSION_FILENAME = OPTIONS.version_filename
VERSION = OPTIONS.version
INPUT_TYPE = OPTIONS.input_type

if VERSION_FILENAME:
    with open(VERSION_FILENAME) as jsonfile:
        j = json.load(jsonfile)

    if not EDITION:
        EDITION = j['license']

    if not MODE:
        if j['details']['role'] == 'COORDINATOR':
            MODE = 'cluster'

    if not VERSION:
        VERSION = j['version']

if not VERSION:
    if NAME:
        VERSION = NAME
    else:
        VERSION = BRANCH

def simple_performance(row):
    """ translate simple performance output """
    global VERSION, CURRENT_DATE, DEFAULT_SIZE, BRANCH, MODE, EDITION

    size = "big"

    if len(row) > 11:
        size = row[11]

    if not size:
        size = DEFAULT_SIZE

    count = 1000000

    if len(row) > 9:
        count = int(row[9])

    if not VERSION:
        VERSION = row[0]

    if not BRANCH:
        if VERSION == "3.4":
            BRANCH = "3.4"
        elif VERSION == "3.5":
            BRANCH = "3.5"
        elif VERSION == "3.6":
            BRANCH = "3.6"
        elif VERSION == "3.7":
            BRANCH = "3.7"
        elif VERSION == "3.8":
            BRANCH = "3.8"
        elif VERSION == "devel":
            BRANCH = "devel"

    date = CURRENT_DATE

    if not date:
        date = dt_parser.parse(row[1])

    number_runs = 5

    if len(row) > 10:
        number_runs = int(row[10])

    print(json.dumps({
        "test": {
            "name": row[2],
            "average": float(row[3]),
            "median": float(row[4]),
            "min": float(row[5]),
            "max": float(row[6]),
            "deviation": float(row[7]),
            "numberRuns": number_runs
        },
        "size": {
            "collection": row[8],
            "count": count,
            "size": size
        },
        "configuration": {
            "version": VERSION,
            "branch": BRANCH,
            "mode": MODE,
            "edition": EDITION
        },
        "isoDate": date.isoformat(),
        "date": date.timestamp(),
        "ms": 1000 * date.timestamp()
    }))

def simple_performance_cluster(row):
    """ convert the simple performance cluster to json"""
    global VERSION, CURRENT_DATE, BRANCH, MODE, EDITION

    count = row[7]
    date = CURRENT_DATE
    name = row[0]
    number_runs = row[8]
    size = row[9]

    print(json.dumps({
        "test": {
            "name": name,
            "average": float(row[1]),
            "median": float(row[2]),
            "min": float(row[3]),
            "max": float(row[4]),
            "deviation": float(row[5]),
            "numberRuns": number_runs
        },
        "size": {
            "collection": row[6],
            "count": count,
            "size": size
        },
        "configuration": {
            "version": VERSION,
            "branch": BRANCH,
            "mode": MODE,
            "edition": EDITION
        },
        "isoDate": date.isoformat(),
        "date": date.timestamp(),
        "ms": 1000 * date.timestamp()
    }))

def ddl_performance_cluster(rownum, row):
    """ convert the DDL-CSV to json """
    global VERSION, CURRENT_DATE, BRANCH, MODE
    global EDITION, HEADLINE, VALUES, OPTIONS

    if rownum == 0:
        HEADLINE = row
        for header in HEADLINE:
            VALUES[header] = []
    elif rownum == -1:
        count = len(VALUES[HEADLINE[0]])
        number_runs = len(VALUES[HEADLINE[0]])
        date = CURRENT_DATE

        i = 1
        total_list = VALUES[HEADLINE[1]]
        count_monotonic = 0
        while i < len(total_list):
            if total_list[i] >= total_list[i-1]:
                count_monotonic += 1
            i += 1
        result = {
            "test": {
                "name": "ddl"
            },
            "monotonicity": count_monotonic / len(total_list),
            "size": {
                "count": count,
                "collectionCount": OPTIONS.collections_per_database,
                "indexesPercollection": OPTIONS.indexes_per_collection,
                "numberOfShards": OPTIONS.no_shards,
                "replicationFactor": OPTIONS.replication_factor
            },
            "configuration": {
                "version": VERSION,
                "branch": BRANCH,
                "mode": MODE,
                "edition": EDITION
            },
            "isoDate": date.isoformat(),
            "date": date.timestamp(),
            "ms": 1000 * date.timestamp()
        }

        i = 1
        while i < len(HEADLINE):
            result['test'][HEADLINE[i]] = {
                "average": statistics.fmean(VALUES[HEADLINE[i]]),
                "median": statistics.median(VALUES[HEADLINE[i]]),
                "min": min(VALUES[HEADLINE[i]]),
                "max": max(VALUES[HEADLINE[i]]),
                "deviation": {
                    "pst": statistics.pstdev(VALUES[HEADLINE[i]]),
                    "pvariance": statistics.pvariance(VALUES[HEADLINE[i]]),
                    "stdev": statistics.stdev(VALUES[HEADLINE[i]]),
                    "variance": statistics.variance(VALUES[HEADLINE[i]])
                },
                "values": VALUES[HEADLINE[i]],
                "numberRuns": number_runs
            }
            i += 1

        print(json.dumps(result))
    else:
        i = 0
        while i < len(HEADLINE):
            VALUES[HEADLINE[i]].append(float(row[i]))
            i += 1

with open(OPTIONS.filename) as csvfile:
    CSV_LINES = csv.reader(csvfile, delimiter=',', quotechar='|')
    ROW_NUM = 0
    for row_data in CSV_LINES:
        if INPUT_TYPE == "simple-performance":
            simple_performance(row_data)
        elif INPUT_TYPE == "simple-performance-cluster":
            simple_performance_cluster(row_data)
        elif INPUT_TYPE == "ddl-performance-cluster":
            ddl_performance_cluster(ROW_NUM, row_data)
        else:
            print("unknown output format '%s'" % (INPUT_TYPE))
        ROW_NUM += 1
    if INPUT_TYPE == "ddl-performance-cluster":
        ddl_performance_cluster(-1, [])
