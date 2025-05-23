#!/bin/env python3
""" the testing runner actually manages launching the processes, creating reports, etc. """
from datetime import datetime
import os
from pathlib import Path
import hashlib
import json
import pprint
import re
import shutil
import signal
import sys
import time
from threading  import Thread, Lock
import traceback
from multiprocessing import Process
import zipfile

import psutil

from socket_counter import get_socket_count

# pylint: disable=line-too-long disable=broad-except
from arangosh import ArangoshExecutor
from test_config import get_priority, TestConfig
from site_config import (
    TEMP,
    IS_WINDOWS,
    IS_MAC,
    IS_LINUX,
    get_workspace,
    COVERAGE_VAR,
    COVERAGE_VALUE
)
from tools.killall import list_all_processes, kill_all_arango_processes
from aggregate_coverage import combine_coverage_dirs_multi

MAX_COREFILES_SINGLE=4
MAX_COREFILES_CLUSTER=15
if 'MAX_CORECOUNT' in os.environ:
    MAX_COREFILES_SINGLE=int(os.environ['MAX_CORECOUNT'])
    MAX_COREFILES_CLUSTER=int(os.environ['MAX_CORECOUNT'])
MAX_COREFILE_SIZE_MB=850
if 'MAX_CORESIZE' in os.environ:
    MAX_COREFILE_SIZE_MB=int(os.environ['MAX_CORESIZE'])

COVERAGE_LOCK = Lock()

pp = pprint.PrettyPrinter(indent=4)

ZIPFORMAT="gztar"
ZIPEXT="tar.gz"
try:
    import py7zr
    shutil.register_archive_format('7zip', py7zr.pack_7zarchive, description='7zip archive')
    ZIPFORMAT="7zip"
    ZIPEXT="7z"
except ModuleNotFoundError:
    pass

def zipp_this(filenames, target_dir):
    """ worker function to zip one file a time in a subprocess """
    # pylint: disable=consider-using-with
    for corefile in filenames:
        try:
            print(f'zipping {corefile}')
            zipfile.ZipFile(str(target_dir / (corefile.name + "." + ZIPEXT)),
                            mode='w', compression=zipfile.ZIP_LZMA).write(str(corefile))
        except Exception as exc:
            print(f'skipping {corefile} since {exc}')
        try:
            corefile.unlink(missing_ok=True)
        except Exception as ex:
            print(f"failed to delete {corefile} because of {ex}")

def testing_runner(testing_instance, this, arangosh):
    """ operate one makedata instance """
    try:
        this.start = datetime.now(tz=None)
        this.cov_prefix = None
        this.cov_prefix_var = None
        if this.cfg.is_cov:
            this.cov_prefix =  (Path(COVERAGE_VALUE) /
                                this.name_enum.replace(' ', '_'))
            if this.cov_prefix.exists():
                print(f"deleting pre-existing coverage {str(this.cov_prefix)}")
                shutil.rmtree(str(this.cov_prefix))
            if not this.cov_prefix.exists():
                this.cov_prefix.mkdir(parents=True)
            this.cov_prefix_var = this.cov_prefix / "testingjs"
        ret = arangosh.run_testing(this.suite,
                                   this.arangosh_args,
                                   this.args,
                                   999999999,
                                   this.base_logdir,
                                   this.log_file,
                                   this.name_enum,
                                   this.temp_dir,
                                   COVERAGE_VAR,
                                   str(this.cov_prefix_var) if this.cov_prefix is not None else this.cov_prefix,
                                   True) #verbose?
        this.success = (
            not ret["progressive_timeout"] or
            not ret["have_deadline"] or
            ret["rc_exit"] == 0
        )
        this.finish = datetime.now(tz=None)
        this.delta = this.finish - this.start
        this.delta_seconds = this.delta.total_seconds()
        this.crashed = not this.crashed_file.exists() or this.crashed_file.read_text() == "true"
        this.success = this.success and this.success_file.exists() and this.success_file.read_text() == "true"
        print(f"done with {this.name_enum} -> {this.success} {ret['rc_exit']}")
        if this.report_file.exists():
            this.structured_results = this.report_file.read_text(encoding="UTF-8", errors='ignore')
        this.summary = ret['error']
        if this.summary_file.exists():
            this.summary += this.summary_file.read_text()
        else:
            print(f'{this.name_enum} no testreport!')
        final_name = TEMP / this.name
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
            final_name = TEMP / ("FAIL_" + this.name)
        try:
            this.temp_dir.rename(final_name)
        except FileExistsError as ex:
            print(f"can't expand the temp directory {ex} to {final_name}")
    except Exception as ex:
        stack = ''.join(traceback.TracebackException.from_exception(ex).format())
        this.crashed = True
        this.success = False
        this.summary = f"Python exception caught during test execution: {ex}\n{stack}"
        print(this.summary)
        this.finish = datetime.now(tz=None)
        this.delta = this.finish - this.start
        this.delta_seconds = this.delta.total_seconds()
    finally:
        print('finally')
        try:
            if this.cov_prefix is not None:
                with COVERAGE_LOCK:
                    start = time.time()
                    cov_dir = Path(this.cov_prefix)
                    result_dir = combine_coverage_dirs_multi(this.cfg, cov_dir, this.parallelity)
                    if result_dir is None:
                        print("combining coverage failed!")
                    else:
                        hash_str = hashlib.md5(this.name_enum.encode()).hexdigest()
                        target_dir = Path(COVERAGE_VALUE) / hash_str
                        print(f'renaming {str(result_dir)} -> {target_dir}')
                        result_dir.rename(target_dir)
                        print(f"deleting coverage {str(this.cov_prefix)}")
                        shutil.rmtree(str(this.cov_prefix))
                        print(f"done combining after {str(time.time() - start)}")
        except Exception as ex:
            print(ex)
            print(traceback.format_exc())
            raise ex
        with arangosh.slot_lock:
            with open((this.cfg.run_root / "job_to_pids.jsonl"), "a+", encoding="utf-8")  as jsonl_file:
                jsonl_file.write(f'{json.dumps({"pid": ret["pid"], "logfile": str(this.log_file)})}\n')
            testing_instance.running_suites.remove(this.name_enum)
        testing_instance.done_job(this.parallelity)

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
                print("no more slots available")
                return -1
            try:
                sock_count = get_socket_count()
                if sock_count > 8000:
                    print(f"Socket count: {sock_count}, waiting before spawning more")
                    return -1
            except psutil.AccessDenied:
                pass
            load_estimate = self.cfg.parallelity_to_load_factor * self.scenarios[offset].parallelity
            load = psutil.getloadavg()
            if ((load[0] > self.cfg.max_load) or
                (load[1] > self.cfg.max_load1) or
                (load[0] + load_estimate > self.cfg.overload)):
                print(F"{str(load)} <= {load_estimate} Load to high; waiting before spawning more - Disk I/O: " +
                      str(psutil.swap_memory()))
                return -1
        parallelity = 0
        with self.slot_lock:
            parallelity = self.scenarios[offset].parallelity
        self.used_slots += parallelity
        this = self.scenarios[offset]
        this.counter = counter
        this.temp_dir = TEMP / str(counter)
        this.name_enum = f"{this.name} {str(counter)}"
        print(f"launching {this.name_enum}")
        pp.pprint(this)
        this.cfg = self.cfg

        with self.slot_lock:
            self.running_suites.append(this.name_enum)

        worker = Thread(target=testing_runner,
                        name="testing runner",
                        args=(self,
                              this,
                              self.arangosh))
        worker.name = this.name
        worker.start()
        self.workers.append(worker)
        return parallelity

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
            if IS_WINDOWS:
                kill_all_arango_processes()
            print("Main: waiting for the children to terminate")
            psutil.wait_procs(children, timeout=20)
            print("Main: giving workers 20 more seconds to exit.")
            time.sleep(60)
            with self.slot_lock:
                more_running = self.used_slots != 0
        else:
            print("Main: workers terminated on time")
        if more_running:
            self.generate_report_txt("ALL: some suites didn't even abort!\n")
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
        # pylint: disable=too-many-branches disable=too-many-statements
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
        parallelity = 0
        sleep_count = 0
        last_started_count = -1
        if datetime.now() > self.cfg.deadline:
            raise ValueError("test already timed out before started?")
        while (datetime.now() < self.cfg.deadline) and (start_offset < len(self.scenarios) or used_slots > 0):
            used_slots = 0
            with self.slot_lock:
                used_slots = self.used_slots
            if ((self.cfg.available_slots > used_slots) and
                (start_offset < len(self.scenarios)) and
                 ((last_started_count < 0) or
                  (sleep_count - last_started_count > parallelity)) ):
                print(f"Launching more: {self.cfg.available_slots} > {used_slots} {counter} {last_started_count} ")
                sys.stdout.flush()
                rapid_fire = 0
                par = 1
                while (self.cfg.rapid_fire > rapid_fire and
                       self.cfg.available_slots > used_slots and
                       len(self.scenarios) > start_offset and
                       par > 0):
                    par =  self.launch_next(start_offset, counter, last_started_count != -1)
                    rapid_fire += par
                    if par > 0:
                        counter += 1
                        time.sleep(0.1)
                        start_offset += 1
                if par > 0:
                    parallelity = par
                    last_started_count = sleep_count
                    sleep_count += 1
                    time.sleep(self.cfg.loop_sleep)
                    self.print_active()
                else:
                    if used_slots == 0 and start_offset >= len(self.scenarios):
                        print("done")
                        break
                    self.print_active()
                    sleep_count += 1
                    time.sleep(self.cfg.loop_sleep)
                    sleep_count += 1
            else:
                self.print_active()
                time.sleep(self.cfg.loop_sleep)
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

    def generate_report_txt(self, moremsg):
        """ create the summary testfailures.txt from all bits """
        print(self.scenarios)
        summary = moremsg
        if self.deadline_reached:
            summary = "Deadline reached during test execution!\n"
        for testrun in self.scenarios:
            print(testrun)
            if testrun.crashed or not testrun.success:
                summary += f"\n=== {testrun.name} ===\n{testrun.summary}"
            if testrun.start is None:
                summary += f"\n=== {testrun.name} ===\nhasn't been launched at all!"
            elif testrun.finish is None:
                summary += f"\n=== {testrun.name} ===\nwouldn't exit for some reason!"
        print(summary)
        self.testfailures_file.write_text(summary)

    def append_report_txt(self, text):
        """ if the file has already been written, but we have more to say: """
        with self.testfailures_file.open("a") as filep:
            filep.write(text + '\n')

    # pylint: disable=too-many-arguments
    def mp_zip_tar(self, fnlist, zip_dir, tarfile, verb, filetype):
        """ use full machine to compress files in zip-tar """
        zip_slots = psutil.cpu_count(logical=False)
        count = 0
        zip_slot_array = []
        for _ in range(zip_slots):
            zip_slot_array.append([])
        for one_file in fnlist:
            if one_file.exists():
                zip_slot_array[count % zip_slots].append(one_file)
                count += 1
        zippers = []
        print(f"{verb} launching zipper sub processes {zip_slot_array}")
        for zip_slot in zip_slot_array:
            if len(zip_slot) > 0:
                proc = Process(target=zipp_this, args=(zip_slot, zip_dir))
                proc.start()
                zippers.append(proc)
        for zipper in zippers:
            zipper.join()
        print("compressing files done")

        for one_file in fnlist:
            if one_file.is_file():
                one_file.unlink(missing_ok=True)

        print(f"creating {filetype}: {str(tarfile)} with {str(fnlist)}.tar")
        sys.stdout.flush()
        try:
            shutil.make_archive(str(tarfile),
                                'tar',
                                (zip_dir / '..').resolve(),
                                zip_dir.name,
                                True)
        except Exception as ex:
            print(f"Failed to create {verb} zip: {str(ex)}")
            self.append_report_txt(f"Failed to create {verb} zip: {str(ex)}")

    def cleanup_unneeded_binary_files(self):
        """ delete all files not needed for the crashreport binaries """
        shutil.rmtree(str(self.cfg.bin_dir / 'tzdata'))
        needed = [
            'tzdata',
            'icudtl',
            'fuertetest',
            'arangovpack',
            'arangobackup',
            'arangosh',
            'arangoexport',
            'arangoinspect',
            'arangoimport',
            'arangoimp',
            'arango-secure-installation',
            'foxx-manager',
            'arangorestore',
            'arangobench',
            'snowball',
            'arangodbtests',
            'arangod',
            'arango-init-database',
            'arangodump']
        for one_file in self.cfg.bin_dir.iterdir():
            if (one_file.suffix == '.lib' or
                (one_file.stem not in needed)):
                print(f'Deleting {str(one_file)}')
                one_file.unlink(missing_ok=True)

    def generate_crash_report(self):
        """ crash report zips """
        # pylint: disable=too-many-statements disable=too-many-branches disable=too-many-locals disable=chained-comparison
        core_max_count = MAX_COREFILES_SINGLE
        if self.cluster:
            core_max_count = MAX_COREFILES_CLUSTER
        core_dir = Path.cwd()
        core_pattern = "core*"
        if IS_WINDOWS:
            core_pattern = "*.dmp"
        system_corefiles = []
        if 'COREDIR' in os.environ:
            core_dir = Path(os.environ['COREDIR'])
        elif IS_LINUX:
            core_pattern = Path('/proc/sys/kernel/core_pattern').read_text(encoding="utf-8").strip()
            if core_pattern.startswith('/'):
                core_dir = Path(core_pattern).parent
                core_pattern = Path(core_pattern).name
            core_pattern = re.sub(r'%.', '*', core_pattern)
        else:
            core_dir = Path('/var/tmp/') # default to coreDirectory in testing.js
        if IS_MAC:
            system_corefiles = list(Path('/cores').glob(core_pattern))
            if system_corefiles is None:
                system_corefiles = []
        core_files_list = list(core_dir.glob(core_pattern))
        if core_files_list is None:
            core_files_list = []
        core_files_list += system_corefiles
        if len(core_files_list) == 0 or core_max_count <= 0:
            print(f'Coredumps are not collected: {str(len(core_files_list))} coredumps found; coredumps max limit to collect is {str(core_max_count)}!')
        else:
            if not self.crashed or self.success:
                self.append_report_txt("non captured crash reports found; please inspect the tests to find out who created them.")
            self.crashed = True
            self.success = False
            core_zip_dir = get_workspace() / 'coredumps'
            core_zip_dir.mkdir(parents=True, exist_ok=True)

            crash_report_file = get_workspace() / datetime.now(tz=None).strftime(f"crashreport-{self.cfg.datetime_format}")
            self.mp_zip_tar(core_files_list, core_zip_dir, crash_report_file, 'coredump', 'crashreport')
            shutil.rmtree(str(core_zip_dir), ignore_errors=True)

            self.cleanup_unneeded_binary_files()
        if self.crashed:
            binary_report_file = get_workspace() / datetime.now(tz=None).strftime(f"binaries-{self.cfg.datetime_format}")
            bin_files_list = [f for f in self.cfg.bin_dir.glob('*') if not f.is_symlink()]
            self.mp_zip_tar(bin_files_list, self.cfg.bin_dir, binary_report_file, 'binary support', 'binreport')

    def generate_test_report(self):
        """ regular testresults zip """
        tarfile = get_workspace() / datetime.now(tz=None).strftime(f"testreport-{self.cfg.datetime_format}")
        print('flattening inner dir structure')
        for subdir in TEMP.iterdir():
            for subsubdir in subdir.iterdir():
                path_segment = subsubdir.parts[len(subsubdir.parts) - 1]
                if path_segment.startswith('arangosh_'):
                    clean_subdir = True
                    for subsubsubdir in subsubdir.iterdir():
                        try:
                            shutil.move(str(subsubsubdir), str(subdir))
                        except shutil.Error as ex:
                            msg = f"generate_test_report: failed to move file while cleaning up temporary files: {ex}"
                            self.append_report_txt('\n' + msg + '\n')
                            print(msg)
                            clean_subdir = False
                    if clean_subdir:
                        subsubdir.rmdir()
        print(f"Creating {str(tarfile)}.{ZIPEXT}")
        sys.stdout.flush()
        try:
            shutil.make_archive(self.cfg.run_root / 'innerlogs',
                                ZIPFORMAT,
                                (TEMP / '..').resolve(),
                                TEMP.name)
        except Exception as ex:
            print("Failed to create inner zip: " + str(ex))
            self.append_report_txt(f"Failed to create inner {ZIPEXT}: {str(ex)}")
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
            state = 'GOOD\n'
            if not self.success or self.crashed:
                state  = 'BAD\n'
            filep.write(state)
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

    def register_test_func(self, test):
        """ print one test function """
        args = test["args"]
        params = test["params"]
        suffix = params.get("suffix", "")
        name = test['prefix'] + test["name"]
        if suffix:
            name += f"_{suffix}"

        if test["parallelity"] :
            parallelity = test["parallelity"]
        if 'cluster' in test['flags']:
            self.cluster = True
            if parallelity == 1:
                parallelity = 4
            args += ['--cluster', 'true',
                     '--dumpAgencyOnError', 'true']
        if "ldap" in test["flags"] and not 'LDAPHOST' in os.environ:
            return

        if "buckets" in params and not self.cfg.small_machine:
            num_buckets = int(params["buckets"])
            for i in range(num_buckets):
                self.scenarios.append(
                    TestConfig(self.cfg,
                               name + f"_{i}",
                               test["suite"],
                               [ *args,
                                 '--index', f"{i}",
                                 '--testBuckets', f'{num_buckets}/{i}'],
                               test['arangosh_args'],
                               test['priority'],
                               parallelity,
                               test['flags']))
        else:
            self.scenarios.append(
                TestConfig(self.cfg,
                           name,
                           test["suite"],
                           [ *args],
                           test['arangosh_args'],
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
