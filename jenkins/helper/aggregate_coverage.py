#!/usr/bin/env python3
"""test drivers"""
from datetime import datetime
import os
import shutil
import sys
from queue import Queue
from pathlib import Path
from threading  import Thread, Lock

import psutil

from async_client import (
    ArangoCLIprogressiveTimeoutExecutor,
    make_default_params
)

from site_config import SiteConfig

SUCCESS=True

# pylint disable=global-variable-not-assigned

class GcovMerger(ArangoCLIprogressiveTimeoutExecutor):
    """configuration"""

    def __init__(self, jobs, site_config):
        self.identifier = jobs[0]
        self.job = jobs
        self.job_parameters = ['merge', jobs[0], jobs[1], '-o', jobs[2]]
        self.params = None
        super().__init__(site_config, None)

    def launch(self):
       # pylint: disable=R0913 disable=R0902 disable=broad-except
        """ gcov merger """
        print('------')
        verbose = True
        self.params = make_default_params(verbose, 111)
        print(self.params)
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
        print(f'done with {self.job[0]} {self.job[1]} in {end-start} - {ret}')
        #delete_logfile_params(params)
        ret = {}
        ret['error'] = self.params['error']
        shutil.rmtree(self.job[0])
        shutil.rmtree(self.job[1])
        return ret

    def end_run(self):
        """ terminate dmesg again """
        print(f"killing gcov-tool {self.params['pid']}")
        try:
            psutil.Process(self.params['pid']).kill()
        except psutil.NoSuchProcess:
            print('dmesg already gone?')

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
    gcov_dir = Path(sys.argv[1])
    cfg = SiteConfig(gcov_dir.resolve())
    coverage_dirs = []
    for subdir in gcov_dir.iterdir():
        if subdir.is_dir() and len(str(subdir.name)) == 32:
            coverage_dirs.append(subdir)
        else:
            print(len(str(subdir.name)))
            print(f"Skipping {subdir}")
    jobs = []
    sub_jobs = coverage_dirs
    last_output = ''
    combined_dir = gcov_dir / 'combined'
    if combined_dir.exists():
        shutil.rmtree(str(combined_dir))
    combined_dir.mkdir()
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

    worker_count = max_jobs = psutil.cpu_count(logical=False)
    print(max_jobs)
    max_jobs = max(max_jobs, 10)
    while worker_count > 0:
        launch_worker(cfg)
        worker_count -= 1
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
    print('sending queue flush command')
    worker_count = max_jobs
    while worker_count > 0:
        JOB_QUEUE.put(('done', 'done', 'done'))
        worker_count -= 1

    worker_count = max_jobs
    for worker in WORKER_ARRAY:
        worker.join()

    last_output.rename(Path(sys.argv[2]))
    if not SUCCESS:
        os.exit(1)

if __name__ == "__main__":
    main()
