#!/bin/env python3
""" read test definition, and generate the output for the specified target """
import argparse
from datetime import datetime
import sys, os
from pathlib import Path
import platform
import pprint
from threading  import Thread, Lock
import time
import psutil
import shutil
from async_client import (
    CliExecutionException,
    ArangoCLIprogressiveTimeoutExecutor,
    dummy_line_result,
)
IS_WINDOWS = platform.win32_ver()[0] != ""
SUCCESS = True
RUNNING_SUITES = []
pp = pprint.PrettyPrinter(indent=4)

all_tests = []
#pylint: disable=line-too-long disable=broad-except

# check python 3
if sys.version_info[0] != 3:
    print("found python version ", sys.version_info)
    sys.exit()

def get_workspace():
    if 'WORKDIR' in os.environ:
        return Path(os.environ['WORKDIR'])
    return Path.cwd() / 'work'
    
class TestConfig():
    def __init__(self):
        """ defaults for test config """
        self.parallelity = 3
        self.db_count = 100
        self.db_count_chunks = 5
        self.min_replication_factor = 2
        self.max_replication_factor = 3
        self.data_multiplier = 4
        self.collection_multiplier = 1
        self.launch_delay = 1.3
        self.single_shard = False
        self.db_offset = 0
        self.progressive_timeout = 100
        self.weight = 1000
        self.args = []
        self.suite = ""
        self.name = ""
        self.log = ''
        self.crashed = True
        self.success = False
        self.structured_results = ""
        self.summary = ""

    def expand_vars(self, cfg, flags):
        self.base_logdir = cfg.test_report_dir / self.name
        if not self.base_logdir.exists():
            self.base_logdir.mkdir()
        self.log_file =  cfg.run_root / f'{self.name}.log'
        self.summary_file = self.base_logdir / 'testfailures.txt'
        self.crashed_file = self.base_logdir / 'UNITTEST_RESULT_CRASHED.json'
        self.success_file = self.base_logdir / 'UNITTEST_RESULT_EXECUTIVE_SUMMARY.json'
        self.report_file =  self.base_logdir / 'UNITTEST_RESULT.json'
        self.base_testdir = cfg.test_data_dir/ self.name

        new_args = [];
        for param in self.args:
            if param.startswith('$'):
                paramname = param[1:]
                if paramname in os.environ:
                    new_args += os.environ[paramname].split(' ')
                else:
                    print("Error: failed to expand environment variable: '" + param + "' for '" + self.name + "'")
            else:
                new_args.append(param)
        new_args += ['--coreCheck', 'true', '--disableMonitor', 'true', '--writeXmlReport', 'true']


        if 'filter' in os.environ:
            new_args += ['--test', os.environ['filter']]
        if 'sniff' in flags:
            if IS_WINDOWS:
                new_args += ['--sniff', 'true',
                             '--sniffProgram',  os.environ['TSHARK'],
                             '--sniffDevice', os.environ['dumpDevice']]
            else:
                new_args += ['--sniff', 'sudo']
        
        if 'SKIPNONDETERMINISTIC' in os.environ:
            new_args += ['--skipNondeterministic', os.environ['SKIPNONDETERMINISTIC']]
        if 'SKIPTIMECRITICAL' in os.environ:
            new_args += ['--skipTimeCritical', os.environ['SKIPTIMECRITICAL']]

        if 'BUILDMODE' in os.environ:
            new_args += [ '--buildType',  os.environ['BUILDMODE'] ]
 
        if 'dumpAgencyOnError' in os.environ:
            new_args += [ '--dumpAgencyOnError', os.environ['dumpAgencyOnError']]
        if 'portBase' in os.environ:
            new_args += [ '--minPort', os.environ['portBase'],
                          '--maxPort', str(int(os.environ['portBase']) + 99)]
        if 'SKIPGREY' in os.environ:
            new_args += [ '--skipGrey', os.environ['SKIPGREY']]
        if 'ONLYGREY' in os.environ:
            new_args += [ '--onlyGrey', os.environ['ONLYGREY']]
        self.args = new_args

        if 'vst' in flags:
            new_args += [ '--vst', 'true']
        if 'ssl' in flags:
            new_args += [ '--protocol', 'ssl']
        if 'http2' in flags:
            new_args += [ '--http2', 'true']
        if 'encrypt' in flags:
            new_args += [ '--encryptionAtRest', 'true']
        
    def __repr__(self):
        return """
        {0.name} => {0.parallelity}, {0.weight}, -- {1}""".format(
            self, ' '.join(self.args))

class config:
    def __init__(self, definition_file):
        if definition_file.is_file():
            definition_file = definition_file.parent
        base_source_dir = (definition_file / '..').resolve()
        bin_dir = (base_source_dir / 'build' / 'bin').resolve()
        if IS_WINDOWS:
            for target in ['RelWithdebInfo', 'Debug']:
                if (bin_dir / target).exists():
                    bin_dir = bin_dir / target

        self.cfgdir = base_source_dir / 'etc' / 'relative'
        self.bin_dir = bin_dir
        self.base_path = base_source_dir
        self.passvoid = ''
        self.run_root = base_source_dir / 'testrun'
        if self.run_root.exists():
            shutil.rmtree(self.run_root)
        self.test_data_dir = self.run_root / 'run'
        self.test_data_dir.mkdir(parents=True)
        self.test_report_dir = self.run_root / 'report'
        self.test_report_dir.mkdir(parents=True)

class ArangoshExecutor(ArangoCLIprogressiveTimeoutExecutor):
    """configuration"""

    def __init__(self, config, slot_lock):
        self.slot_lock = slot_lock
        self.read_only = False
        super().__init__(config, None)

    
    def run_testing(self,
                    testcase,
                    testing_args,
                    timeout,
                    directory,
                    logfile,
                    verbose
                    ):
       # pylint: disable=R0913 disable=R0902
        """ testing.js wrapper """
        global RUNNING_SUITES
        print('------')
        print(testing_args)
        args = [
            '-c', str(self.cfg.cfgdir / 'arangosh.conf'),
            '--log.level', 'warning',
            "--log.level", "v8=debug",
            '--server.endpoint', 'none',
            '--javascript.allow-external-process-control', 'true',
            '--javascript.execute', self.cfg.base_path / 'UnitTests' / 'unittest.js',
            ]
        run_cmd = args +[
            '--',
            testcase,
            '--testOutput', directory ] + testing_args
        try:
            return self.run_arango_tool_monitored(
                self.cfg.bin_dir / "arangosh",
                run_cmd,
                timeout,
                dummy_line_result,
                verbose,
                False,
                True,
                logfile
            )
        except CliExecutionException as ex:
            print(ex)
            return False

def testing_runner(testing_instance, this, arangosh):
    """ operate one makedata instance """
    global SUCCESS
    os.environ['TMPDIR'] = str(this.base_testdir)
    os.environ['TEMP'] = str(this.base_testdir) # TODO howto wintendo?
    this.success = arangosh.run_testing(this.suite,
                                        this.args,
                                        999999999,
                                        this.base_logdir,
                                        this.log_file,
                                        True)[0] #verbose?
    print('done with ' + this.name)
    this.crashed = this.crashed_file.read_text() == "true"
    this.success = this.success and this.success_file.read_text() == "true"
    this.structured_results = this.crashed_file.read_text()
    this.summary = this.summary_file.read_text()
    with arangosh.slot_lock:
        RUNNING_SUITES.remove(this.name)
    
    if this.crashed or not this.success:
        print(str(this.log_file.name))
        print(this.log_file.parent / ("FAIL_" + str(this.log_file.name))
              )
        failname = this.log_file.parent / ("FAIL_" + str(this.log_file.name))
        this.log_file.rename(failname)
        this.log_file = failname
        SUCCESS = False

    print(this.weight)
    testing_instance.done_job(this.parallelity)

class testingRunner():
    def __init__(self, cfg):
        self.cfg = cfg
        self.slot_lock = Lock()
        self.available_slots = psutil.cpu_count(logical=False)
        self.used_slots = 0
        self.scenarios = []
        self.arangosh = ArangoshExecutor(self.cfg, self.slot_lock)
        self.workers = []

    def print_active(self):
        global RUNNING_SUITES
        with self.slot_lock:
            print("Running: " + str(RUNNING_SUITES) + " => Slots: " + str(self.used_slots))

    def done_job(self, count):
        """ if one job is finished... """
        with self.slot_lock:
            self.used_slots -= count

    def launch_next(self, offset):
        """ launch one testing job """
        global RUNNING_SUITES
        if self.scenarios[offset].parallelity > (self.available_slots - self.used_slots):
            return False
        with self.slot_lock:
            self.used_slots += self.scenarios[offset].parallelity
        this = self.scenarios[offset]
        print("launching " + this.name)
        pp.pprint(this)

        print(this.log)
        with self.slot_lock:
            RUNNING_SUITES.append(this.name)

        worker = Thread(target=testing_runner,
                        args=(self,
                              this,
                              self.arangosh))
        worker.name = this.name
        worker.start()
        self.workers.append(worker)
        return True

    def testing_runner(self):
        """ run testing suites """
        global SUCCESS
        global RUNNING_SUITES
        
        mem = psutil.virtual_memory()
        os.environ['ARANGODB_OVERRIDE_DETECTED_TOTAL_MEMORY'] = str(int((mem.total * 0.8) / 9))

        #raise Exception("tschuess")
        start_offset = 0
        used_slots = 0
        if len(self.scenarios) == 0:
            raise Exception("no valid scenarios loaded")
        some_scenario = self.scenarios[0]
        if not some_scenario.base_logdir.exists():
            some_scenario.base_logdir.mkdir()
        if not some_scenario.base_testdir.exists():
            some_scenario.base_testdir.mkdir()
        while start_offset < len(self.scenarios) or used_slots > 0:
            used_slots = 0
            with self.slot_lock:
                used_slots = self.used_slots
            if self.available_slots > used_slots and start_offset < len(self.scenarios):
                print(f"Launching more: {self.available_slots} > {used_slots}")
                if self.launch_next(start_offset):
                    start_offset += 1
                    time.sleep(5)
                    self.print_active()
                else:
                    if used_slots == 0:
                        print("done")
                        break
                    self.print_active()
                    time.sleep(5)
            else:
                self.print_active()
                time.sleep(5)
        for worker in self.workers:
            worker.join()
        print(self.scenarios)
        summary = ""
        for testrun in self.scenarios:
            if testrun.crashed or not testrun.success:
                summary += testrun.summary
        print("\n" + "SUCCESS" if SUCCESS else "FAILED")
        print(summary)
        print('a'*80)
        (get_workspace() / 'testfailures.txt').write_text(summary)
        print(                            some_scenario.base_testdir)
        shutil.make_archive(self.cfg.run_root / 'innerlogs',
                            "bztar",
                            Path.cwd(),
                            str(self.cfg.test_data_dir) + "/")

        shutil.rmtree(self.cfg.test_data_dir, ignore_errors=False)

        tarfile = get_workspace() / datetime.now(tz=None).strftime("testreport-%d-%b-%YT%H.%M.%SZ")
        print(some_scenario.base_logdir)
        shutil.make_archive(str(tarfile),
                            "gztar",
                            str(self.cfg.run_root) + "/",
                            str(self.cfg.run_root) + "/")
        # Path(str(tarfile) + '.tar.gz').rename(str(tarfile) +'.7z') # todo
    def register_test_func(self, cluster, test):
        """ print one test function """
        args = test["args"]
        params = test["params"]
        suffix = params.get("suffix", "")
        name = test["name"]
        weight = 1 
        if suffix:
            name += f"_{suffix}"

        if test["wweight"] :
            parallelity = test["wweight"]
        # TODO full, windows, single, cluster
        if 'single' in test['flags'] and cluster:
            return;
        if 'cluster' in test['flags'] and not cluster:
            return;
        if cluster:
            if parallelity == 1:
                parallelity = 4
            args += ['--cluster', 'true',
                     '--dumpAgencyOnError', 'true']
        if "enterprise" in test["flags"]:
            return # todo: detect enterprise
        if "ldap" in test["flags"] and not 'LDAPHOST' in os.environ:
            return

        if "buckets" in params:
            num_buckets = int(params["buckets"])
            for i in range(num_buckets):
                cfg = TestConfig()
                self.scenarios.append(cfg)
                cfg.weight = test['weight'];
                cfg.args = [ *args, '--index', f"{i}", '--testBuckets', f'{num_buckets}/{i}'];
                cfg.suite = test["name"]
                cfg.name = name + f"_{i}"
                cfg.expand_vars(self.cfg, test['flags'])
                cfg.parallelity = parallelity
        else:
            cfg = TestConfig()
            self.scenarios.append(cfg)
            cfg.weight = test['weight'];
            cfg.args = [*args]
            cfg.suite = test["name"]
            cfg.name = name
            cfg.parallelity = parallelity
            cfg.expand_vars(self.cfg, test['flags'])

def launch(args, outfile, tests):
    """ Manage test execution on our own """
    runner = testingRunner(config(Path(args.definitions).resolve()))
    for test in tests:
        runner.register_test_func(args.cluster, test)
    print(runner.scenarios)

    runner.testing_runner()
    
def generate_fish_output(args, outfile, tests):
    """ unix/fish conformant test definitions """
    def output(line):
        """ output one line """
        print(line, file=outfile)

    def print_test_func(test, func, varname):
        """ print one test function """
        args = " ".join(test["args"])
        params = test["params"]
        suffix = params.get("suffix", "-")

        conditions = []
        if "enterprise" in test["flags"]:
            conditions.append("isENTERPRISE;")
        if "ldap" in test["flags"]:
            conditions.append("hasLDAPHOST;")

        if len(conditions) > 0:
            conditions_string = " and ".join(conditions) + " and "
        else:
            conditions_string = ""

        if "buckets" in params:
            num_buckets = int(params["buckets"])
            for i in range(num_buckets):
                output(
                    f'{conditions_string}'
                    f'set {varname} "${varname}""{test["weight"]},{func} \'{test["name"]}\''
                    f' {i} --testBuckets {num_buckets}/{i} {args}\\n"')
        else:
            output(f'{conditions_string}'
                   f'set {varname} "${varname}""{test["weight"]},{func} \'{test["name"]}\' '
                   f'{suffix} {args}\\n"')

    def print_all_tests(func, varname):
        """ iterate over all definitions """
        for test in tests:
            print_test_func(test, func, varname)

    if args.cluster:
        print_all_tests("runClusterTest1", "CT")
    else:
        print_all_tests("runSingleTest1", "ST")


def generate_ps1_output(args, outfile, tests):
    """ powershell conformant test definitions """
    def output(line):
        """ output one line """
        print(line, file=outfile)

    for test in tests:
        params = test["params"]
        suffix = f' -index "{params["suffix"]}"' if "suffix" in params else ""
        cluster_str = " -cluster $true" if args.cluster else ""
        condition_prefix = ""
        condition_suffix = ""
        if "enterprise" in test["flags"]:
            condition_prefix = 'If ($ENTERPRISEEDITION -eq "On") { '
            condition_suffix = ' }'
        if "ldap" in test["flags"]:
            raise Exception("ldap not supported for windows")

        moreargs = ""
        args_list = test["args"]
        if len(args_list) > 0:
            moreargs = f' -moreParams "{" ".join(args_list)}"'

        if "buckets" in params:
            num_buckets = int(params["buckets"])
            for i in range(num_buckets):
                output(f'{condition_prefix}'
                       f'registerTest -testname "{test["name"]}" -weight {test["wweight"]} '
                       f'-index "{i}" -bucket "{num_buckets}/{i}"{moreargs}{cluster_str}'
                       f'{condition_suffix}')
        else:
            output(f'{condition_prefix}'
                   f'registerTest -testname "{test["name"]}"{cluster_str} -weight {test["wweight"]}{suffix}{moreargs}'
                   f'{condition_suffix}')


def filter_tests(args, tests):
    """ filter testcase by operations target Single/Cluster/full """
    if args.all:
        return tests

    filters = []
    if args.cluster:
        filters.append(lambda test: "single" not in test["flags"])
    else:
        filters.append(lambda test: "cluster" not in test["flags"])

    if args.full:
        filters.append(lambda test: "!full" not in test["flags"])
    else:
        filters.append(lambda test: "full" not in test["flags"])

    if args.format == "ps1":
        filters.append(lambda test: "!windows" not in test["flags"])

    for one_filter in filters:
        tests = filter(one_filter, tests)
    return list(tests)


def generate_dump_output(_, outfile, tests):
    """ interactive version output to inspect comprehension """
    def output(line):
        """ output one line """
        print(line, file=outfile)

    for test in tests:
        params = " ".join(f"{key}={value}" for key, value in test['params'].items())
        output(f"{test['name']}")
        output(f"\tweight: {test['weight']}")
        output(f"\tweight: {test['wweight']}")
        output(f"\tflags: {' '.join(test['flags'])}")
        output(f"\tparams: {params}")
        output(f"\targs: {' '.join(test['args'])}")


formats = {
    "dump": generate_dump_output,
    "fish": generate_fish_output,
    "ps1": generate_ps1_output,
    "launch": launch,
}

known_flags = {
    "cluster": "this test requires a cluster",
    "single": "this test requires a single server",
    "full": "this test is only executed in full tests",
    "!full": "this test is only executed in non-full tests",
    "ldap": "ldap",
    "enterprise": "this tests is only executed with the enterprise version",
    "!windows": "test is excluded from ps1 output"
}

known_parameter = {
    "buckets": "number of buckets to use for this test",
    "suffix": "suffix that is appended to the tests folder name",
    "weight": "weight that controls execution order on Linux / Mac. Lower weights are executed later",
    "wweight": "windows weight how many resources will the job use in the SUT? Default: 1 in Single server, 4 in Clusters"
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
                        default="fish")
    parser.add_argument("-o", "--output", type=str, help="output file, default is '-', which means stdout", default="-")
    parser.add_argument("--validate-only", help="validates the test definition file", action="store_true")
    parser.add_argument("--help-flags", help="prints information about available flags and exits", action="store_true")
    parser.add_argument("--cluster", help="output only cluster tests instead of single server", action="store_true")
    parser.add_argument("--full", help="output full test set", action="store_true")
    parser.add_argument("--all", help="output all test, ignore other filters", action="store_true")
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
            params[key] = parse_number(params[key])
        elif default_value is not None:
            params[key] = default_value

    parse_number_or_default("weight", 250)
    parse_number_or_default("wweight", 4 if is_cluster else 1)
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
    name, *remainder = bits

    flags = []
    params = {}
    args = []

    for idx, bit in enumerate(remainder):
        if bit == "--":
            args = remainder[idx + 1:]
            break

        if "=" in bit:
            key, value = bit.split("=", maxsplit=1)
            params[key] = value
        else:
            flags.append(bit)

    # check all flags
    for flag in flags:
        if flag not in known_flags:
            raise Exception(f"Unknown flag `{flag}`")

    # check all params
    for param in params:
        if param not in known_parameter:
            raise Exception(f"Unknown parameter `{param}`")

    validate_flags(flags)
    params = validate_params(params, 'cluster' in flags)

    return {
        "name": name,
        "weight": params["weight"],
        "wweight": params["wweight"],
        "flags": flags,
        "args": args,
        "params": params
    }


def read_definitions(filename):
    """ read test definitions txt """
    tests = []
    has_error = False
    with open(filename, "r", encoding="utf-8") as filep:
        for line_no, line in enumerate(filep):
            line = line.strip()
            if line.startswith("#") or len(line) == 0:
                continue  # ignore comments
            try:
                test = read_definition_line(line)
                tests.append(test)
            except Exception as exc:
                print(f"{filename}:{line_no + 1}: {exc}", file=sys.stderr)
                has_error = True
    if has_error:
        raise Exception("abort due to errors")
    return tests


def generate_output(args, outfile, tests):
    """ generate output """
    if args.format not in formats:
        raise Exception(f"Unknown format `{args.format}`")
    formats[args.format](args, outfile, tests)


def get_output_file(args):
    """ get output file """
    if args.output == '-':
        return sys.stdout
    return open(args.output, "w", encoding="utf-8")


def main():
    """ entrypoint """
    try:
        args = parse_arguments()
        tests = read_definitions(args.definitions)
        if args.validate_only:
            return  # nothing left to do
        tests = filter_tests(args, tests)
        generate_output(args, get_output_file(args), tests)
    except Exception as exc:
        print(exc, file=sys.stderr)
        print(exc.stack)
        sys.exit(1)


if __name__ == "__main__":
    main()
