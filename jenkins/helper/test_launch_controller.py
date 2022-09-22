#!/bin/env python3
""" read test definition, and generate the output for the specified target """
import argparse
from datetime import datetime, timedelta
import platform
import os
from pathlib import Path
import pprint
import signal
import sys
from threading  import Thread, Lock
import time
from traceback import print_exc
import shutil
import psutil

from async_client import (
    ArangoCLIprogressiveTimeoutExecutor,
    make_logfile_params,
    logfile_line_result,
    delete_logfile_params
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
if IS_MAC:
    # Put us to the performance cores:
    # https://apple.stackexchange.com/questions/443713
    from os import setpriority
    PRIO_DARWIN_THREAD  = 0b0011
    PRIO_DARWIN_PROCESS = 0b0100
    PRIO_DARWIN_BG      = 0x1000
    setpriority(PRIO_DARWIN_PROCESS, 0, 0)

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
    # pylint: disable=unused-import
    # this will patch psutil for us:
    import monkeypatch_psutil

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

print(os.environ)
TEMP = Path("/tmp/")
if 'TMP' in os.environ:
    TEMP = Path(os.environ['TMP'])
if 'TEMP' in os.environ:
    TEMP = Path(os.environ['TEMP'])
if 'TMP' in os.environ:
    TEMP = Path(os.environ['TMP'])
if 'INNERWORKDIR' in os.environ:
    TEMP = Path(os.environ['INNERWORKDIR'])
    wd = TEMP / 'ArangoDB'
    wd.cwd()
    TEMP = TEMP / 'tmp'
else:
    TEMP = TEMP / 'ArangoDB'
if not TEMP.exists():
    TEMP.mkdir(parents=True)
os.environ['TMPDIR'] = str(TEMP)
os.environ['TEMP'] = str(TEMP)
os.environ['TMP'] = str(TEMP)

def list_all_processes():
    """list all processes for later reference"""
    pseaf = "PID  Process"
    # pylint: disable=catching-non-exception
    for process in psutil.process_iter(["pid", "name"]):
        cmdline = process.name
        try:
            cmdline = str(process.cmdline())
            if cmdline == "[]":
                cmdline = "[" + process.name() + "]"
        except psutil.AccessDenied:
            pass
        except psutil.ProcessLookupError:
            pass
        except psutil.NoSuchProcess:
            pass
        print(f"{process.pid} {cmdline}")
    print(pseaf)
    sys.stdout.flush()

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
            "--log.foreground-tty", "true",
            "--log.force-direct", "true",
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
        params = make_logfile_params(verbose, logfile, self.cfg.trace)
        ret = self.run_monitored(
            self.cfg.bin_dir / "arangosh",
            run_cmd,
            params=params,
            progressive_timeout=timeout,
            deadline=self.cfg.deadline,
            result_line_handler=logfile_line_result,
            identifier=identifier
        )
        delete_logfile_params(params)
        ret['error'] = params['error']
        return ret

TEST_LOG_FILES = []

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
        # pylint: disable=global-variable-not-assigned
        global TEST_LOG_FILES
        try:
            print(TEST_LOG_FILES.index(str(self.log_file)))
            raise Exception(f'duplicate testfile {str(self.log_file)}')
        except ValueError:
            TEST_LOG_FILES.append(str(self.log_file))
        self.summary_file = self.base_logdir / 'testfailures.txt'
        self.crashed_file = self.base_logdir / 'UNITTEST_RESULT_CRASHED.json'
        self.success_file = self.base_logdir / 'UNITTEST_RESULT_EXECUTIVE_SUMMARY.json'
        self.report_file =  self.base_logdir / 'UNITTEST_RESULT.json'
        self.base_testdir = cfg.test_data_dir_x / self.name

        self.args = cfg.extra_args
        for param in args:
            if param.startswith('$'):
                paramname = param[1:].upper()
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
            if IS_WINDOWS and 'TSHARK' in os.environ:
                self.args += ['--sniff', 'true',
                             '--sniffProgram',  os.environ['TSHARK'],
                             '--sniffDevice', os.environ['DUMPDEVICE']]
            else:
                self.args += ['--sniff', 'sudo']

        if 'SKIPNONDETERMINISTIC' in os.environ:
            self.args += ['--skipNondeterministic', os.environ['SKIPNONDETERMINISTIC']]
        if 'SKIPTIMECRITICAL' in os.environ:
            self.args += ['--skipTimeCritical', os.environ['SKIPTIMECRITICAL']]

        if 'BUILDMODE' in os.environ:
            self.args += [ '--buildType',  os.environ['BUILDMODE'] ]

        if 'DUMPAGENCYONERROR' in os.environ:
            self.args += [ '--dumpAgencyOnError', os.environ['DUMPAGENCYONERROR']]

        myport = cfg.portbase
        cfg.portbase += cfg.port_offset
        self.args += [ '--minPort', str(myport), '--maxPort', str(myport + cfg.port_offset - 1)]
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
        return f"""
{self.name} => {self.parallelity}, {self.priority}, {self.success} -- {' '.join(self.args)}"""

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
        self.datetime_format = "%Y-%m-%dT%H%M%SZ"
        self.trace = False
        self.portbase = 7000
        if 'PORTBASE' in os.environ:
            self.portbase = int(os.environ['PORTBASE'])
        self.port_offset = 100
        self.timeout = 1800
        if 'timeLimit'.upper() in os.environ:
            self.timeout = int(os.environ['timeLimit'.upper()])
        elif 'timeLimit' in os.environ:
            self.timeout = int(os.environ['timeLimit'])
        self.small_machine = False
        self.extra_args = []
        if psutil.cpu_count(logical=False) <= 12:
            print("Small machine detected, quadrupling deadline, disabling buckets!")
            self.small_machine = True
            self.port_offset = 400
            self.timeout *= 4
            self.extra_args = ['--extraArgs:rocksdb.compression-type', 'none']
        self.no_threads = psutil.cpu_count()
        self.available_slots = round(self.no_threads * 2) #logical=False)
        if IS_MAC and platform.processor() == "arm" and psutil.cpu_count() == 8:
            self.no_threads = 6 # M1 only has 4 performance cores
            self.available_slots = 10
        if IS_WINDOWS:
            self.max_load = 0.85
            self.max_load1 = 0.75
        else:
            self.max_load = self.no_threads * 0.9
            self.max_load1 = self.no_threads * 1.1
        self.overload = self.max_load * 1.4
        self.slots_to_parallelity_factor = self.max_load / self.available_slots
        self.deadline = datetime.now() + timedelta(seconds=self.timeout)
        self.hard_deadline = datetime.now() + timedelta(seconds=self.timeout + 660)
        if definition_file.is_file():
            definition_file = definition_file.parent
        base_source_dir = (definition_file / '..').resolve()
        bin_dir = (base_source_dir / 'build' / 'bin').resolve()
        if IS_WINDOWS:
            for target in ['RelWithdebInfo', 'Debug']:
                if (bin_dir / target).exists():
                    bin_dir = bin_dir / target
        print(f"""Machine Info:
 - {psutil.cpu_count(logical=False)} Cores / {psutil.cpu_count(logical=True)} Threads
 - {platform.processor()} processor architecture
 - {psutil.virtual_memory()} virtual Memory
 - {self.max_load} / {self.max_load1} configured maximum load 0 / 1
 - {self.slots_to_parallelity_factor} parallelity to load estimate factor
 - {self.overload} load1 threshhold for overload logging
 - {self.available_slots} test slots
 - {str(TEMP)} - temporary directory
 - current Disk I/O: {str(psutil.disk_io_counters())}
 - current Swap: {str(psutil.swap_memory())}
""")
        self.cfgdir = base_source_dir / 'etc' / 'relative'
        self.bin_dir = bin_dir
        self.base_path = base_source_dir
        self.test_data_dir = base_source_dir
        self.passvoid = ''
        self.run_root = base_source_dir / 'testrun'
        if self.run_root.exists():
            shutil.rmtree(self.run_root)
        self.test_data_dir_x = self.run_root / 'run'
        self.test_data_dir_x.mkdir(parents=True)
        self.test_report_dir = self.run_root / 'report'
        self.test_report_dir.mkdir(parents=True)
        self.portbase = 7000
        if 'PORTBASE' in os.environ:
            self.portbase = int(os.environ['PORTBASE'])

    def get_overload(self):
        """ estimate whether the system is overloaded """
        load = psutil.getloadavg()
        if load[0] > self.overload:
            return(f"HIGH SYSTEM LOAD! {load[0]}")

def testing_runner(testing_instance, this, arangosh):
    """ operate one makedata instance """
    this.start = datetime.now(tz=None)
    ret = arangosh.run_testing(this.suite,
                               this.args,
                               999999999,
                               this.base_logdir,
                               this.log_file,
                               this.name_enum,
                               True) #verbose?
    this.success = (
        not ret["progressive_timeout"] or
        not ret["have_deadline"] or
        ret["rc_exit"] == 0
    )
    this.finish = datetime.now(tz=None)
    this.delta = this.finish - this.start
    this.delta_seconds = this.delta.total_seconds()
    print(f'done with {this.name_enum}')
    this.crashed = not this.crashed_file.exists() or this.crashed_file.read_text() == "true"
    this.success = this.success and this.success_file.exists() and this.success_file.read_text() == "true"
    if this.report_file.exists():
        this.structured_results = this.report_file.read_text(encoding="UTF-8", errors='ignore')
    this.summary = ret['error']
    if this.summary_file.exists():
        this.summary += this.summary_file.read_text()
    with arangosh.slot_lock:
        testing_instance.running_suites.remove(this.name_enum)

    if this.crashed or not this.success:
        print(str(this.log_file.name))
        print(this.log_file.parent / ("FAIL_" + str(this.log_file.name))
              )
        failname = this.log_file.parent / ("FAIL_" + str(this.log_file.name))
        this.log_file.rename(failname)
        this.log_file = failname
        if (this.summary == "" and failname.stat().st_size < 1024*10):
            print("pulling undersized test output into testfailures.txt")
            this.summary = failname.read_text(encoding='utf-8')
        with arangosh.slot_lock:
            if this.crashed:
                testing_instance.crashed = True
            testing_instance.success = False
    testing_instance.done_job(this.parallelity)

def get_socket_count():
    """ get the number of sockets lingering destruction """
    counter = 0
    for socket in psutil.net_connections(kind='inet'):
        if socket.status in [
                psutil.CONN_FIN_WAIT1,
                psutil.CONN_FIN_WAIT1,
                psutil.CONN_CLOSE_WAIT]:
            counter += 1
    return counter

class TestingRunner():
    """ manages test runners, creates report """
    # pylint: disable=too-many-instance-attributes
    def __init__(self, cfg):
        self.cfg = cfg
        self.deadline_reached = False
        self.slot_lock = Lock()
        self.used_slots = 0
        self.scenarios = []
        self.arangosh = ArangoshExecutor(self.cfg, self.slot_lock)
        self.workers = []
        self.running_suites = []
        self.success = True
        self.crashed = False
        self.cluster = False
        self.datetime_format = "%Y-%m-%dT%H%M%SZ"
        self.testfailures_file = get_workspace() / 'testfailures.txt'
        self.overload_report_file = self.cfg.test_report_dir / 'overload.txt'
        self.overload_report_fh = self.overload_report_file.open('w', encoding='utf-8')

    def print_active(self):
        """ output currently active testsuites """
        now = datetime.now(tz=None).strftime(f"testreport-{self.cfg.datetime_format}")
        load = psutil.getloadavg()
        used_slots = ""
        running_slots = ""
        with self.slot_lock:
            used_slots = str(self.used_slots)
            running_slots = str(self.running_suites)
        print(str(load) + "<= Load " +
              "Running: " + str(self.running_suites) +
              " => Active Slots: " + used_slots +
              " => Swap: " + str(psutil.swap_memory()) +
              " => Disk I/O: " + str(psutil.disk_io_counters()))
        sys.stdout.flush()
        if load[0] > self.cfg.overload:
            print(f"{now} {load[0]} | {used_slots} | {running_slots}", file=self.overload_report_fh)

    def done_job(self, parallelity):
        """ if one job is finished... """
        with self.slot_lock:
            self.used_slots -= parallelity

    def launch_next(self, offset, counter, do_loadcheck):
        """ launch one testing job """
        if do_loadcheck:
            if self.scenarios[offset].parallelity > (self.cfg.available_slots - self.used_slots):
                return False
            try:
                sock_count = get_socket_count()
                if sock_count > 8000:
                    print(f"Socket count: {sock_count}, waiting before spawning more")
                    return False
            except psutil.AccessDenied:
                pass
            load_estimate = self.cfg.slots_to_parallelity_factor * self.scenarios[offset].parallelity
            load = psutil.getloadavg()
            if ((load[0] > self.cfg.max_load) or
                (load[1] > self.cfg.max_load1) or
                (load[0] + load_estimate > self.cfg.overload)):
                print(F"{str(load)} <= {load_estimate} Load to high; waiting before spawning more - Disk I/O: " +
                      str(psutil.swap_memory()))
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

    def handle_deadline(self):
        """ here we make sure no worker thread is stuck during its extraordinary shutdown """
        # 5 minutes for threads to clean up their stuff, else we consider them blocked
        more_running = True
        mica = None
        print(f"Main: {str(datetime.now())} soft deadline reached: {str(self.cfg.deadline)} now waiting for hard deadline {str(self.cfg.hard_deadline)}")
        while ((datetime.now() < self.cfg.hard_deadline) and more_running):
            time.sleep(1)
            with self.slot_lock:
                more_running = self.used_slots != 0
        if more_running:
            print("Main: reaching hard Time limit!")
            list_all_processes()
            mica = os.getpid()
            myself = psutil.Process(mica)
            children = myself.children(recursive=True)
            for one_child in children:
                if one_child.pid != mica:
                    try:
                        print(f"Main: killing {one_child.name()} - {str(one_child.pid)}")
                        one_child.resume()
                    except psutil.NoSuchProcess:
                        pass
                    except psutil.AccessDenied:
                        pass
                    try:
                        one_child.kill()
                    except psutil.NoSuchProcess:  # pragma: no cover
                        pass
            print("Main: waiting for the children to terminate")
            psutil.wait_procs(children, timeout=20)
            print("Main: giving workers 20 more seconds to exit.")
            time.sleep(60)
            with self.slot_lock:
                more_running = self.used_slots != 0
        else:
            print("Main: workers terminated on time")
        if more_running:
            self.generate_report_txt()
            print("Main: force-terminates the python process due to overall unresponsiveness! Geronimoooo!")
            list_all_processes()
            sys.stdout.flush()
            self.success = False
            if IS_WINDOWS:
                # pylint: disable=protected-access
                # we want to exit without waiting for threads:
                os._exit(4)
            else:
                os.kill(mica, signal.SIGKILL)
                sys.exit(4)

    def testing_runner(self):
        """ run testing suites """
        # pylint: disable=too-many-branches
        mem = psutil.virtual_memory()
        os.environ['ARANGODB_OVERRIDE_DETECTED_TOTAL_MEMORY'] = str(int((mem.total * 0.8) / 9))

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
        sleep_count = 0
        last_started_count = -1
        if datetime.now() > self.cfg.deadline:
            raise ValueError("test already timed out before started?")
        print(f"Main: Starting {str(datetime.now())} soft deadline will be: {str(self.cfg.deadline)} hard deadline will be: {str(self.cfg.hard_deadline)}")
        while (datetime.now() < self.cfg.deadline) and (start_offset < len(self.scenarios) or used_slots > 0):
            used_slots = 0
            with self.slot_lock:
                used_slots = self.used_slots
            if ((self.cfg.available_slots > used_slots) and
                (start_offset < len(self.scenarios)) and
                 ((last_started_count < 0) or
                  (sleep_count - last_started_count > 5)) ):
                print(f"Launching more: {self.cfg.available_slots} > {used_slots} {counter} {last_started_count} ")
                sys.stdout.flush()
                if self.launch_next(start_offset, counter, last_started_count != -1):
                    last_started_count = sleep_count
                    start_offset += 1
                    sleep_count += 1
                    time.sleep(5)
                    counter += 1
                    self.print_active()
                else:
                    if used_slots == 0 and start_offset >= len(self.scenarios):
                        print("done")
                        break
                    self.print_active()
                    sleep_count += 1
                    time.sleep(5)
            else:
                self.print_active()
                time.sleep(5)
                sleep_count += 1
        self.deadline_reached = datetime.now() > self.cfg.deadline
        if self.deadline_reached:
            self.handle_deadline()
        for worker in self.workers:
            if self.deadline_reached:
                print("Deadline: Joining threads of " + worker.name)
            worker.join()
        if self.success:
            for scenario in self.scenarios:
                if not scenario.success:
                    self.success = False

    def generate_report_txt(self):
        """ create the summary testfailures.txt from all bits """
        print(self.scenarios)
        summary = ""
        if self.deadline_reached:
            summary = "Deadline reached during test execution!\n"
        for testrun in self.scenarios:
            print(testrun)
            if testrun.crashed or not testrun.success:
                summary += f"\n=== {testrun.name} ===\n{testrun.summary}"
            if testrun.finish is None:
                summary += f"\n=== {testrun.name} ===\nhasn't been launched at all!"
        print(summary)
        self.testfailures_file.write_text(summary)

    def append_report_txt(self, text):
        """ if the file has already been written, but we have more to say: """
        with self.testfailures_file.open("a") as filep:
            filep.write(text + '\n')

    def cleanup_unneeded_binary_files(self):
        """ delete all files not needed for the crashreport binaries """
        shutil.rmtree(str(self.cfg.bin_dir / 'tzdata'))
        needed = [
            'arangod',
            'arangosh',
            'arangodump',
            'arangorestore',
            'arangoimport',
            'arangobackup',
            'arangodbtests']
        for one_file in self.cfg.bin_dir.iterdir():
            if (one_file.suffix == '.lib' or
                (one_file.stem not in needed) ):
                print(f'Deleting {str(one_file)}')
                one_file.unlink(missing_ok=True)

    def generate_crash_report(self):
        """ crash report zips """
        core_max_count = 4 # single server crashdumps...
        if self.cluster:
            core_max_count = 15 # 3 cluster instances
        core_dir = Path.cwd()
        core_pattern = "core*"
        move_files = False
        if IS_WINDOWS:
            core_pattern = "*.dmp"
        system_corefiles = []
        if 'COREDIR' in os.environ:
            core_dir = Path(os.environ['COREDIR'])
        else:
            move_files = True
            core_dir = Path('/var/tmp/') # default to coreDirectory in testing.js
        if IS_MAC:
            move_files = True
            system_corefiles = sorted(Path('/cores').glob(core_pattern))
        files = sorted(core_dir.glob(core_pattern)) + system_corefiles
        if len(files) > core_max_count:
            count = 0
            for one_crash_file in files:
                if not one_crash_file.is_file():
                    continue
                count += 1
                if count > core_max_count:
                    print(f'{core_max_count} reached. will not archive {one_crash_file}')
                    one_crash_file.unlink(missing_ok=True)

        is_empty = len(files) == 0
        if not is_empty and move_files:
            core_dir = core_dir / 'coredumps'
            core_dir.mkdir(parents=True, exist_ok=True)
            for one_file in files:
                if one_file.exists():
                    try:
                        shutil.move(one_file, core_dir)
                    except PermissionError as ex:
                        print(f"won't move {str(one_file)} - not an owner! {str(ex)}")
                        self.append_report_txt(f"won't move {str(one_file)} - not an owner! {str(ex)}")

        if self.crashed or not is_empty:
            crash_report_file = get_workspace() / datetime.now(tz=None).strftime(f"crashreport-{self.cfg.datetime_format}")
            print("creating crashreport: " + str(crash_report_file))
            sys.stdout.flush()
            try:
                shutil.make_archive(str(crash_report_file),
                                    ZIPFORMAT,
                                    (core_dir / '..').resolve(),
                                    core_dir.name,
                                    True)
            except Exception as ex:
                print("Failed to create binaries zip: " + str(ex))
                self.append_report_txt("Failed to create binaries zip: " + str(ex))
            self.cleanup_unneeded_binary_files()
            binary_report_file = get_workspace() / datetime.now(tz=None).strftime(f"binaries-{self.cfg.datetime_format}")
            print("creating crashreport binary support zip: " + str(binary_report_file))
            sys.stdout.flush()
            try:
                shutil.make_archive(str(binary_report_file),
                                    ZIPFORMAT,
                                    (self.cfg.bin_dir / '..').resolve(),
                                    self.cfg.bin_dir.name,
                                    True)
            except Exception as ex:
                print("Failed to create crashdump zip: " + str(ex))
                self.append_report_txt("Failed to create crashdump zip: " + str(ex))
            for corefile in core_dir.glob(core_pattern):
                print("Deleting corefile " + str(corefile))
                sys.stdout.flush()
                corefile.unlink()
            if move_files:
                core_dir.rmdir()

    def generate_test_report(self):
        """ regular testresults zip """
        tarfile = get_workspace() / datetime.now(tz=None).strftime(f"testreport-{self.cfg.datetime_format}")
        print("Creating " + str(tarfile))
        sys.stdout.flush()
        try:
            shutil.make_archive(self.cfg.run_root / 'innerlogs',
                                ZIPFORMAT,
                                (TEMP / '..').resolve(),
                                TEMP.name)
        except Exception as ex:
            print("Failed to create inner zip: " + str(ex))
            self.append_report_txt("Failed to create inner zip: " + str(ex))
            self.success = False

        try:
            shutil.rmtree(TEMP, ignore_errors=False)
            shutil.make_archive(tarfile,
                                ZIPFORMAT,
                                self.cfg.run_root,
                                '.',
                                True)
        except Exception as ex:
            print("Failed to create testreport zip: " + str(ex))
            self.append_report_txt("Failed to create testreport zip: " + str(ex))
            self.success = False
        try:
            shutil.rmtree(self.cfg.run_root, ignore_errors=False)
        except Exception as ex:
            print("Failed to clean up: " + str(ex))
            self.append_report_txt("Failed to clean up: " + str(ex))
            self.success = False

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
            filep.write(f'''
<tr style="background-color: red;color: white;"><td>TOTAL</td><td align="right"></td><td align="right">{state}</td></tr>
</table>
''')

    def register_test_func(self, cluster, test):
        """ print one test function """
        args = test["args"]
        params = test["params"]
        suffix = params.get("suffix", "")
        name = test["name"]
        if suffix:
            name += f"_{suffix}"

        if test["parallelity"] :
            parallelity = test["parallelity"]
        if 'single' in test['flags'] and cluster:
            return
        if 'cluster' in test['flags'] and not cluster:
            return
        if cluster:
            self.cluster = True
            if parallelity == 1:
                parallelity = 4
            args += ['--cluster', 'true',
                     '--dumpAgencyOnError', 'true']
        if "enterprise" in test["flags"]:
            return
        if "ldap" in test["flags"] and not 'LDAPHOST' in os.environ:
            return

        if "buckets" in params and not self.cfg.small_machine:
            num_buckets = int(params["buckets"])
            for i in range(num_buckets):
                self.scenarios.append(
                    TestConfig(self.cfg,
                               name + f"_{i}",
                               test["name"],
                               [ *args,
                                 '--index', f"{i}",
                                 '--testBuckets', f'{num_buckets}/{i}'],
                               test['priority'],
                               parallelity,
                               test['flags']))
        else:
            self.scenarios.append(
                TestConfig(self.cfg,
                           name,
                           test["name"],
                           [ *args],
                           test['priority'],
                           parallelity,
                           test['flags']))

    def sort_by_priority(self):
        """ sort the tests by their priority for the excecution """
        self.scenarios.sort(key=get_priority, reverse=True)

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
    create_report = True
    if args.no_report:
        print("won't generate report as you demanded!")
        create_report = False
    try:
        runner.testing_runner()
        runner.overload_report_fh.close()
        if create_report:
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
        output(f"\tpriority: {test['priority']}")
        output(f"\tparallelity: {test['parallelity']}")
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
    "sniff": "whether tcpdump / ngrep should be used",
    "ldap": "ldap",
    "enterprise": "this tests is only executed with the enterprise version",
    "!windows": "test is excluded from ps1 output",
    "no_report": "disable reporting"
}

known_parameter = {
    "buckets": "number of buckets to use for this test",
    "suffix": "suffix that is appended to the tests folder name",
    "priority": "priority that controls execution order. Testsuites with lower priority are executed later",
    "parallelity": "parallelity how many resources will the job use in the SUT? Default: 1 in Single server, 4 in Clusters"
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
    parser.add_argument("--full", help="output full test set", action="store_true")
    parser.add_argument("--gtest", help="only runt gtest", action="store_true")
    parser.add_argument("--all", help="output all test, ignore other filters", action="store_true")
    parser.add_argument("--no_report", help="disable report generation except for testfailures.txt", action="store_true")
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
            raise Exception(f"Unknown flag `{flag}` in `{line}`")

    # check all params
    for param in params:
        if param not in known_parameter:
            raise Exception(f"Unknown parameter `{param}` in `{line}`")

    validate_flags(flags)
    params = validate_params(params, 'cluster' in flags)

    return {
        "name": name,
        "priority": params["priority"],
        "parallelity": params["parallelity"],
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
