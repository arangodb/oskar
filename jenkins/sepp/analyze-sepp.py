import itertools
import json
import os
import statistics
import time


def calcStats(data, name):
    data = list(map(lambda x: x[name], data))
    return {
        "avg": statistics.mean(data),
        "stddev": statistics.pstdev(data),
        "min": min(data),
        "max": max(data)
    }


def calcResult(group):
    data = list(group)
    result = {}
    for f in ['throughput', 'databaseSize', 'operations']:
        result[f] = calcStats(data, f)
    return result


results = []
date = int(time.time())

with open("version.json", 'r') as f:
    version = json.load(f)


def generateResult(file, func):
    with open(file, 'r') as f:
        data = json.load(f)

    def key_f(x): return x['config']
    for key, group in itertools.groupby(data, key_f):
        (config, name) = func(key)

        result = calcResult(group)
        result = {
            "base": os.environ["BASE_BRANCH"],
            "arangodb": os.environ["ARANGODB_BRANCH"],
            "enterprise": os.environ["ENTERPRISE_BRANCH"],
            "config": config,
            "fullConfig": key,
            "result": result,
            "name": name,
            "date": int(time.time()),
            "version": version
        }
        results.append(result)


def generateInsertResults():
    def func(key):
        threads = key['workload']['insert']['threads']
        docSize = key['workload']['insert']['default']['documentModifier']['s']['randomString']['size']
        config = {
            "documentSize": docSize,
            "threads": threads
        }
        return (config, f"insert-t{threads}-s{docSize}")
    generateResult('./insert-result.json', func)


def generateIterateResults():
    def func(key):
        threads = key['workload']['iterate']['threads']
        docSize = key['setup']['prefill']['testcol']['default']['documentModifier']['s']['randomString']['size']
        config = {
            "documentSize": docSize,
            "threads": threads
        }
        return (config, f"iterate-t{threads}-s{docSize}")
    generateResult('./iterate-result.json', func)


generateInsertResults()
generateIterateResults()
print(json.dumps(results))
