#!/usr/bin/env python3
""" convert testresult CSVs to JSON """
#pylint: disable=too-many-instance-attributes,too-many-arguments,too-many-locals

import csv
import json
import datetime as dt
import statistics
import sys
from abc import abstractmethod, ABC

from dateutil import parser as dt_parser
import click


class CSVTranslator(ABC):
    """ class providing the base algorithm to iterate CSV Files """
    def __init__(self,
                 csv_filename,
                 version_filename,
                 version_textname,
                 version,
                 date,
                 branch,
                 name,
                 mode,
                 edition,
                 size,
                 collections_per_database,
                 indexes_per_collection,
                 no_shards,
                 replication_factor):

        self.headline = []
        self.values = {}

        self.current_date = None

        if date:
            self.current_date = dt_parser.parse(date)
        else:
            self.current_date = dt.datetime.now()

        self.branch = branch
        self.name = name
        self.mode = mode
        self.edition = edition
        self.default_size = size
        self.version_filename = version_filename
        self.version_textname = version_textname
        self.version = version
        self.csv_filename = csv_filename

        self.collections_per_database = collections_per_database
        self.indexes_per_collection = indexes_per_collection
        self.no_shards = no_shards
        self.replication_factor = replication_factor

    def load_version_file(self):
        """ the version file contains information about the SUT, load it. """
        j = None
        if self.version_filename:
            with open(self.version_filename) as jsonfile:
                j = json.load(jsonfile)

            if not self.edition:
                print(self.edition)
                self.edition = j['license']

            if not self.mode:
                if j['details']['role'] == 'COORDINATOR':
                    self.mode = 'cluster'

            if not self.version:
               self.version = j['version']

            if not self.version:
                if self.name:
                    self.version = self.name
                else:
                    self.version = self.branch
        elif self.version_textname:
            with open(self.version_textname) as textfile:
                c = 0
                for line in textfile.readlines():
                    c += 1
                    s = line.strip()

                if c == 1:
                    if not version:
                        self.version = s
                else:
                    m = re.search('(license):\W*(.+)$', s)

                    if m:
                        if m.group(1):
                            if not edition:
                                self.edition = m.group(2)

    def process_csv_file(self):
        """ load the CSV file and iterate it line by line """
        with open(self.csv_filename) as csvfile:
            lines = csv.reader(csvfile, delimiter=',', quotechar='|')
            row_num = 0
            for row_data in lines:
                self.process_csv_line(row_num, row_data)
                row_num += 1
            self.seal_file()

    @abstractmethod
    def process_csv_line(self, row_num, row_data):
        """ process one csv line """

    def seal_file(self):
        """ invoked after the file has been processed """

class SimplePerformance(CSVTranslator):
    """ process simple perfomance tests CSV-Files """
    def process_csv_line(self, row_num, row_data):

        size = "big"
        if len(row_data) > 11:
            size = row_data[11]
        if not size:
            size = self.default_size

        count = 1000000
        if len(row_data) > 9:
            count = int(row_data[9])

        if not self.version:
            self.version = row_data[0]

        if not self.branch:
            if self.version == "3.4":
                self.branch = "3.4"
            elif self.version == "3.5":
                self.branch = "3.5"
            elif self.version == "3.6":
                self.branch = "3.6"
            elif self.version == "3.7":
                self.branch = "3.7"
            elif self.version == "3.8":
                self.branch = "3.8"
            elif self.version == "devel":
                self.branch = "devel"

        date = self.current_date
        if not date:
            date = dt_parser.parse(row_data[1])

        number_runs = 5
        if len(row_data) > 10:
            number_runs = int(row_data[10])

        print(json.dumps({
            "test": {
                "name": row_data[2],
                "average": float(row_data[3]),
                "median": float(row_data[4]),
                "min": float(row_data[5]),
                "max": float(row_data[6]),
                "deviation": float(row_data[7]),
                "numberRuns": number_runs
            },
            "size": {
                "collection": row_data[8],
                "count": count,
                "size": size
            },
            "configuration": {
                "version": self.version,
                "branch": self.branch,
                "mode": self.mode,
                "edition": self.edition
            },
            "isoDate": date.isoformat(),
            "date": date.timestamp(),
            "ms": 1000 * date.timestamp()
        }))

class SimplePerformanceCluster(CSVTranslator):
    """ process simple cluster perfomance tests CSV-Files """
    def process_csv_line(self, row_num, row_data):
        count = row_data[7]
        date = self.current_date
        name = row_data[0]
        number_runs = row_data[8]
        size = row_data[9]

        print(json.dumps({
            "test": {
                "name": name,
                "average": float(row_data[1]),
                "median": float(row_data[2]),
                "min": float(row_data[3]),
                "max": float(row_data[4]),
                "deviation": float(row_data[5]),
                "numberRuns": number_runs
            },
            "size": {
                "collection": row_data[6],
                "count": count,
                "size": size
            },
            "configuration": {
                "version": self.version,
                "branch": self.branch,
                "mode": self.mode,
                "edition": self.edition
            },
            "isoDate": date.isoformat(),
            "date": date.timestamp(),
            "ms": 1000 * date.timestamp()
        }))

class DDLPerformanceCluster(CSVTranslator):
    """ process Cluster DDL perfomance tests CSV-Files """
    def process_csv_line(self, row_num, row_data):
        if row_num == 0:
            self.headline = row_data
            for header in self.headline:
                self.values[header] = []
        else:
            i = 0
            while i < len(self.headline):
                self.values[self.headline[i]].append(float(row_data[i]))
                i += 1

    def seal_file(self):
        date = self.current_date

        i = 1
        total_list = self.values[self.headline[1]]
        count = len(total_list)
        count_monotonic = 0
        while i < count:
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
                "collectionCount": self.collections_per_database,
                "indexesPercollection": self.indexes_per_collection,
                "numberOfShards": self.no_shards,
                "replicationFactor": self.replication_factor
            },
            "configuration": {
                "version": self.version,
                "branch": self.branch,
                "mode": self.mode,
                "edition": self.edition
            },
            "isoDate": date.isoformat(),
            "date": date.timestamp(),
            "ms": 1000 * date.timestamp()
        }

        i = 1
        while i < len(self.headline):
            name = self.headline[i]
            test_values = self.values[name]
            result['test'][name] = {
                "average": statistics.fmean(test_values),
                "median": statistics.median(test_values),
                "min": min(test_values),
                "max": max(test_values),
                "deviation": {
                    "pst": statistics.pstdev(test_values),
                    "pvariance": statistics.pvariance(test_values),
                    "stdev": statistics.stdev(test_values),
                    "variance": statistics.variance(test_values)
                },
                "values": test_values,
                "numberRuns": count
            }
            i += 1

        print(json.dumps(result))

class Coverage():
    def __init__(self,
                 csv_filename,
                 version_filename,
                 version,
                 date,
                 branch,
                 name,
                 mode,
                 edition,
                 size,
                 collections_per_database,
                 indexes_per_collection,
                 no_shards,
                 replication_factor):
        self.version = version
        self.branch = branch
        self.current_date = None

        if date:
            self.current_date = dt_parser.parse(date)
        else:
            self.current_date = dt.datetime.now()

    def load_version_file(self):
        pass

    def process_csv_file():
        lines = []
        with open(options.filename) as textfile:
            lines = textfile.readlines()

        result = {}
        date = self.current_date

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


@click.command()
@click.option("-f", "--file", "filename", help="input file")
@click.option("-V", "--version-file", "version_filename",
              help="version file")
@click.option("-T", "--version-text", "version_textname",
              help="version text file")
@click.option("-w", "--force-version", "version",
              help="version")
@click.option("-d", "--date", "date", help="iso date")
@click.option("-b", "--branch", "branch",
              help="branch")
@click.option("-n", "--name", "name",
              help="branch or tag")
@click.option("-m", "--mode", "mode",
              help="singleserver or cluster")
@click.option("-e", "--edition", "edition",
              help="community or enterprise")
@click.option("-s", "--size", "size",
              help="tiny, small, medium, big")
@click.option("-F", "--type", "input_type",
              help="input format")

@click.option("--collectionsPerDatabase", "collections_per_database",
              help="number of collections created in each iteration")
@click.option("--indexesPerCollection", "indexes_per_collection",
              help="number of indices per collection to be created")
@click.option("--numberOfShards", "no_shards",
              help="number of shards created on each collection")
@click.option("--replicationFactor", "replication_factor",
              help="replication factor on these collections")
#pylint: disable=no-value-for-parameter
def convert_file(filename,
                 version_filename,
                 version_textname,
                 version,
                 date,
                 branch,
                 name,
                 mode,
                 edition,
                 size,
                 input_type,
                 collections_per_database,
                 indexes_per_collection,
                 no_shards,
                 replication_factor):
    """ main """
    create_class = None
    if input_type == "simple-performance":
        create_class = SimplePerformance
    elif input_type == "simple-performance-cluster":
        create_class = SimplePerformanceCluster
    elif input_type == "ddl-performance-cluster":
        create_class = DDLPerformanceCluster
    elif input_type == "coverage":
        create_class = Coverage
    else:
        print("unknown output format '%s'" % (input_type))
        return 1

    inst = create_class(filename,
                        version_filename,
                        version_textname,
                        version,
                        date,
                        branch,
                        name,
                        mode,
                        edition,
                        size,
                        collections_per_database,
                        indexes_per_collection,
                        no_shards,
                        replication_factor)
    inst.load_version_file()
    inst.process_csv_file()
    return 0

if __name__ == "__main__":
    sys.exit(convert_file())
