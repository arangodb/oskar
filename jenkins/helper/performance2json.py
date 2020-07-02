import csv
import json
import datetime as dt

from dateutil import parser as dt_parser
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", help="input file", metavar="FILE")
parser.add_option("-V", "--version-file", dest="version_filename", help="version file", metavar="FILE")
parser.add_option("-d", "--date", dest="date", help="iso date", metavar="DATE")
parser.add_option("-b", "--branch", dest="branch", help="branch", metavar="BRANCH")
parser.add_option("-n", "--name", dest="name", help="branch or tag", metavar="BRANCH-OR-TAG")
parser.add_option("-m", "--mode", dest="mode", help="singleserver or cluster", metavar="MODE")
parser.add_option("-e", "--edition", dest="edition", help="community or enterprise", metavar="EDITION")
parser.add_option("-s", "--size", dest="size", help="tiny, small, medium, big", metavar="SIZE")
parser.add_option("-F", "--type", dest="input_type", help="input format", metavar="TYPE")

(options, args) = parser.parse_args()

current_date = None

if options.date:
        current_date = dt_parser.parse(options.date)

branch = options.branch
name = options.name
mode = options.mode
edition = options.edition
default_size = options.size
version_filename = options.version_filename
version = None
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

if not version:
        if name:
                version = name
        else:
                version = branch

def simple_performance(row):
        global version, current_date, default_size

        size = row[11]

        if not size:
                size = default_size

        if not version:
                version = row[0]

        date = current_date

        if not date:
                date = dt_parser.parse(row[1])

        print(json.dumps({
                "test": {
                        "name": row[2],
                        "average": float(row[3]),
                        "median": float(row[4]),
                        "min": float(row[5]),
                        "max": float(row[6]),
                        "deviation": float(row[7]),
                        "numberRuns": int(row[10])
                },
                "size": {
                        "collection": row[8],
                        "count": int(row[9]),
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


with open(options.filename) as csvfile:
        lines = csv.reader(csvfile, delimiter=',', quotechar='|')
        for row in lines:
                if input_type == "simple-performance":
                        simple_performance(row)
                else:
                        print("unknown output format '%s'" % (input_type))
