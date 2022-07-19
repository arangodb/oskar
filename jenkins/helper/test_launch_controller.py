#!/bin/env python3
""" read test definition, and generate the output for the specified target """
import argparse
from datetime import datetime, timedelta
import os
from pathlib import Path
import platform
import pprint
import signal
import sys
from threading  import Thread, Lock
import time
from traceback import print_exc
import shutil
import psutil

from async_client import (
    CliExecutionException,
    ArangoCLIprogressiveTimeoutExecutor,
    dummy_line_result,
)

ZIPFORMAT="gztar"
try:
    import py7zr
    shutil.register_archive_format('7zip', py7zr.pack_7zarchive, description='7zip archive')
    ZIPFORMAT="7zip"
except ModuleNotFoundError:
    pass

# check python 3
if sys.version_info[0] != 3:
    print("found unsupported python version ", sys.version_info)
    sys.exit()


IS_WINDOWS = platform.win32_ver()[0] != ""
IS_MAC = platform.mac_ver()[0] != ""

pp = pprint.PrettyPrinter(indent=4)

all_tests = []
#pylint: disable=line-too-long disable=broad-except

def sigint_boomerang_handler(signum, frame):
    """do the right thing to behave like linux does"""
    # pylint: disable=unused-argument
    if signum != signal.SIGINT:
        sys.exit(1)
    # pylint: disable=unnecessary-pass
    pass

if IS_WINDOWS:
    original_sigint_handler = signal.getsignal(signal.SIGINT)
    signal.signal(signal.SIGINT, sigint_boomerang_handler)


def get_workspace():
    """ evaluates the directory to put reports to """
    if 'INNERWORKDIR' in os.environ:
        workdir = Path(os.environ['INNERWORKDIR'])
        if workdir.exists():
            return workdir
    if 'WORKDIR' in os.environ:
        workdir = Path(os.environ['WORKDIR'])
        if workdir.exists():
            return workdir
    #if 'WORKSPACE' in os.environ:
    #    workdir = Path(os.environ['WORKSPACE'])
    #    if workdir.exists():
    #        return workdir
    return Path.cwd() / 'work'

temp = Path("/tmp/")
if 'TEMP' in os.environ:
    temp = Path(os.environ['TEMP'])
if 'INNERWORKDIR' in os.environ:
    temp = Path(os.environ['INNERWORKDIR'])
    wd = temp / 'ArangoDB'
    wd.cwd()
    temp = temp / 'tmp'

if not temp.exists():
    temp.mkdir(parents=True)
os.environ['TMPDIR'] = str(temp)
os.environ['TEMP'] = str(temp)

class ArangoshExecutor(ArangoCLIprogressiveTimeoutExecutor):
    """configuration"""

    def __init__(self, site_config, slot_lock):
        self.slot_lock = slot_lock
        self.read_only = False
        super().__init__(site_config, None)

    def run_testing(self,
                    testcase,
                    testing_args,
                    timeout,
                    directory,
                    logfile,
                    identifier, 
                    verbose
                    ):
       # pylint: disable=R0913 disable=R0902
        """ testing.js wrapper """
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
                self.cfg.deadline,
                dummy_line_result,
                verbose,
                False,
                True,
                logfile,
                identifier
            )
        except CliExecutionException as ex:
            print(ex)
            return False

class TestConfig():
    """ setup of one test """
    # pylint: disable=too-many-instance-attributes disable=too-many-arguments
    # pylint: disable=too-many-branches disable=too-many-statements
    # pylint: disable=too-few-public-methods
    def __init__(self,
                 cfg,
                 name,
                 suite,
                 args,
                 priority,
                 parallelity,
                 flags):
        """ defaults for test config """
        self.parallelity = parallelity
        self.launch_delay = 1.3
        self.progressive_timeout = 100
        self.priority = priority
        self.suite = suite
        self.name = name
        self.name_enum = name
        self.crashed = False
        self.success = True
        self.structured_results = ""
        self.summary = ""
        self.start = None
        self.finish = None
        self.delta_seconds = 0
        self.delta = None

        self.base_logdir = cfg.test_report_dir / self.name
        if not self.base_logdir.exists():
            self.base_logdir.mkdir()
        self.log_file =  cfg.run_root / f'{self.name}.log'
        self.summary_file = self.base_logdir / 'testfailures.txt'
        self.crashed_file = self.base_logdir / 'UNITTEST_RESULT_CRASHED.json'
        self.success_file = self.base_logdir / 'UNITTEST_RESULT_EXECUTIVE_SUMMARY.json'
        self.report_file =  self.base_logdir / 'UNITTEST_RESULT.json'
        self.base_testdir = cfg.test_data_dir/ self.name

        self.args = []
        for param in args:
            if param.startswith('$'):
                paramname = param[1:]
                if paramname in os.environ:
                    self.args += os.environ[paramname].split(' ')
                else:
                    print("Error: failed to expand environment variable: '" + param + "' for '" + self.name + "'")
            else:
                self.args.append(param)
        self.args += ['--coreCheck', 'true', '--disableMonitor', 'true', '--writeXmlReport', 'true']


        if 'filter' in os.environ:
            self.args += ['--test', os.environ['filter']]
        if 'sniff' in flags:
            if IS_WINDOWS:
                self.args += ['--sniff', 'true',
                             '--sniffProgram',  os.environ['TSHARK'],
                             '--sniffDevice', os.environ['dumpDevice']]
            else:
                self.args += ['--sniff', 'sudo']

        if 'SKIPNONDETERMINISTIC' in os.environ:
            self.args += ['--skipNondeterministic', os.environ['SKIPNONDETERMINISTIC']]
        if 'SKIPTIMECRITICAL' in os.environ:
            self.args += ['--skipTimeCritical', os.environ['SKIPTIMECRITICAL']]

        if 'BUILDMODE' in os.environ:
            self.args += [ '--buildType',  os.environ['BUILDMODE'] ]

        if 'dumpAgencyOnError' in os.environ:
            self.args += [ '--dumpAgencyOnError', os.environ['dumpAgencyOnError']]
        if 'portBase' in os.environ:
            self.args += [ '--minPort', os.environ['portBase'],
                          '--maxPort', str(int(os.environ['portBase']) + 99)]
        if 'SKIPGREY' in os.environ:
            self.args += [ '--skipGrey', os.environ['SKIPGREY']]
        if 'ONLYGREY' in os.environ:
            self.args += [ '--onlyGrey', os.environ['ONLYGREY']]

        if 'vst' in flags:
            self.args += [ '--vst', 'true']
        if 'ssl' in flags:
            self.args += [ '--protocol', 'ssl']
        if 'http2' in flags:
            self.args += [ '--http2', 'true']
        if 'encrypt' in flags:
            self.args += [ '--encryptionAtRest', 'true']

    def __repr__(self):
        return """
{0.name} => {0.parallelity}, {0.priority}, {0.success} -- {1}""".format(
            self,
            ' '.join(self.args))

    def print_test_log_line(self):
        """ get visible representation """
        # pylint: disable=consider-using-f-string
        resultstr = "Good result in"
        if not self.success:
            resultstr = "Bad result in"
        if self.crashed:
            resultstr = "Crash occured in"
        return """
{1} {0.name} => {0.parallelity}, {0.priority}, {0.success} -- {2}""".format(
            self,
            resultstr,
            ' '.join(self.args))

    def print_testruns_line(self):
        """ get visible representation """
        # pylint: disable=consider-using-f-string
        resultstr = "GOOD"
        if not self.success:
            resultstr = "BAD"
        if self.crashed:
            resultstr = "CRASH"
        return """
<tr><td>{0.name}</td><td align="right">{0.delta}</td><td align="right">{1}</td></tr>""".format(
            self,
            resultstr)

def get_priority(test_config):
    """ sorter function to return the priority """
    return test_config.priority

class SiteConfig:
    """ this environment - adapted to oskar defaults """
    # pylint: disable=too-few-public-methods disable=too-many-instance-attributes
    def __init__(self, definition_file):
        print(os.environ)
        self.timeout = 1800
        if 'timeLimit' in os.environ:
            self.timeout = int(os.environ['timeLimit'])
        self.deadline = datetime.now() + timedelta(seconds=self.timeout)
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

def testing_runner(testing_instance, this, arangosh):
    """ operate one makedata instance """
    this.start = datetime.now(tz=None)
    this.success = arangosh.run_testing(this.suite,
                                        this.args,
                                        999999999,
                                        this.base_logdir,
                                        this.log_file,
                                        this.name_enum,
                                        True)[0] #verbose?
    this.finish = datetime.now(tz=None)
    this.delta = this.finish - this.start
    this.delta_seconds = this.delta.total_seconds()
    print(f'done with {this.name_enum}')
    this.crashed = this.crashed_file.read_text() == "true"
    this.success = this.success and this.success_file.read_text() == "true"
    this.structured_results = this.crashed_file.read_text()
    this.summary = this.summary_file.read_text()
    print('xxx')
    with arangosh.slot_lock:
        print('yyy')
        testing_instance.running_suites.remove(this.name_enum)

    if this.crashed or not this.success:
        print(str(this.log_file.name))
        print(this.log_file.parent / ("FAIL_" + str(this.log_file.name))
              )
        failname = this.log_file.parent / ("FAIL_" + str(this.log_file.name))
        this.log_file.rename(failname)
        this.log_file = failname
        with arangosh.slot_lock:
            print('zzz')
            if this.crashed:
                testing_instance.crashed = True
            testing_instance.success = False
    testing_instance.done_job(this.parallelity)

class TestingRunner():
    """ manages test runners, creates report """
    # pylint: disable=too-many-instance-attributes
    def __init__(self, cfg):
        self.cfg = cfg
        self.slot_lock = Lock()
        self.available_slots = psutil.cpu_count(logical=False)
        self.used_slots = 0
        self.scenarios = []
        self.arangosh = ArangoshExecutor(self.cfg, self.slot_lock)
        self.workers = []
        self.running_suites = []
        self.success = True
        self.crashed = False

    def print_active(self):
        """ output currently active testsuites """
        with self.slot_lock:
            print("Running: " + str(self.running_suites) + " => Active Slots: " + str(self.used_slots))
        sys.stdout.flush()

    def done_job(self, count):
        """ if one job is finished... """
        with self.slot_lock:
            self.used_slots -= count

    def launch_next(self, offset, counter):
        """ launch one testing job """
        if self.scenarios[offset].parallelity > (self.available_slots - self.used_slots):
            return False
        with self.slot_lock:
            self.used_slots += self.scenarios[offset].parallelity
        this = self.scenarios[offset]
        this.name_enum = f"{this.name} {str(counter)}"
        print(f"launching {this.name_enum}")
        pp.pprint(this)

        with self.slot_lock:
            self.running_suites.append(this.name_enum)

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
        mem = psutil.virtual_memory()
        os.environ['ARANGODB_OVERRIDE_DETECTED_TOTAL_MEMORY'] = str(int((mem.total * 0.8) / 9))

        #raise Exception("tschuess")
        start_offset = 0
        used_slots = 0
        counter = 0
        if len(self.scenarios) == 0:
            raise Exception("no valid scenarios loaded")
        some_scenario = self.scenarios[0]
        if not some_scenario.base_logdir.exists():
            some_scenario.base_logdir.mkdir()
        if not some_scenario.base_testdir.exists():
            some_scenario.base_testdir.mkdir()
        print(self.cfg.deadline)
        if datetime.now() > self.cfg.deadline:
            raise ValueError("test already timed out before started?")
        while (datetime.now() < self.cfg.deadline) and (start_offset < len(self.scenarios) or used_slots > 0):
            used_slots = 0
            with self.slot_lock:
                used_slots = self.used_slots
            if self.available_slots > used_slots and start_offset < len(self.scenarios):
                print(f"Launching more: {self.available_slots} > {used_slots} {counter}")
                sys.stdout.flush()
                if self.launch_next(start_offset, counter):
                    start_offset += 1
                    time.sleep(5)
                    counter += 1
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
        deadline = (datetime.now() > self.cfg.deadline)
        for worker in self.workers:
            if deadline:
                print("Deadline: Waiting for " + worker.name)
            worker.join()

    def generate_report_txt(self):
        """ create the summary testfailures.txt from all bits """
        print(self.scenarios)
        summary = ""
        for testrun in self.scenarios:
            print(testrun)
            if testrun.crashed or not testrun.success:
                summary += testrun.summary
        print(summary)
        (get_workspace() / 'testfailures.txt').write_text(summary)

    def generate_crash_report(self):
        """ crash report zips """
        core_dir = Path.cwd()
        core_pattern = "core*"
        if 'COREDIR' in os.environ:
            core_dir = Path(os.environ['COREDIR'])
        if IS_MAC:
            core_dir = Path('/cores')
        if IS_WINDOWS:
            core_pattern = "*.dmp"
        is_empty = not bool(sorted(core_dir.glob(core_pattern)))
        print(core_dir)
        if not is_empty:
            crash_report_file = get_workspace() / datetime.now(tz=None).strftime("crashreport-%d-%b-%YT%H.%M.%SZ")
            print("creating crashreport: " + str(crash_report_file))
            sys.stdout.flush()
            shutil.make_archive(str(crash_report_file),
                                ZIPFORMAT,
                                core_dir,
                                core_dir,
                                True)
            binary_report_file = get_workspace() / datetime.now(tz=None).strftime("binaries-%d-%b-%YT%H.%M.%SZ")
            print("creating crashreport binary support zip: " + str(binary_report_file))
            sys.stdout.flush()
            shutil.make_archive(str(binary_report_file),
                                ZIPFORMAT,
                                self.cfg.bin_dir,
                                self.cfg.bin_dir,
                                True)
            for corefile in core_dir.glob(core_pattern):
                print("Deleting corefile " + str(corefile))
                sys.stdout.flush()
                corefile.unlink()

    def generate_test_report(self):
        """ regular testresults zip """
        tarfile = get_workspace() / datetime.now(tz=None).strftime("testreport-%d-%b-%YT%H.%M.%SZ")
        print("Creating " + str(tarfile))
        sys.stdout.flush()
        shutil.make_archive(self.cfg.run_root / 'innerlogs',
                            "bztar",
                            Path.cwd(),
                            self.cfg.test_data_dir)

        shutil.rmtree(self.cfg.test_data_dir, ignore_errors=False)
        shutil.make_archive(tarfile,
                            ZIPFORMAT,
                            self.cfg.run_root,
                            self.cfg.run_root,
                            True)

    def create_log_file(self):
        """ create the log file with the stati """
        logfile = get_workspace() / 'test.log'
        with open(logfile, "w", encoding="utf-8") as filep:
            for one_scenario in self.scenarios:
                filep.write(one_scenario.print_test_log_line())

    def create_testruns_file(self):
        """ create the log file with the stati """
        logfile = get_workspace() / 'testRuns.html'
        state = 'GOOD'
        if not self.success:
            state  = 'BAD'
        if self.crashed:
            state = 'CRASHED'
        with open(logfile, "w", encoding="utf-8") as filep:
            filep.write('''
<table>
<tr><th>Test</th><th>Runtime</th><th>Status</th></tr>
''')
            total = 0
            for one_scenario in self.scenarios:
                filep.write(one_scenario.print_testruns_line())
                total += one_scenario.delta_seconds
            filep.write('''
<tr style="background-color: red;color: white;"><td>TOTAL</td><td align="right"></td><td align="right">{0}</td></tr>
</table>
'''.format(state))

    def register_test_func(self, cluster, test):
        """ print one test function """
        args = test["args"]
        params = test["params"]
        suffix = params.get("suffix", "")
        name = test["name"]
        if suffix:
            name += f"_{suffix}"

        if test["wweight"] :
            parallelity = test["wweight"]
        if 'single' in test['flags'] and cluster:
            return
        if 'cluster' in test['flags'] and not cluster:
            return
        if cluster:
            if parallelity == 1:
                parallelity = 4
            args += ['--cluster', 'true',
                     '--dumpAgencyOnError', 'true']
        if "enterprise" in test["flags"]:
            return
        if "ldap" in test["flags"] and not 'LDAPHOST' in os.environ:
            return

        if "buckets" in params:
            num_buckets = int(params["buckets"])
            for i in range(num_buckets):
                self.scenarios.append(
                    TestConfig(self.cfg,
                               name + f"_{i}",
                               test["name"],
                               [ *args,
                                 '--index', f"{i}",
                                 '--testBuckets', f'{num_buckets}/{i}'],
                               test['weight'],
                               parallelity,
                               test['flags']))
        else:
            self.scenarios.append(
                TestConfig(self.cfg,
                           name,
                           test["name"],
                           [ *args],
                           test['weight'],
                           parallelity,
                           test['flags']))

    def sort_by_priority(self):
        """ sort the tests by their priority for the excecution """
        self.scenarios.sort(key=get_priority)

    def print_and_exit_closing_stance(self):
        """ our finaly good buye stance. """
        print("\n" + "SUCCESS" if self.success else "FAILED")
        retval = 0
        if not self.success:
            retval = 1
        if self.crashed:
            retval = 2
        sys.exit(retval)

def launch(args, tests):
    """ Manage test execution on our own """
    runner = TestingRunner(SiteConfig(Path(args.definitions).resolve()))
    for test in tests:
        runner.register_test_func(args.cluster, test)
    runner.sort_by_priority()
    print(runner.scenarios)
    try:
        runner.testing_runner()
        runner.generate_report_txt()
        runner.generate_crash_report()
        runner.generate_test_report()
    except Exception as exc:
        print()
        sys.stderr.flush()
        sys.stdout.flush()
        print(exc, file=sys.stderr)
        print_exc()
    finally:
        sys.stderr.flush()
        sys.stdout.flush()
        runner.create_log_file()
        runner.create_testruns_file()
        runner.print_and_exit_closing_stance()

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

    if args.gtest:
        filters.append(lambda test: "gtest" ==  test["name"])

    if args.format == "ps1" or IS_WINDOWS:
        filters.append(lambda test: "!windows" not in test["flags"])

    for one_filter in filters:
        tests = filter(one_filter, tests)
    return list(tests)


def generate_dump_output(_, tests):
    """ interactive version output to inspect comprehension """
    def output(line):
        """ output one line """
        print(line)

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
    "launch": launch,
}

known_flags = {
    "cluster": "this test requires a cluster",
    "single": "this test requires a single server",
    "full": "this test is only executed in full tests",
    "!full": "this test is only executed in non-full tests",
    "gtest": "only the gtest are to be executed",
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
                        default="launch")
    parser.add_argument("-o", "--output", type=str, help="output file, default is '-', which means stdout", default="-")
    parser.add_argument("--validate-only", help="validates the test definition file", action="store_true")
    parser.add_argument("--help-flags", help="prints information about available flags and exits", action="store_true")
    parser.add_argument("--cluster", help="output only cluster tests instead of single server", action="store_true")
    parser.add_argument("--full", help="output full test set", action="store_true")
    parser.add_argument("--gtest", help="only runt gtest", action="store_true")
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
