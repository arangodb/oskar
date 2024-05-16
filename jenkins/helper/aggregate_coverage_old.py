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

import psutil
from async_client import (
    ArangoCLIprogressiveTimeoutExecutor,
    make_default_params,
    # make_logfile_params
)

from site_config import SiteConfig, TEMP

SUCCESS = True

# pylint disable=global-variable-not-assigned

class Gcovr(ArangoCLIprogressiveTimeoutExecutor):
    """configuration"""

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
        verbose = True
        self.params = make_default_params(verbose, 111)
        print(self.job_parameters)
        start = datetime.now()
        try:
            ret = self.run_monitored(
                "gcovr",
                self.job_parameters,
                self.params,
                progressive_timeout=600,
                deadline_grace_period=30*60,
                identifier='gcovr'
            )
        except Exception as ex:
            print('exception in gcovr run')
            self.params['error'] += str(ex)
        end = datetime.now()
        print(f'done with gcovr in {end-start}')
        ret = {}
        ret['error'] = self.params['error']
        return ret

    def translate_xml(self):
        """ convert the directories inside the xml file """
        xmltext = self.xmlfile.read_text(encoding='utf8')
        xmltext = xmltext.replace('filename="', 'filename="./coverage/')
        self.xmlfile.write_text(xmltext)

class GcovMerger(ArangoCLIprogressiveTimeoutExecutor):
    """configuration"""

    def __init__(self, job, site_config):
        self.identifier = job[0]
        self.job = job
        self.job_parameters = ['merge', job[0], job[1], '-o', job[2]]
        self.params = None
        super().__init__(site_config, None)

    def launch(self):
       # pylint: disable=R0913 disable=R0902 disable=broad-except
        """ gcov merger """
        verbose = False
        self.params = make_default_params(verbose, 111)
        start = datetime.now()
        try:
            ret = self.run_monitored(
                "gcov-tool",
                self.job_parameters,
                self.params,
                progressive_timeout=600,
                deadline_grace_period=30*60,
                identifier=self.identifier
            )
        except Exception as ex:
            print(f'exception in {self.job[0]} {self.job[1]}: {ex}')
            self.params['error'] += str(ex)
        end = datetime.now()
        print(f"done with {self.job[0]} {self.job[1]} in {end-start} - {ret['rc_exit']} - {self.params['output']}")
        ret = {}
        ret['error'] = self.params['error']
        shutil.rmtree(self.job[0])
        shutil.rmtree(self.job[1])
        return ret

SLOT_LOCK = Lock()
WORKER_ARRAY = []
JOB_QUEUE = Queue()
JOB_DONE_QUEUE = Queue()

def gcov_merge_runner(cfg, _):
    """ thread runner """
    global SLOT_LOCK, SUCCESS
    print('worker thread started')
    while True:
        job = JOB_QUEUE.get()
        if job[0] == 'done':
            print('worker exiting')
            return
        print(f'thread starting {job}')
        merger = GcovMerger(job, cfg)
        ret = merger.launch()
        with SLOT_LOCK:
            if ret['error'] != '':
                print(f"marking failure: {ret['error']}")
                SUCCESS = False
        JOB_DONE_QUEUE.put((job, ret))

def launch_worker(cfg):
    """ launch one instance """
    global SLOT_LOCK
    with SLOT_LOCK:
        worker = Thread(target=gcov_merge_runner,
                        args=(cfg, ''))
        WORKER_ARRAY.append(worker)
        worker.start()
    print('thread launched')

def main():
    """ go """
    # pylint disable=too-many-locals disable=too-many-statements
    global SLOT_LOCK, SUCCESS
    base_dir = Path(sys.argv[1])
    os.chdir(base_dir)
    gcov_dir = base_dir / sys.argv[2]
    cfg = SiteConfig(gcov_dir.resolve())

    # Locate all directories containing coverage information;
    coverage_dirs = []
    for subdir in gcov_dir.iterdir():
        if subdir.is_dir() and len(str(subdir.name)) == 32:
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
    coverage_dir = base_dir / 'coverage'
    if coverage_dir.exists():
        shutil.rmtree(str(coverage_dir))
    coverage_dir.mkdir()
    count = 0
    jobcount = 0
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
    worker_count = max_jobs = psutil.cpu_count(logical=False)
    print(max_jobs)
    max_jobs = max(max_jobs, 10)
    while worker_count > 0:
        launch_worker(cfg)
        worker_count -= 1

    # feed the workers one tree layer in one go
    for one_job_set in jobs:
        count = 0
        for one_job in one_job_set:
            JOB_QUEUE.put(one_job)
            count += 1
        print(f'waiting for jobset {count} to finish')
        while count > 0:
            print('.')
            JOB_DONE_QUEUE.get()
            count -= 1
        print('jobset finished')

    # terminate workers
    print('sending queue flush command')
    worker_count = max_jobs * 2
    while worker_count > 0:
        JOB_QUEUE.put(('done', 'done', 'done'))
        worker_count -= 1
    print('waiting for jobs to exit')
    for worker in WORKER_ARRAY:
        print('.')
        worker.join()
    print('all workers joined')
    sys.stdout.flush()
    if not last_output.exists():
        print(f'output {str(last_output)} not there?')
    result_dir = combined_dir / 'result'
    last_output.rename(result_dir)

    sourcedir = base_dir / 'ArangoDB'
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
                    source = (os.path.join(root, filename))
                    shutil.copy2(source, path / filename)

    print('copy the gcno files from the build directory')
    buildir = sourcedir / 'build'
    baselen = len(str(buildir))
    for root, _, files in os.walk(buildir):
        subdir = str(result_dir) + root[baselen:]
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

    xmlfile = coverage_dir / 'coverage.xml'
    resultfile = coverage_dir / 'summary.txt'
    gcovr = Gcovr(cfg, sourcedir, xmlfile, resultfile, result_dir, [
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
