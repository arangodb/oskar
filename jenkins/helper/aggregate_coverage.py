#!/usr/bin/env python3
"""test drivers"""
from datetime import datetime
import shutil
import sys
import time
from pathlib import Path
from threading  import Thread, Lock

import psutil

from async_client import (
    ArangoCLIprogressiveTimeoutExecutor,
    make_default_params
)

from site_config import SiteConfig
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
       # pylint: disable=R0913 disable=R0902
        """ gcov merger """
        print('------')
        verbose = True
        self.params = make_default_params(verbose, 111)
        print(self.params)
        start = datetime.now()
        ret = self.run_monitored(
            "gcov-tool",
            self.job_parameters,
            self.params,
            progressive_timeout=600,
            deadline_grace_period=30*60,
            identifier=self.identifier
        )
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
JOB_SLOT_ARRAY = []
JOB_DONE_ARRAY = []

def gcov_merge_runner(_, instance):
    """ thread runner """
    global JOB_DONE_ARRAY, SLOT_LOCK
    print(f'thread started {instance.job}')
    instance.launch()
    with SLOT_LOCK:
        count = 0
        for job in JOB_SLOT_ARRAY:
            if job[1].identifier == instance.identifier:
                break
            count += 1
        job = JOB_SLOT_ARRAY.pop(count)
        JOB_DONE_ARRAY.append(job)

def launch_gcov_merge(jobs, cfg):
    """ launch one instance """
    global JOB_DONE_ARRAY, SLOT_LOCK, JOB_DONE_ARRAY
    merger = GcovMerger(jobs, cfg)
    with SLOT_LOCK:
        worker = Thread(target=gcov_merge_runner,
                        args=('true', merger))
        JOB_SLOT_ARRAY.append((worker, merger))
        worker.start()
    print('thread launched')

def main():
    """ go """
    # pylint disable=too-many-locals disable=too-many-statements
    global JOB_DONE_ARRAY, SLOT_LOCK, JOB_DONE_ARRAY
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
    count = 0
    jobcount = 0
    last_output = ''
    combined_dir = gcov_dir / 'combined'
    if combined_dir.exists():
        shutil.rmtree(str(combined_dir))
    combined_dir.mkdir()
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

    max_jobs = psutil.cpu_count(logical=False)
    print(max_jobs)
    if max_jobs < 10:
        max_jobs = 10
    active_job_count = 0
    ccc = 0
    for one_job_set in jobs:
        local_active_job = 0
        for one_job in one_job_set:
            with SLOT_LOCK:
                local_active_job = len(JOB_SLOT_ARRAY)
            print(local_active_job)
            while active_job_count >= max_jobs:
                print('.')
                time.sleep(1)
                with SLOT_LOCK:
                    local_active_job = len(JOB_SLOT_ARRAY)
                    if len(JOB_DONE_ARRAY) > 0:
                        for finished_job in JOB_DONE_ARRAY:
                            finished_job.join()
                        JOB_DONE_ARRAY = []
            print(f"launching {one_job}")
            launch_gcov_merge(one_job, cfg)
            ccc += 1
            time.sleep(0.2)

        with SLOT_LOCK:
            local_active_job = len(JOB_SLOT_ARRAY)
        while local_active_job > 0:
            time.sleep(1)
            with SLOT_LOCK:
                local_active_job = len(JOB_SLOT_ARRAY)
        with SLOT_LOCK:
            local_active_job = len(JOB_SLOT_ARRAY)
            if len(JOB_DONE_ARRAY) > 0:
                for finished_job in JOB_DONE_ARRAY:
                    finished_job[0].join()
                JOB_DONE_ARRAY = []
    last_output.rename(Path(sys.argv[2]))

if __name__ == "__main__":
    main()
