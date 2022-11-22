#!/bin/env python3
""" manipulate processes """
import sys
import psutil

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
