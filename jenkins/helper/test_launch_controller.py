#!/bin/env python3
""" read test definition, and generate the output for the specified target """
import argparse
import copy
import sys
import json
from traceback import print_exc
import yaml

from site_config import IS_ARM, IS_WINDOWS, IS_MAC, IS_COVERAGE

from dump_handler import generate_dump_output
from launch_handler import launch

# check python 3
if sys.version_info[0] != 3:
    print("found unsupported python version ", sys.version_info)
    sys.exit()

#pylint: disable=line-too-long disable=broad-except disable=chained-comparison

def filter_tests(args, tests):
    """ filter testcase by operations target Single/Cluster/full """
    for one in tests:
        one['prefix'] = ""
    if args.all:
        return tests

    def list_generator(cluster):
        # pylint: disable=too-many-branches
        filters = []
        if cluster:
            filters.append(lambda test: "single" not in test["flags"])
        else:
            filters.append(lambda test: "cluster" not in test["flags"])

        if args.full:
            filters.append(lambda test: "!full" not in test["flags"])
        else:
            filters.append(lambda test: "full" not in test["flags"])

        if args.gtest:
            filters.append(lambda test: test["name"].startswith("gtest"))

        if not args.enterprise:
            filters.append(lambda test: "enterprise" not in test["flags"])

        if IS_WINDOWS:
            filters.append(lambda test: "!windows" not in test["flags"])

        if IS_MAC:
            filters.append(lambda test: "!mac" not in test["flags"])

        if IS_ARM:
            filters.append(lambda test: "!arm" not in test["flags"])

        if IS_COVERAGE:
            filters.append(lambda test: "!coverage" not in test["flags"])

        if args.no_report:
            print("Disabling report generation")
            args.create_report = False

        filtered = copy.deepcopy(tests)
        for one_filter in filters:
            filtered = filter(one_filter, filtered)
        remaining_tests = list(filtered)
        if cluster:
            # after we filtered for cluster only tests, we now need to make sure
            # that tests are actually launched as cluster tests:
            for one in remaining_tests:
                if not 'cluster' in one['flags']:
                    one['flags'].append('cluster')
        return remaining_tests

    if args.single_cluster:
        res_sg = list_generator(False)
        for one in res_sg:
            one['prefix'] = "sg_"
        res_cl = list_generator(True)
        for one in res_cl:
            one['prefix'] = "cl_"
        return res_sg + res_cl
    return list_generator(args.cluster)

formats = {
    "dump": generate_dump_output,
    "launch": launch,
}

known_flags = {
    "cluster": "this test requires a cluster",
    "single": "this test requires a single server",
    "full": "this test is only executed in full tests",
    "!full": "this test is only executed in non-full tests",
    "gtest": "only the testsuites starting with 'gtest' are to be executed",
    "sniff": "whether tcpdump / ngrep should be used",
    "ldap": "ldap",
    "enterprise": "this tests is only executed with the enterprise version",
    "!windows": "test is excluded from ps1 output",
    "!circleci": "test is excluded on CircleCI",
    "!mac": "test is excluded when launched on MacOS",
    "!arm": "test is excluded when launched on Arm Linux/MacOS hosts",
    "!coverage": "test is excluded when coverage scenario are ran",
    "no_report": "disable reporting"
}

known_parameter = {
    "prefix": 'internal',
    "name": "name of the test suite. This is mainly useful if a set of suites is combined. If not set, defaults to the suite name.",
    "size": "container size to be used in CircleCI",
    "buckets": "number of buckets to use for this test",
    "suffix": "suffix that is appended to the tests folder name",
    "priority": "priority that controls execution order. Testsuites with lower priority are executed later",
    "parallelity": "parallelity how many resources will the job use in the SUT? Default: 1 in Single server, 4 in Clusters",
    "type": "single or cluster flag",
    "full": "whether to spare from a single or full run",
    "sniff": "whether to enable sniffing",
}


def print_help_flags():
    """ print help for flags """
    print("Flags are specified as a single token.")
    for flag, exp in known_flags.items():
        print(f"{flag}: {exp}")

    print("Parameter have a value and specified as param=value.")
    for flag, exp in known_parameter.items():
        print(f"{flag}: {exp}")


def parse_arguments():
    """ argv """
    if "--help-flags" in sys.argv:
        print_help_flags()
        sys.exit()

    parser = argparse.ArgumentParser()
    parser.add_argument("definitions", help="file containing the test definitions", type=str)
    parser.add_argument("-f", "--format", type=str, choices=formats.keys(), help="which format to output",
                        default="launch")
    parser.add_argument("--validate-only", help="validates the test definition file", action="store_true")
    parser.add_argument("--help-flags", help="prints information about available flags and exits", action="store_true")
    parser.add_argument("--cluster", help="output only cluster tests instead of single server", action="store_true")
    parser.add_argument("--single_cluster", help="process cluster cluster and single tests", action="store_true")
    parser.add_argument("--enterprise", help="add enterprise tests", action="store_true")
    parser.add_argument("--no-enterprise", help="add enterprise tests", action="store_true")
    parser.add_argument("--full", help="output full test set", action="store_true")
    parser.add_argument("--gtest", help="only run gtest-suites", action="store_true")
    parser.add_argument("--all", help="output all test, ignore other filters", action="store_true")
    parser.add_argument("--no-report", help="don't create testreport and crash tarballs", type=bool)
    args = parser.parse_args()

    return args


def validate_params(params, is_cluster):
    """ check for argument validity """
    def parse_number(value):
        """ check value """
        try:
            return int(value)
        except Exception as exc:
            raise Exception(f"invalid numeric value: {value}") from exc

    def parse_number_or_default(key, default_value=None):
        """ check number """
        if key in params:
            if isinstance(params[key], int):
                return
            if params[key][0] == '*': # factor the default
                params[key] = default_value * parse_number(params[key][1:])
            else:
                params[key] = parse_number(params[key])
        elif default_value is not None:
            params[key] = default_value

    parse_number_or_default("priority", 250)
    parse_number_or_default("parallelity", 4 if is_cluster else 1)
    parse_number_or_default("buckets")

    return params


def validate_flags(flags):
    """ check whether target flags are valid """
    if "cluster" in flags and "single" in flags:
        raise Exception("`cluster` and `single` specified for the same test")
    if "full" in flags and "!full" in flags:
        raise Exception("`full` and `!full` specified for the same test")


def read_definition_line(line):
    """ parse one test definition line """
    bits = line.split()
    if len(bits) < 1:
        raise Exception("expected at least one argument: <testname>")
    suites, *remainder = bits

    flags = []
    params = {}
    args = []
    arangosh_args = []

    for idx, bit in enumerate(remainder):
        if bit == "--":
            args = remainder[idx + 1:]
            break
        if bit.startswith("--"):
            arangosh_args.append(bit)
        elif "=" in bit:
            key, value = bit.split("=", maxsplit=1)
            params[key] = value
        else:
            flags.append(bit)

    # check all flags
    for flag in flags:
        if flag not in known_flags:
            raise Exception(f"Unknown flag `{flag}` in `{line}`")

    # check all params
    for param in params:
        if param not in known_parameter:
            raise Exception(f"Unknown parameter `{param}` in `{line}`")

    validate_flags(flags)
    params = validate_params(params, 'cluster' in flags)

    return {
        "name": params.get("name", suites),
        "suite": suites,
        "priority": params["priority"],
        "parallelity": params["parallelity"],
        "flags": flags,
        "args": args,
        "arangosh_args": arangosh_args,
        "params": params
    }

def read_yaml_suite(name, suite, definition, testfile_definitions, bucket_name, yaml_struct):
    """ convert yaml representation into the internal one """
    if not 'options' in definition:
        definition['options'] = {}
    flags = []
    params = {}
    arangosh_args = []
    args = []
    if 'args' in definition:
        if not isinstance(definition['args'], dict):
            raise Exception(f"expected args to be a key value list! have: {definition['args']}")
        for key, val in definition['args'].items():
            if key == 'moreArgv':
                args.append(val)
            else:
                args.append(f"--{key}")
                if isinstance(val, bool):
                    args.append("true" if val else "false")
                else:
                    args.append(val)
    if 'arangosh_args' in definition:
        if not isinstance(definition['arangosh_args'], dict):
            raise Exception(f"expected arangosh_args to be a key value list! have: {definition['arangosh_args']}")
        for key, val in definition['arangosh_args'].items():
            arangosh_args.append(f"--{key}")
            if isinstance(val, bool):
                arangosh_args.append("true" if val else "false")
            else:
                arangosh_args.append(val)

    is_cluster = False
    if 'type' in definition['options']:
        if definition['options']['type'] == "cluster":
            is_cluster = True
            flags.append('cluster')
        else:
            flags.append('single')
    size = "medium" if is_cluster else "small"
    size = size if not "size" in params else params['size']
    params = validate_params(definition['options'], is_cluster)

    if 'full' in params:
        flags.append("full" if params["full"] else "!full")
    if 'coverage' in params:
        flags.append("coverage" if params["coverage"] else "!coverage")
    if 'sniff' in params:
        flags.append("sniff" if params["sniff"] else "!sniff")
    if yaml_struct != {}:
        run_job = yaml_struct['add-yaml']['derives-to']
    else:
        run_job = 'run-linux-tests'
    return {
        "bucket": bucket_name,
        "name": params.get("name", suite),
        "suites": suite,
        "suite": suite,
        "size": size,
        "flags": flags,
        "args": args.copy(),
        "priority": params["priority"],
        "arangosh_args": arangosh_args.copy(),
        "params": params.copy(),
        "testfile_definitions": testfile_definitions,
        "run_job": run_job,
        "parallelity": params["parallelity"],
    }

def read_yaml_serial_suite(name, definition, testfile_definitions, bucket_name, yaml_struct):
    """ convert yaml representation into the internal one """
    generated_definition = {
    }
    if 'options' in definition:
        generated_definition['options'] = definition['options']
    args = {}
    generated_name = ""
    if 'args' in definition:
        args = definition['args'].copy()
    if isinstance(definition['suites'][0], str):
        generated_name = ','.join(definition['suites'])
    else:
        suite_strs = []
        options_json = []
        for suite in definition['suites']:
            suite_name = list(suite.keys())[0]
            if 'args' in suite[suite_name]:
                options_json.append(suite[suite_name]['args'])
            suite_strs.append(suite_name)
        generated_name = ','.join(suite_strs)
        args['optionsJson'] = json.dumps(options_json, separators=(',', ':'))
    if args != {}:
        generated_definition['args'] = args
    name = generated_name
    if 'name' in definition:
        name = definition['name']
    return read_yaml_suite(name, generated_name, generated_definition, testfile_definitions, bucket_name, yaml_struct)

def read_yaml_bucket_suite(name, definition, testfile_definitions, bucket_name, yaml_struct):
    """ convert yaml representation into the internal one """
    bucket_name = definition['name']
    ret = []
    for suite in definition['suites']:
        suite_name = list(suite.keys())[0]
        ret.append(read_yaml_suite(suite_name, suite_name, suite[suite_name], testfile_definitions, bucket_name, yaml_struct))
    return ret

def read_definitions(filename):
    """ read test definitions txt """
    tests = []
    has_error = False
    testfile_definitions = {}
    yaml_text = ""
    have_yaml = False
    parsed_yaml = {}
    if filename.endswith(".yml"):
        with open(filename, "r", encoding="utf-8") as filep:
            config = yaml.safe_load(filep)
            filtered_config = []
            for testcase in config:
                suite_name = list(testcase.keys())[0]
                if suite_name == "add-yaml":
                    parsed_yaml = {"add-yaml": copy.deepcopy(testcase["add-yaml"])}
                elif suite_name == "jobProperties":
                    testfile_definitions = copy.deepcopy(testcase["jobProperties"])
                else:
                    filtered_config.append(testcase)
            for testcase in filtered_config:
                suite_name = list(testcase.keys())[0]
                if suite_name == "serial":
                    tests.append(read_yaml_serial_suite(suite_name, testcase, testfile_definitions, None, parsed_yaml))
                elif suite_name == "bucket":
                    tests += read_yaml_bucket_suite(suite_name, testcase, testfile_definitions, None, parsed_yaml)
                    None
                else:
                    tests.append(read_yaml_suite(suite_name, suite_name, testcase[suite_name], testfile_definitions, None, parsed_yaml))
    else:
        with open(filename, "r", encoding="utf-8") as filep:
            for line_no, line in enumerate(filep):
                line = line.strip()
                if line.startswith("#") or len(line) == 0:
                    continue  # ignore comments
                try:
                    test = read_definition_line(line)
                    tests.append(test)
                except Exception as exc:
                    print(f"{filename}:{line_no + 1}: \n`{line}`\n {exc}", file=sys.stderr)
                    has_error = True
    if has_error:
        raise Exception("abort due to errors")
    return tests


def generate_output(args, tests):
    """ generate output """
    if args.format not in formats:
        raise Exception(f"Unknown format `{args.format}`")
    formats[args.format](args, tests)

def main():
    """ entrypoint """
    try:
        args = parse_arguments()
        tests = read_definitions(args.definitions)
        if args.validate_only:
            return  # nothing left to do
        tests = filter_tests(args, tests)
        generate_output(args, tests)
    except Exception as exc:
        print(exc, file=sys.stderr)
        print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
