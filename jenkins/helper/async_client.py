#!/usr/bin/env python
""" Run a javascript command by spawning an arangosh
    to the configured connection """

import os
from queue import Queue, Empty
import sys
from subprocess import PIPE, Popen
from threading import Thread
# from allure_commons._allure import attach

from asciiprint import print_progress as progress
#import tools.loghelper as lh

ON_POSIX = "posix" in sys.builtin_module_names


def dummy_line_result(line):
    """do nothing with the line..."""
    # pylint: disable=pointless-statement
    line
    return True


def enqueue_stdout(std_out, queue, instance):
    """add stdout to the specified queue"""
    for line in iter(std_out.readline, b""):
        # print("O: " + str(line))
        queue.put((line, instance))
    # print('0 done!')
    queue.put(-1)
    std_out.close()


def enqueue_stderr(std_err, queue, instance):
    """add stderr to the specified queue"""
    for line in iter(std_err.readline, b""):
        # print("E: " + str(line))
        queue.put((line, instance))
    # print('1 done!')
    queue.put(-1)
    std_err.close()


def convert_result(result_array):
    """binary -> string"""
    result = ""
    for one_line in result_array:
        result += "\n" + one_line[0].decode("utf-8").rstrip()
    return result


class CliExecutionException(Exception):
    """transport CLI error texts"""

    def __init__(self, message, execution_result, have_timeout):
        super().__init__()
        self.execution_result = execution_result
        self.message = message
        self.have_timeout = have_timeout


class ArangoCLIprogressiveTimeoutExecutor:
    """
    Abstract base class to run arangodb cli tools
    with username/password/endpoint specification
    timeout will be relative to the last thing printed.
    """

    # pylint: disable=too-few-public-methods too-many-arguments disable=too-many-instance-attributes disable=too-many-statements disable=too-many-branches disable=too-many-locals
    def __init__(self, config, connect_instance):
        """launcher class for cli tools"""
        self.connect_instance = connect_instance
        self.cfg = config

    def run_arango_tool_monitored(
        self,
        executeable,
        more_args,
        timeout=60,
        result_line=dummy_line_result,
        verbose=False,
        expect_to_fail=False,
        use_default_auth=True,
        logfile=None
    ):
        """
        runs a script in background tracing with
        a dynamic timeout that its got output
        (is still alive...)
        """
        # fmt: off
        passvoid = ''
        if self.cfg.passvoid:
            passvoid  = str(self.cfg.passvoid)
        elif self.connect_instance:
            passvoid = str(self.connect_instance.get_passvoid())
        if passvoid is None:
            passvoid = ''

        run_cmd = [
            "--log.foreground-tty", "true",
            "--log.force-direct", "true",
        ]
        if self.connect_instance:
            run_cmd += ["--server.endpoint", self.connect_instance.get_endpoint()]
            if use_default_auth:
                run_cmd += ["--server.username", str(self.cfg.username)]
                run_cmd += ["--server.password", passvoid]

        run_cmd += more_args
        return self.run_monitored(executeable, run_cmd, timeout, result_line, verbose, expect_to_fail, logfile)
        # fmt: on

    def run_monitored(
            self, executeable, args, timeout=60, result_line=dummy_line_result, verbose=False, expect_to_fail=False, logfile=None
    ):
        """
        run a script in background tracing with a dynamic timeout that its got output (is still alive...)
        """

        run_cmd = [executeable] + args
        print(run_cmd, verbose)
        with Popen(
            run_cmd,
            stdout=PIPE,
            stderr=PIPE,
            close_fds=ON_POSIX,
            cwd=self.cfg.base_path.resolve(),
        ) as process:
            queue = Queue()
            thread1 = Thread(
                name="readIO",
                target=enqueue_stdout,
                args=(process.stdout, queue, self.connect_instance),
            )
            thread2 = Thread(
                name="readErrIO",
                target=enqueue_stderr,
                args=(process.stderr, queue, self.connect_instance),
            )
            thread1.start()
            thread2.start()

            try:
                print(
                    "me PID:%d launched PID:%d with LWPID:%d and LWPID:%d"
                    % (os.getpid(), process.pid, thread1.native_id, thread2.native_id)
                )
            except AttributeError:
                print("me PID:%d launched PID:%d with LWPID:N/A and LWPID:N/A" % (os.getpid(), process.pid))

            # ... do other things here
            out = None
            if logfile:
                out = logfile.open('wb')
            # read line without blocking
            have_timeout = False
            line_filter = False
            tcount = 0
            close_count = 0
            result = []
            while not have_timeout:
                #if not verbose:
                #    progress("sj" + str(tcount))
                line = ""
                try:
                    line = queue.get(timeout=1)
                    line_filter = line_filter or result_line(line)
                except Empty:
                    tcount += 1
                    #if verbose:
                    #    progress("T " + str(tcount))
                    have_timeout = tcount >= timeout
                else:
                    tcount = 0
                    if isinstance(line, tuple):
                        #if verbose:
                        #    print("e: " + str(line[0]))
                        if out:
                            out.write(line[0])
                        #if not str(line[0]).startswith("#"):
                        #    result.append(line)
                    else:
                        close_count += 1
                        if close_count == 2:
                            print(" done!")
                            break
            if out:
                out.close()
            timeout_str = ""
            if have_timeout:
                timeout_str = "TIMEOUT OCCURED!"
                print(timeout_str)
                timeout_str += "\n"
                process.kill()
            rc_exit = process.wait()
            thread1.join()
            thread2.join()

        # attach(str(rc_exit), f"Exit code: {str(rc_exit)}")

        if have_timeout or rc_exit != 0:
            res = (False, timeout_str,
                   # convert_result(result),
                   rc_exit, line_filter)
            #if expect_to_fail:
            return res
            #raise CliExecutionException(f"Execution failed. {res} {have_timeout}", res, have_timeout)

        if not expect_to_fail:
            if len(result) == 0:
                res = (True, "", 0, line_filter)
            else:
                res = (True, "" ,
                       #convert_result(result),
                       0, line_filter)
            return res

        if len(result) == 0:
            res = (True, "", 0, line_filter)
        else:
            res = (True, "",
                   #convert_result(result),
                   0, line_filter)
        raise CliExecutionException("Execution was expected to fail, but exited successfully.", res, have_timeout)