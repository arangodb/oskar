#!/usr/bin/env python3
"""test drivers"""
from datetime import datetime
import fnmatch
import glob
import os
from queue import Queue
import shutil
import sys
from pathlib import Path
from threading  import Thread, Lock
import traceback

import psutil
from async_client import (
    ArangoCLIprogressiveTimeoutExecutor,
    make_default_params,
    make_tail_params,
    tail_silent_line_result,
    # make_logfile_params
)

from site_config import SiteConfig

SUCCESS = True

# pylint disable=global-variable-not-assigned disable=global-statement

class LlvmCov(ArangoCLIprogressiveTimeoutExecutor):
    """Convert the joint report to the jenkins compatible XML"""

    def __init__(self, site_config):
        super().__init__(site_config, None)

    def launch(self, coverage_file, lcov_file):
       # pylint: disable=R0913 disable=R0902 disable=broad-except
        """ gcov merger """
        verbose = True
        binary = "/usr/lib/llvm-16/bin/llvm-cov"
        self.job_parameters = [
            'export',
            '-format=lcov',
            'ArangoDB/build/bin/arangod',
            f'-instr-profile={str(coverage_file)}'
        ]
        self.params = make_tail_params(verbose, "lcov_convert ", lcov_file)
        print(self.job_parameters)
        start = datetime.now()
        try:
            ret = self.run_monitored(
                binary,
                self.job_parameters,
                self.params,
                progressive_timeout=600,
                deadline_grace_period=30*60,
                identifier=binary,
                result_line_handler=tail_silent_line_result,
            )
        except Exception as ex:
            print(f'''exception in {binary} run {ex}
            {"".join(traceback.TracebackException.from_exception(ex).format())}''')
            self.params['error'] += str(ex)
        end = datetime.now()
        print(f'done with {binary} in {end-start}')
        ret = {}
        ret['error'] = self.params['error']
        return ret

class LcovCobertura(ArangoCLIprogressiveTimeoutExecutor):
    """Convert the joint report to the jenkins compatible XML"""

    def __init__(self, site_config):
        super().__init__(site_config, None)

    def launch(self, lcov_file, source_dir, coverage_binary, cobertura_xml, excludes):
       # pylint: disable=R0913 disable=R0902 disable=broad-except
        """ lcov to cobertura xml converter """
        binary="/usr/local/bin/lcov_cobertura"
        verbose = False # Noisy since payload ends on stdout;
        # no way to specify a file for the output.
        self.job_parameters = [
            str(lcov_file),
            '-b',
            str(source_dir), #            /home/willi/oskar/work/ArangoDB/
            '-e',
            str(coverage_binary),  #ArangoDB/build/bin/arangod
            '-o', # cobertura.xml
            str(cobertura_xml),
        ]
        for excl in excludes:
            self.job_parameters += ['--excludes', excl]
        self.params = make_default_params(verbose, "222")
        print(self.job_parameters)
        start = datetime.now()
        try:
            ret = self.run_monitored(
                binary,
                self.job_parameters,
                self.params,
                progressive_timeout=600,
                deadline_grace_period=30*60,
                identifier=binary
            )
        except Exception as ex:
            print(f'''exception in {binary} run {ex}
            {"".join(traceback.TracebackException.from_exception(ex).format())}''')
            self.params['error'] += str(ex)
        end = datetime.now()
        print(f'done with {binary} in {end-start}')
        ret = {}
        ret['error'] = self.params['error']
        return ret

def translate_xml(xmlfile):
    """ convert the directories inside the xml file """
    xmltext = xmlfile.read_text(encoding='utf8')
    xmltext = xmltext.replace('filename="', 'filename="./coverage/')
    xmlfile.write_text(xmltext)

class Gcovr(ArangoCLIprogressiveTimeoutExecutor):
    """Convert the joint report to the jenkins compatible XML"""

    def __init__(self, site_config, rootdir, xmlfile, resultfile, coverage_dir, directories):
        self.job_parameters = [
            '--print-summary',
            '--exclude-throw-branches',
            '--root', str(rootdir),
            '--xml',
            '--output', str(xmlfile),
            '--exclude-lines-by-pattern', "TRI_ASSERT",
        ]
        for one_directory in directories:
            for one_globbed in glob.glob(str(rootdir / one_directory)):
                self.job_parameters += ['-e', str(one_globbed)]
        self.job_parameters.append(str(coverage_dir))
        self.resultfile = resultfile
        self.xmlfile = xmlfile
        self.params = None
        super().__init__(site_config, None)

    def launch(self):
       # pylint: disable=R0913 disable=R0902 disable=broad-except
        """ gcov merger """
        if self.cfg.is_lcov:
            binary = "/usr/lib/llvm-16/bin/llvm-profdata"
        else:
            binary = "gcovr"
        verbose = True
        self.params = make_default_params(verbose, 111)
        print(self.job_parameters)
        start = datetime.now()
        try:
            ret = self.run_monitored(
                binary,
                self.job_parameters,
                self.params,
                progressive_timeout=600,
                deadline_grace_period=30*60,
                identifier=binary
            )
        except Exception as ex:
            print(f'''exception in {binary} run {ex}
            {"".join(traceback.TracebackException.from_exception(ex).format())}''')
            self.params['error'] += str(ex)
        end = datetime.now()
        print(f'done with {binary} in {end-start}')
        ret = {}
        ret['error'] = self.params['error']
        return ret

    def translate_xml(self):
        """ convert the directories inside the xml file """
        translate_xml(self.xmlfile)

class GcovMerger(ArangoCLIprogressiveTimeoutExecutor):
    """Merge two sets of gcov files"""

    def __init__(self, job, site_config):
        self.identifier = job[0]
        self.job = job
        self.job_parameters = ['merge', job[0], job[1], '-o', job[2]]
        self.params = None
        super().__init__(site_config, None)

    def post_process_launch(self, process):
        """ hook to work with the process while it launches """
        print(f"re-nicing {str(process)}")
        process.nice(-19)

    def launch(self):
       # pylint: disable=R0913 disable=R0902 disable=broad-except
        """ gcov merger """
        if self.cfg.is_lcov:
            binary = "/usr/lib/llvm-16/bin/llvm-profdata"
        else:
            binary = "gcov-tool"
        verbose = True
        self.params = make_default_params(verbose, 111)
        start = datetime.now()
        try:
            ret = self.run_monitored(
                binary,
                self.job_parameters,
                self.params,
                progressive_timeout=600,
                deadline_grace_period=30*60,
                identifier=self.identifier
            )
        except Exception as ex:
            print(f'''exception in {self.job[0]} {self.job[1]}: {ex}
            {"".join(traceback.TracebackException.from_exception(ex).format())}''')
            self.params['error'] += str(ex)
        end = datetime.now()
        print(f"done with {self.job[0]} {self.job[1]} in {end-start} - {ret['rc_exit']} - {self.params['output']}")
        ret = {}
        ret['error'] = self.params['error']
        for one_file in [self.job[0], self.job[1]]:
            print('cleaning up')
            cleanup_file = Path(one_file)
            print(cleanup_file)
            if cleanup_file.is_dir():
                shutil.rmtree(cleanup_file)
            elif cleanup_file.exists():
                print('delete file')
                cleanup_file.unlink()
                print('file gone')
            else:
                print(f'file {str(cleanup_file)} already gone?')
        print(f"launch(): returning {ret}")
        return ret

COV_SLOT_LOCK = Lock()
COV_WORKER_ARRAY = []
COV_JOB_QUEUE = None
COV_JOB_DONE_QUEUE = None

def gcov_merge_runner(cfg, _):
    """ thread runner for merging coverage directories """
    global COV_SLOT_LOCK, SUCCESS
    print('worker thread started')
    while True:
        job = COV_JOB_QUEUE.get()
        if job[0] == 'done':
            print('worker exiting')
            return
        print(f'thread starting {job}')
        merger = GcovMerger(job, cfg)
        ret = merger.launch()
        with COV_SLOT_LOCK:
            if ret['error'] != '':
                print(f"marking failure: {ret['error']}")
                SUCCESS = False
        print(f"marking job as done {job}")
        COV_JOB_DONE_QUEUE.put((job, ret))

def launch_worker(cfg):
    """ launch one instance """
    global COV_SLOT_LOCK
    with COV_SLOT_LOCK:
        worker = Thread(
            target=gcov_merge_runner,
            name="gcov_merger",
            args=(cfg, ''))
        worker.name="gcov_merger"
        COV_WORKER_ARRAY.append(worker)
        worker.start()
    print('thread launched')


def combine_coverage_dirs_multi(cfg,
                                gcov_dir,
                                slot_count):
    """ take all coverage databases to be found in one directory and combine them"""
    global COV_JOB_QUEUE, COV_JOB_DONE_QUEUE
    COV_JOB_QUEUE = Queue()
    COV_JOB_DONE_QUEUE = Queue()
    print(gcov_dir)
    print('8'*88)
    # Locate all directories containing coverage information;
    coverage_dirs = []
    for subdir in gcov_dir.iterdir():
        if len(str(subdir.name)) == 32:
            print(f"adding {subdir}")
            coverage_dirs.append(subdir)
        else:
            print(len(str(subdir.name)))
            print(f"Skipping {subdir}")

    # aggregate them to a tree job structure
    jobs = []
    sub_jobs = coverage_dirs
    last_output = None
    combined_dir = gcov_dir / 'combined'
    if combined_dir.exists():
        shutil.rmtree(str(combined_dir))
    combined_dir.mkdir()
    count = 0
    jobcount = 0
    if len(sub_jobs) == 0:
        print("failed to locate subjobs in {coverage_dirs}")
        return None
    if len(sub_jobs) == 1:
        print(sub_jobs)
        return sub_jobs[0]
    while len(sub_jobs) > 1:
        next_jobs = []
        jobs.append([])
        while len(sub_jobs) > 1:
            last_output = combined_dir / f'{jobcount}'
            this_subjob = [str(sub_jobs.pop()),
                           str(sub_jobs.pop()),
                           str(last_output)]
            jobs[count].append(this_subjob)
            next_jobs.append(this_subjob[2])
            jobcount += 1
        count += 1
        if len(sub_jobs) > 0:
            next_jobs.append(sub_jobs.pop())
        sub_jobs = next_jobs

    # launch workers
    total_wrk_count = worker_count = max_jobs = slot_count
    print(max_jobs)
    max_jobs = max(max_jobs, 10)
    max_jobs = 1 #####
    while worker_count > 0:
        launch_worker(cfg)
        worker_count -= 1

    # feed the workers one tree layer in one go
    for one_job_set in jobs:
        count = 0
        for one_job in one_job_set:
            COV_JOB_QUEUE.put(one_job)
            count += 1
        print(f'waiting for jobset {count} to finish')
        while count > 0:
            print('.')
            COV_JOB_DONE_QUEUE.get()
            count -= 1
        print('jobset finished')

    # terminate workers
    print('sending queue flush command')
    worker_count = total_wrk_count * 3
    while worker_count > 0:
        COV_JOB_QUEUE.put(('done', 'done', 'done'))
        worker_count -= 1
    print('waiting for jobs to exit')
    for worker in COV_WORKER_ARRAY:
        print('.')
        worker.join()
    print('all workers joined')
    sys.stdout.flush()
    if not last_output.exists():
        print(f'output {str(last_output)} not there?')
    result_dir = combined_dir / 'coverage_result'
    if last_output.exists():
        last_output.rename(result_dir)
        return result_dir
    SUCCESS=False
    print("Last output wasn't there: {str(result_dir)}")
    return None

def convert_to_lcov_file(cfg, coverage_file, lcov_file):
    """ convert the database into an lcov file """
    cov = LlvmCov(cfg)
    cov.launch(coverage_file, lcov_file)
def convert_lcov_to_cobertura(cfg, lcov_file, source_dir, binary, cobertura_xml, excludes):
    """ convert the lcov file to a cobertura xml """
    cov = LcovCobertura(cfg)
    cov.launch(lcov_file, source_dir, binary, cobertura_xml, excludes)

def main():
    """ go """
    # pylint disable=too-many-locals disable=too-many-statements
    base_dir = Path(sys.argv[1])
    coverage_dir = base_dir / 'coverage'
    if coverage_dir.exists():
        shutil.rmtree(str(coverage_dir))
    coverage_dir.mkdir()
    gcov_dir = base_dir / sys.argv[2]
    cfg = SiteConfig(gcov_dir.resolve())
    result_dir = combine_coverage_dirs_multi(
        cfg,
        gcov_dir,
        psutil.cpu_count(logical=False))

    sourcedir = base_dir / 'ArangoDB'
    if cfg.is_lcov:
        binary = sourcedir / 'build' / 'bin' / 'arangod'
        lcov_file = gcov_dir / 'coverage.lcov'
        print('converting to lcov file')
        convert_to_lcov_file(cfg, result_dir, lcov_file)
    os.chdir(base_dir)
    # copy the source files from the sourcecode directory
    for copy_dir in [
            Path('lib'),
            Path('arangosh'),
            Path('client-tools'),
            Path('arangod'),
            Path('utils/gdb-pretty-printers'),
            Path('enterprise/Enterprise'),
            Path('enterprise/tests')
    ]:
        srcdir = sourcedir / copy_dir
        if srcdir.exists():
            baselen = len(str(srcdir))
            dstdir = coverage_dir / copy_dir
            print(f"Copy {str(srcdir)} => {str(dstdir)}")

            for root, _, files in os.walk(srcdir):
                subdir = str(dstdir) + root[baselen:]
                path = Path(subdir)
                path.mkdir(parents=True, exist_ok=True)
                for filename in files:
                    source = os.path.join(root, filename)
                    shutil.copy2(source, path / filename)

    print('copy the gcno files from the build directory')
    buildir = sourcedir / 'build'
    baselen = len(str(buildir))
    for root, _, files in os.walk(buildir):
        subdir = str(coverage_dir) + root[baselen:]
        path = Path(subdir)
        path.mkdir(parents=True, exist_ok=True)
        for filename in fnmatch.filter(files, '*.gcno'):
            source = (os.path.join(root, filename))
            shutil.copy2(source, path / filename)

    print('create a symlink into the jemalloc source:')
    jmdir = sourcedir / '3rdParty' / 'jemalloc' / 'jemalloc' / 'include'
    if not jmdir.exists():
        jmdir = list((sourcedir / '3rdParty' / 'jemalloc').glob('v*'))[0] / 'include'
    (sourcedir / 'include').symlink_to(jmdir)

    cobertura_xml = coverage_dir / 'coverage.xml'
    if cfg.is_lcov:
        print('converting to cobertura report')
        convert_lcov_to_cobertura(cfg, lcov_file,
                                  sourcedir,
                                  binary,
                                  cobertura_xml,
                                  [
                                      '.*3rdParty.*',
                                      '.*usr.*',
                                      '.*tests/.*'
                                  ])
        translate_xml(cobertura_xml)
    else:
        resultfile = coverage_dir / 'summary.txt'
        gcovr = Gcovr(cfg, sourcedir, cobertura_xml, resultfile, result_dir, [
            Path('build'),
            Path('build') / '3rdParty' / 'libunwind'/ 'v*',
            Path('build') / '3rdParty' / 'libunwind' / 'v*' / 'src',
            Path('3rdParty'),
            Path('3rdParty') / 'jemalloc' / 'v*',
            Path('usr'),
            Path('tests')
            ])
        gcovr.launch()
        gcovr.translate_xml()

    if not SUCCESS:
        os._exit(1)

if __name__ == "__main__":
    main()
