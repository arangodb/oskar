#!/usr/bin/env python3
"""test drivers"""
import shutil
import sys
import time
from pathlib import Path
from threading  import Thread, Lock

import psutil

from async_client import (
    ArangoCLIprogressiveTimeoutExecutor,
    make_default_params,
    default_line_result
)

from site_config import SiteConfig
# pylint disable=global-variable-not-assigned

class GcovMerger(ArangoCLIprogressiveTimeoutExecutor):
    """configuration"""

    def __init__(self, jobs, site_config):
        self.identifier = jobs[0]
        self.job = ['merge', jobs[0], jobs[1], '-o', jobs[2]]
        self.params = None
        super().__init__(site_config, None)

    def launch(self):
       # pylint: disable=R0913 disable=R0902
        """ gcov merger """
        print('------')
        verbose = True
        self.params = make_default_params(verbose, 111)
        print(self.params)
        ret = self.run_monitored(
            "gcov-tool",
            self.job,
            self.params
        )
        #delete_logfile_params(params)
        ret = {}
        ret['error'] = self.params['error']
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

def gcov_merge_runner(abcde, instance):
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
        worker.start()
        JOB_SLOT_ARRAY.append((worker, merger))

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

    max_jobs = 5 # psutil.cpu_count(logical=False)
    active_job_count = 0
    ccc = 0
    for one_job_set in jobs:
        local_active_job = 0
        for one_job in one_job_set:
            with SLOT_LOCK:
                local_active_job = len(JOB_SLOT_ARRAY)
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
            time.sleep(1)

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
# """
# and for i in gcov/????????????????????????????????
#   if test $c -eq 0
#     echo "first file $i"
#     and cp -a $i combined/1
#     and set c 1
#   else if test $c -eq 1
#     echo "merging $i"
#     and rm -rf combined/2
#     and gcov-tool merge $i combined/1 -o combined/2
#     and set c 2
#   else if test $c -eq 2
#     echo "merging $i"
#     and rm -rf combined/1
#     and gcov-tool merge $i combined/2 -o combined/1
#     and set c 1
#   end
# end
#         core_zip_dir = get_workspace() / 'coredumps'
#         core_zip_dir.mkdir(parents=True, exist_ok=True)
#         zip_slots = psutil.cpu_count(logical=False)
#         count = 0
#         zip_slot_array = []
#         for _ in range(zip_slots):
#             zip_slot_array.append([])
#         for one_file in core_files_list:
#             if one_file.exists():
#                 zip_slot_array[count % zip_slots].append(one_file)
#                 count += 1
#         zippers = []
#         print(f"coredump launching zipper sub processes {zip_slot_array}")
#         for zip_slot in zip_slot_array:
#             if len(zip_slot) > 0:
#                 proc = Process(target=zipp_this, args=(zip_slot, core_zip_dir))
#                 proc.start()
#                 zippers.append(proc)
#         for zipper in zippers:
#             zipper.join()
#         print("compressing files done")
# 
#         for one_file in core_files_list:
#             if one_file.is_file():
#                 one_file.unlink(missing_ok=True)
# """
# 
