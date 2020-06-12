import csv
import json
import datetime as dt

from dateutil import parser as dt_parser
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-f", "--file", dest="filename", help="input file", metavar="FILE")
parser.add_option("-V", "--version-file", dest="version_filename", help="version file", metavar="FILE")
parser.add_option("-d", "--date", dest="date", help="iso date", metavar="DATE")
parser.add_option("-b", "--branch", dest="branch", help="branch or tag", metavar="BRANCH")
parser.add_option("-m", "--mode", dest="mode", help="singleserver or cluster", metavar="MODE")
parser.add_option("-e", "--edition", dest="edition", help="community or enterprise", metavar="EDITION")

(options, args) = parser.parse_args()

current_date = dt_parser.parse(options.date)
branch = options.branch
mode = options.mode
edition = options.edition
version_filename = options.version_filename
version = None

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
        version = branch

with open(options.filename) as csvfile:
	lines = csv.reader(csvfile, delimiter=',', quotechar='|')
	for row in lines:
		print(json.dumps({
                        "test": {
                                "name": row[0],
                                "average": row[1],
                                "median": row[2],
                                "min": row[3],
                                "max": row[4],
                                "deviation": row[5],
                                "numberRuns": row[8]
                        },
                        "size": {
                                "collection": row[6],
                                "count": row[7],
                                "size": row[9]
                        },
                        "configuration": {
                                "version": version,
                                "branch": branch,
                                "mode": mode,
                                "edition": edition
                        },
                        "isoDate": current_date.isoformat(),
                        "date": current_date.timestamp()
                }))
