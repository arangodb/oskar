import csv
import json
import datetime as dt
import re
import statistics

from dateutil import parser as dt_parser
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", help="input file", metavar="FILE")
parser.add_option("-V", "--version-file", dest="version_filename", help="version file", metavar="FILE")
parser.add_option("-T", "--version-text", dest="version_textname", help="version text file", metavar="FILE")
parser.add_option("-w", "--force-version", dest="version", help="version", metavar="VERSION")
parser.add_option("-d", "--date", dest="date", help="iso date", metavar="DATE")
parser.add_option("-b", "--branch", dest="branch", help="branch", metavar="BRANCH")
parser.add_option("-n", "--name", dest="name", help="branch or tag", metavar="BRANCH-OR-TAG")
parser.add_option("-m", "--mode", dest="mode", help="singleserver or cluster", metavar="MODE")
parser.add_option("-e", "--edition", dest="edition", help="community or enterprise", metavar="EDITION")
parser.add_option("-s", "--size", dest="size", help="tiny, small, medium, big", metavar="SIZE")
parser.add_option("-F", "--type", dest="input_type", help="input format", metavar="TYPE")

parser.add_option("--collectionsPerDatabase", dest="collections_per_database", help="number of collections created in each iteration", metavar="COL_PER_DB")
parser.add_option("--indexesPerCollection", dest="indexes_per_collection", help="number of indices per collection to be created", metavar="IDX_PER_COL")
parser.add_option("--numberOfShards", dest="no_shards", help="number of shards created on each collection", metavar="NO_SHARDS")
parser.add_option("--replicationFactor", dest="replication_factor", help="replication factor on these collections", metavar="REPL_FACTOR")

(options, args) = parser.parse_args()

current_date = None
headline = []
values = {}

if options.date:
    current_date = dt_parser.parse(options.date)
else:
    current_date = dt.datetime.now()

branch = options.branch
name = options.name
mode = options.mode
edition = options.edition
default_size = options.size
version_filename = options.version_filename
version_textname = options.version_textname
version = options.version
input_type = options.input_type

if version_filename:
    with open(version_filename) as jsonfile:
        j = json.load(jsonfile)

    if not edition:
        edition = j['license']

    if not mode:
        if j['details']['role'] == 'COORDINATOR':
            mode = 'cluster'

    if not version:
        version = j['version']

if version_textname:
    with open(version_textname) as textfile:
        c = 0
        for line in textfile.readlines():
            c += 1
            s = line.strip()

            if c == 1:
                if not version:
                    version = s
            else:
                m = re.search('(license):\W*(.+)$', s)

                if m:
                    if m.group(1):
                        if not edition:
                            edition = m.group(2)

if not version:
    if name:
        version = name
    else:
        version = branch

def simple_performance(row):
    global version, current_date, default_size, branch, mode, edition

    size = "big"

    if len(row) > 11:
        size = row[11]

    if not size:
        size = default_size

    count = 1000000

    if len(row) > 9:
        count = int(row[9])

    if not version:
        version = row[0]

    if not branch:
        if version == "3.4":
            branch = "3.4"
        elif version == "3.5":
            branch = "3.5"
        elif version == "3.6":
            branch = "3.6"
        elif version == "3.7":
            branch = "3.7"
        elif version == "3.8":
            branch = "3.8"
        elif version == "devel":
            branch = "devel"

    date = current_date

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
            "version": version,
            "branch": branch,
            "mode": mode,
            "edition": edition
        },
        "isoDate": date.isoformat(),
        "date": date.timestamp(),
        "ms": 1000 * date.timestamp()
    }))

def simple_performance_cluster(row):
    global version, current_date, branch, mode, edition

    count = row[7]
    date = current_date
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
            "version": version,
            "branch": branch,
            "mode": mode,
            "edition": edition
        },
        "isoDate": date.isoformat(),
        "date": date.timestamp(),
        "ms": 1000 * date.timestamp()
    }))

def ddl_performance_cluster(rownum, row):
    global version, current_date, branch, mode, edition, headline, values, options

    if rownum == 0:
        headline = row
        for header in headline:
            values[header] = []
    elif rownum == -1:
        count = len(values[headline[0]])
        number_runs = len(values[headline[0]])
        date = current_date

        i = 1
        total_list = values[headline[1]]
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
                "collectionCount": options.collections_per_database,
                "indexesPercollection": options.indexes_per_collection,
                "numberOfShards": options.no_shards,
                "replicationFactor": options.replication_factor
            },
            "configuration": {
                "version": version,
                "branch": branch,
                "mode": mode,
                "edition": edition
            },
            "isoDate": date.isoformat(),
            "date": date.timestamp(),
            "ms": 1000 * date.timestamp()
        }

            
        i = 1
        while i < len(headline):
            result['test'][headline[i]] = {
                "average": statistics.fmean(values[headline[i]]),
                "median": statistics.median(values[headline[i]]),
                "min": min(values[headline[i]]),
                "max": max(values[headline[i]]),
                "deviation": {
                    "pst": statistics.pstdev(values[headline[i]]),
                    "pvariance": statistics.pvariance(values[headline[i]]),
                    "stdev": statistics.stdev(values[headline[i]]),
                    "variance": statistics.variance(values[headline[i]])
                },
                "values": values[headline[i]],
                "numberRuns": number_runs
            }
            i += 1
        
        print(json.dumps(result))
    else:
        i = 0
        while i < len(headline):
            values[headline[i]].append(float(row[i]))
            i += 1
        
def coverage(lines):
    global version, current_date, branch

    result = {}
    date = current_date

    for line in lines:
        s = line.strip()

        m = re.search('(lines|branches):\W*([0-9\.]+)%', s)

        if m:
            result[m.group(1)] = m.group(2)

    print(json.dumps({
        "coverage": result,
        "configuration": {
            "version": version,
            "branch": branch
        },
        "isoDate": date.isoformat(),
        "date": date.timestamp(),
        "ms": 1000 * date.timestamp()
    }))


if input_type == "coverage":
    with open(options.filename) as textfile:
        coverage(textfile.readlines())
else:
    with open(options.filename) as csvfile:
        lines = csv.reader(csvfile, delimiter=',', quotechar='|')
        i = 0;
        for row in lines:
            if input_type == "simple-performance":
                simple_performance(row)
            elif input_type == "simple-performance-cluster":
                simple_performance_cluster(row)
            elif input_type == "ddl-performance-cluster":
                ddl_performance_cluster(i, row)
            else:
                print("unknown output format '%s'" % (input_type))
            i += 1
        if input_type == "ddl-performance-cluster":
            ddl_performance_cluster(-1, [])
