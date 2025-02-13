#!/bin/env python3
""" check which resources we have on the test host """
from datetime import datetime, timedelta
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import sys

import psutil
from socket_counter import get_socket_count

IS_COVERAGE = 'COVERAGE' in os.environ and os.environ['COVERAGE'] == 'On'
COVERAGE_VAR = None
COVERAGE_TYPE = None
COVERAGE_VALUE = ""
if IS_COVERAGE:
    if 'LLVM_PROFILE_FILE' in os.environ:
        COVERAGE_VAR = 'LLVM_PROFILE_FILE'
        COVERAGE_TYPE = 'LLVM'
        COVERAGE_VALUE = os.environ[COVERAGE_VAR]
    print(f"coverage value: {COVERAGE_VAR} = {COVERAGE_VALUE}")
IS_ARM = platform.processor() == "arm" or platform.processor() == "aarch64"
IS_WINDOWS = platform.win32_ver()[0] != ""
IS_MAC = platform.mac_ver()[0] != ""
IS_LINUX = not IS_MAC and not IS_WINDOWS
if IS_MAC:
    # Put us to the performance cores:
    # https://apple.stackexchange.com/questions/443713
    from os import setpriority
    PRIO_DARWIN_THREAD  = 0b0011
    PRIO_DARWIN_PROCESS = 0b0100
    PRIO_DARWIN_BG      = 0x1000
    setpriority(PRIO_DARWIN_PROCESS, 0, 0)

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

os.environ['TMPDIR'] = str(TEMP)
os.environ['TEMP'] = str(TEMP)
os.environ['TMP'] = str(TEMP)

def print_env():
    """ dump the environment to the console """
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    for env in os.environ:
        print(f"{env}={ansi_escape.sub('', os.environ[env])}")

def init_temp():
    """ set up the temporary directory and make sure its empty """
    if TEMP.exists():
        # pylint: disable=broad-except
        STATE = 0
        try:
            shutil.rmtree(TEMP)
            STATE = 1
            TEMP.mkdir(parents=True)
        except Exception as ex:
            msg = f"failed to clean temporary directory: {ex} - won't launch tests!"
            if STATE == 1:
                msg = f"failed to create temporary directory after cleaning: {ex} - won't launch tests!"
            (get_workspace() / 'testfailures.txt').write_text(msg + '\n')
            print(msg)
            sys.exit(2)
    else:
        TEMP.mkdir(parents=True)

class SiteConfig:
    """ this environment - adapted to oskar defaults """
    # pylint: disable=too-few-public-methods disable=too-many-instance-attributes
    def __init__(self, definition_file):
        # pylint: disable=too-many-statements disable=too-many-branches
        print_env()
        init_temp()
        self.basedir = Path.cwd()
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
        self.no_threads = psutil.cpu_count()
        self.available_slots = round(self.no_threads * 2) #logical=False)
        self.available_slots = round(self.available_slots * 0.7)
        if IS_MAC and platform.processor() == "arm":
            if psutil.cpu_count() == 8:
                self.no_threads = 6 # M1 mac mini only has 4 performance cores
                self.available_slots = 10
            if psutil.cpu_count() == 20:
                self.no_threads = 16 # M2 mac studio only has 16 performance cores
                self.available_slots = 14
                self.timeout *= 2
        if IS_WINDOWS:
            self.max_load = self.no_threads * 0.5
            self.max_load1 = self.no_threads * 0.6
        else:
            self.max_load = self.no_threads * 0.9
            self.max_load1 = self.no_threads * 1.1
        # roughly increase 1 per ten cores
        self.core_dozend = round(self.no_threads / 10)
        if self.core_dozend == 0:
            self.core_dozend = 1
        self.max_load *= 0.7
        self.loop_sleep = round(5 / self.core_dozend)
        self.overload = self.max_load * 1.4
        self.parallelity_to_load_factor  = self.max_load / self.available_slots
        self.rapid_fire = round(self.available_slots / 10)
        self.is_asan = 'SAN' in os.environ and os.environ['SAN'] == 'On'
        self.is_aulsan = self.is_asan and os.environ['SAN_MODE'] == 'AULSan'
        self.is_cov = IS_COVERAGE
        san_cov_msg = ""
        if self.is_asan or self.is_cov:
            san_cov_msg = ' - SAN '
            slot_divisor = 4
            if self.is_aulsan:
                san_cov_msg = ' - AUL-SAN '
            elif self.is_cov:
                san_cov_msg = ' - LCOV'
                slot_divisor = 2
            san_cov_msg += ' enabled, reducing possible system capacity\n'
            self.rapid_fire = 1
            self.available_slots /= slot_divisor
            #self.timeout *= 1.5
            self.loop_sleep *= 2
            self.max_load /= 2
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
        socket_count = "was not allowed to see socket counts!"
        try:
            socket_count = str(get_socket_count())
        except psutil.AccessDenied:
            pass

        print(f"""Machine Info [{psutil.Process().pid}]:
 - {psutil.cpu_count(logical=False)} Cores / {psutil.cpu_count(logical=True)} Threads
 - {platform.processor()} processor architecture
 - {psutil.virtual_memory()} virtual Memory
 - {self.parallelity_to_load_factor} parallelity to load estimate factor
 - {self.overload} load1 threshhold for overload logging
 - {self.max_load} / {self.max_load1} configured maximum load 0 / 1
 - {self.available_slots} test slots {self.rapid_fire} rapid fire slots
 - {str(TEMP)} - temporary directory
 - current Disk I/O: {str(psutil.disk_io_counters())}
 - current Swap: {str(psutil.swap_memory())}
 - Starting {str(datetime.now())} soft deadline will be: {str(self.deadline)} hard deadline will be: {str(self.hard_deadline)}
 - {self.core_dozend} / {self.loop_sleep} machine size / loop frequency
 - {socket_count} number of currently active tcp sockets
{san_cov_msg}""")
        self.cfgdir = base_source_dir / 'etc' / 'testing'
        self.bin_dir = bin_dir
        self.base_path = base_source_dir
        self.test_data_dir = base_source_dir
        self.passvoid = ''
        self.run_root = base_source_dir / 'testrun'
        if self.run_root.exists():
            shutil.rmtree(self.run_root)
        self.xml_report_dir = base_source_dir / 'testrunXml'
        if self.xml_report_dir.exists():
            shutil.rmtree(self.xml_report_dir)
        self.xml_report_dir.mkdir(parents=True)
        self.test_data_dir_x = self.run_root / 'run'
        self.test_data_dir_x.mkdir(parents=True)
        self.test_report_dir = self.run_root / 'report'
        self.test_report_dir.mkdir(parents=True)
        self.portbase = 7000
        if 'PORTBASE' in os.environ:
            self.portbase = int(os.environ['PORTBASE'])
        self.slot_memory = round((1.1 * psutil.virtual_memory().total) / self.available_slots)

    def is_instrumented(self):
        """ check whether we run an instrumented build """
        return self.is_asan or self.is_aulsan or self.is_cov

    def get_max(self):
        """ get the maximal value before overlead is triggered """
        return f'> {self.overload:9.2f}'

    def get_overload(self):
        """ estimate whether the system is overloaded """
        load = psutil.getloadavg()
        if load[0] > self.overload:
            return f"HIGH LOAD[{load[0]:3.2f} ] "
        return None
