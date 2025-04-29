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

if not 'CLANG_VERSION' in os.environ:
    os.environ['CLANG_VERSION'] = ''
LLVM_COV = Path(f"/usr/lib/llvm-{os.environ['CLANG_VERSION']}/bin/llvm-cov")
if not LLVM_COV.exists():
    LLVM_COV = Path("/usr/lib/llvm/bin/llvm-cov")
LLVM_PROFDATA = Path(f"/usr/lib/llvm-{os.environ['CLANG_VERSION']}/bin/llvm-profdata")
if not LLVM_PROFDATA.exists():
    LLVM_PROFDATA = Path("/usr/lib/llvm/bin/llvm-profdata")

SUCCESS = True

# pylint disable=global-variable-not-assigned disable=global-statement

class LlvmCov(ArangoCLIprogressiveTimeoutExecutor):
    """Convert the joint report to the jenkins compatible XML"""

    def __init__(self, site_config):
        self.job_parameters = []
        self.params = {}
        super().__init__(site_config, None)

    def launch(self, coverage_file, lcov_file):
       # pylint: disable=R0913 disable=R0902 disable=broad-except
        """ gcov merger """
        verbose = True
        binary = str(LLVM_COV)
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
        self.job_parameters = []
        self.params = {}
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
    xml_file_size = xmlfile.stat().st_size
    xmltext = xmlfile.read_text(encoding='utf8')
    xmlsize = len(xmltext)
    xmltext = xmltext.replace('filename="', 'filename="./coverage/')
    xmlfile.write_text(xmltext)
    print(f"Result XML size: {xmlsize} => {len(xmltext)} Files: {xml_file_size} => {xmlfile.stat().st_size}")


class LcovMerger(ArangoCLIprogressiveTimeoutExecutor):
    """Merge two sets of gcov files"""

    def __init__(self, job, site_config):
        self.identifier = job[0]
        self.job = job
        self.job_parameters = ['merge', job[0], job[1], '-o', job[2]]
        self.outdir = Path(job[2])
        self.params = None
        super().__init__(site_config, None)

    def post_process_launch(self, process):
        """ hook to work with the process while it launches """
        # print(f"re-nicing {str(process)}")
        # process.nice(-19)

    def launch(self):
       # pylint: disable=R0913 disable=R0902 disable=broad-except
        """ gcov merger """
        verbose = False
        self.params = make_default_params(verbose, 111)
        binary = str(LLVM_PROFDATA)
        print([binary] + self.job_parameters)
        start = datetime.now()
        ret = {"rc_exit": 3333}
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
        filecount = 0
        if self.outdir.is_file():
            filecount = self.outdir.stat().st_size
        else:
            for _ in glob.iglob(str(self.outdir) + '**/**', recursive=True):
                filecount += 1

        print(f"done with {self.job[0]} +  {self.job[1]} in {end-start} - {ret['rc_exit']} - {self.params['output']} => {filecount}")
        ret['error'] = self.params['error']
        if ret['rc_exit'] != 0:
            print(f"mitigating error: {self.params['error']}")
            if self.params['error'].find(self.job[0]) > 0:
                print(f"skipping {self.job[0]}")
                Path(self.job[1]).rename(Path(self.params['output']))
            elif self.params['error'].find(self.job[1]) > 0:
                print(f"skipping {self.job[1]}")
                Path(self.job[1]).rename(Path(self.params['output']))
            else:
                print("none of our files found in the error message!")
        elif self.job[2]:
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
                print(f"skipping {self.job[0]}")
            else:
                print(f"skipping this layer with {self.job[0]} {self.job[1]}")
        print(f"launch(): returning {ret}")
        return ret

COV_SLOT_LOCK = Lock()
COV_WORKER_ARRAY = []
COV_JOB_QUEUE = None
COV_JOB_DONE_QUEUE = None

def lcov_merge_runner(cfg, _):
    """ thread runner for merging coverage directories """
    global COV_SLOT_LOCK, SUCCESS
    print('worker thread started')
    while True:
        job = COV_JOB_QUEUE.get()
        if job[0] == 'done':
            print('worker exiting')
            return
        print(f'thread starting {job}')
        merger = LcovMerger(job, cfg)
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
            target=lcov_merge_runner,
            args=(cfg, ''))
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
    if gcov_dir.is_file():
        # we could have `testingjs` file here...
        gcov_dir = (gcov_dir / '..').resolve()
    if not gcov_dir.is_dir():
        print(f"the specified dir is not a directory! {gcov_dir}")
        os._exit(1)
    for subdir in gcov_dir.iterdir():
        print(f"subdir: {str(subdir.name)}")
        if ((len(str(subdir.name)) == 32) or
            len(str(subdir.name)) > 32 and str(subdir.name).endswith("arangod")):
            subdir_props = subdir.stat()
            print(f"adding {subdir} => {subdir_props}")
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
    #coverage_dir = base_dir / 'coverage'
    #if coverage_dir.exists():
    #    shutil.rmtree(str(coverage_dir))
    #coverage_dir.mkdir()
    count = 0
    jobcount = 0
    if len(sub_jobs) == 0:
        print(f"failed to locate subjobs in {coverage_dirs}")
        return None
    if len(sub_jobs) == 1:
        print(sub_jobs)
        return sub_jobs[0]
    layer = 0
    while len(sub_jobs) > 1:
        next_jobs = []
        jobs.append([])
        while len(sub_jobs) > 1:
            last_output = combined_dir / f'{jobcount}'
            this_subjob = [str(sub_jobs.pop()),
                           str(sub_jobs.pop()),
                           str(last_output),
                           count < 5]
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
        SUCCESS = False
        print(f'output {str(last_output)} not there?')
        return None
    result_dir = combined_dir / 'coverage_result'
    last_output.rename(result_dir)
    return result_dir

def convert_to_lcov_file(cfg, coverage_file, lcov_file):
    """ convert the database into an lcov file """
    cov = LlvmCov(cfg)
    cov.launch(coverage_file, lcov_file)
def convert_lcov_to_cobertura(cfg, lcov_file, source_dir, binary, cobertura_xml, excludes):
    """ convert the lcov file to a cobertura xml """
    cov = LcovCobertura(cfg)
    cov.launch(lcov_file, source_dir, binary, cobertura_xml, excludes)

def copy_source_directory(sourcedir, coverage_dir):
    """ copy the source files from the sourcecode directory """
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
    print('create a symlink into the jemalloc source:')
    jmdir = sourcedir / '3rdParty' / 'jemalloc' / 'jemalloc' / 'include'
    if not jmdir.exists():
        jmdir = list((sourcedir / '3rdParty' / 'jemalloc').glob('v*'))[0] / 'include'
    (sourcedir / 'include').symlink_to(jmdir)

def main():
    """ go """
    # pylint disable=too-many-locals disable=too-many-statements
    base_dir = Path(sys.argv[1])
    os.chdir(base_dir)
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
    binary = sourcedir / 'build' / 'bin' / 'arangod'
    lcov_file = gcov_dir / 'coverage.lcov'

    copy_source_directory(sourcedir, coverage_dir)

    print('converting to lcov file')
    convert_to_lcov_file(cfg, result_dir, lcov_file)
    print('copy the gcno files from the build directory')
    buildir = sourcedir / 'build'
    baselen = len(str(buildir))
    for root, _, files in os.walk(buildir):
        subdir = str(coverage_dir) + root[baselen:]
        path = Path(subdir)
        path.mkdir(parents=True, exist_ok=True)
        for filename in fnmatch.filter(files, '*.gcno'):
            source = os.path.join(root, filename)
            shutil.copy2(source, path / filename)

    cobertura_xml = coverage_dir / 'coverage.xml'
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

    if not SUCCESS:
        os._exit(1)

if __name__ == "__main__":
    main()
