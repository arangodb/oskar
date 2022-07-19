#!/usr/bin/env python
""" Run a javascript command by spawning an arangosh
    to the configured connection """
import os
from queue import Queue, Empty
import platform
import signal
import sys
from datetime import datetime
from subprocess import PIPE
from threading import Thread
import psutil
# from allure_commons._allure import attach

# from asciiprint import print_progress as progress
#import tools.loghelper as lh

ON_POSIX = "posix" in sys.builtin_module_names
IS_WINDOWS = platform.win32_ver()[0] != ""
def dummy_line_result(line):
    """do nothing with the line..."""
    # pylint: disable=pointless-statement
    line
    return True


def enqueue_stdout(std_out, queue, instance, identifier):
    """add stdout to the specified queue"""
    try:
        for line in iter(std_out.readline, b""):
            # print("O: " + str(line))
            queue.put((line, instance))
    except ValueError as ex:
        print(f"{identifier} communication line seems to be closed: {str(ex)}")
    print(f"{identifier} x0 done!")
    queue.put(-1)
    std_out.close()


def enqueue_stderr(std_err, queue, instance, identifier):
    """add stderr to the specified queue"""
    try:
        for line in iter(std_err.readline, b""):
            # print("E: " + str(line))
            queue.put((line, instance))
    except ValueError as ex:
        print(f"{identifier} communication line seems to be closed: {str(ex)}")
    print(f"{identifier} x1 done!")
    queue.put(-1)
    std_err.close()


def convert_result(result_array):
    """binary -> string"""
    result = ""
    for one_line in result_array:
        result += "\n" + one_line[0].decode("utf-8").rstrip()
    return result

def kill_children(identifier, children):
    """ slash all processes enlisted in children - if they still exist """
    for one_child in children:
        try:
            print(f"{identifier}: killing {one_child.name()} - {str(one_child.pid)}")
            one_child.kill()
            one_child.wait()
        except psutil.NoSuchProcess:  # pragma: no cover
            pass

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
            deadline=0,
            result_line=dummy_line_result,
            verbose=False,
            expect_to_fail=False,
            use_default_auth=True,
            logfile=None,
            identifier=""
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
        return self.run_monitored(executeable,
                                  run_cmd,
                                  timeout,
                                  deadline,
                                  result_line,
                                  verbose,
                                  expect_to_fail,
                                  logfile,
                                  identifier)
        # fmt: on

    def run_monitored(self,
                      executeable,
                      args,
                      timeout=60,
                      deadline=0,
                      result_line=dummy_line_result,
                      verbose=False, expect_to_fail=False, logfile=None,
                      identifier=""
                      ):
        """
        run a script in background tracing with a dynamic timeout that its got output
        Deadline will represent an absolute timeout at which it will be signalled to
        exit, and yet another minute later a hard kill including sub processes will
        follow.
        (is still alive...)
        """
        rc_exit = None
        run_cmd = [executeable] + args
        children = []
        print(run_cmd, verbose)
        with psutil.Popen(
            run_cmd,
            stdout=PIPE,
            stderr=PIPE,
            close_fds=ON_POSIX,
            cwd=self.cfg.base_path.resolve(),
        ) as process:
            queue = Queue()
            thread1 = Thread(
                name=f"readIO {identifier}",
                target=enqueue_stdout,
                args=(process.stdout, queue, self.connect_instance, identifier),
            )
            thread2 = Thread(
                name="readErrIO {identifier}",
                target=enqueue_stderr,
                args=(process.stderr, queue, self.connect_instance, identifier),
            )
            thread1.start()
            thread2.start()
            print(dir(process))
            try:
                print(
                    "{0} me PID:{1} launched PID:{2} with LWPID:{3} and LWPID:{4}".format(
                        identifier,
                        str(os.getpid()),
                        str(process.pid),
                        str(thread1.native_id),
                        str(thread2.native_id))
                )
            except AttributeError:
                print(
                    "{0} me PID:{1} launched PID:{2} with LWPID:N/A and LWPID:N/A".format(
                        identifier,
                        str(os.getpid()),
                        str(process.pid)))

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
            have_deadline = 0
            deadline_wait_count = 0
            while not have_timeout:
                #if not verbose:
                #    progress("sj" + str(tcount))
                line = ""
                empty = False
                try:
                    line = queue.get(timeout=1)
                    line_filter = line_filter or result_line(line)
                except Empty:
                    # print(identifier  + '..' + str(deadline_wait_count))
                    empty = True
                    tcount += 1
                    #if verbose:
                    #    progress("T " + str(tcount))
                    have_timeout = tcount >= timeout
                    if have_timeout:
                        children = process.children(recursive=True)
                        process.kill()
                        kill_children(identifier, children)
                        rc_exit = process.wait()
                    if datetime.now() > deadline:
                        have_deadline += 1
                if have_deadline == 1:
                    have_deadline += 1
                    print(f"{identifier} Deadline reached! Signaling  {str(run_cmd)}")
                    sys.stdout.flush()
                    # Send testing.js break / sigint
                    children = process.children(recursive=True)
                    if IS_WINDOWS:
                        process.send_signal(signal.CTRL_BREAK_EVENT)
                    else:
                        process.send_signal(signal.SIGINT)
                elif have_deadline > 1:
                    try:
                        # give it some time to exit:
                        print(f"{identifier} try wait exit:")
                        children = children + process.children(recursive=True)
                        rc_exit = process.wait(1)
                        print(f"{identifier}  exited: {str(rc_exit)}")
                        kill_children(identifier, children)
                        # print(f"{identifier} flushing")
                        # process.stderr.flush()
                        # process.stdout.flush()
                        print(f"{identifier}  closing")
                        process.stderr.close()
                        process.stdout.close()
                        break
                    except psutil.TimeoutExpired:
                        deadline_wait_count += 1
                        print(f"{identifier} timeout waiting for exit {str(deadline_wait_count)}")
                        # if its not willing, use force:
                        if deadline_wait_count > 60:
                            print(f"{identifier} getting children")
                            children = process.children(recursive=True)
                            kill_children(identifier, children)
                            print(f"{identifier} killing")
                            process.kill()
                            print(f"{identifier} waiting")
                            rc_exit = process.wait()
                            print(f"{identifier} closing")
                            process.stderr.close()
                            process.stdout.close()
                            break

                elif not empty:
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
                        print(f"{identifier} 1 IO Thead done!")
                        if close_count == 2:
                            break
            print(f"{identifier} IO-Loop done")
            if out:
                print(f"{identifier} closing {logfile}")
                out.close()
                print(f"{identifier} {logfile} closed")
            timeout_str = ""
            if have_timeout:
                timeout_str = "TIMEOUT OCCURED!"
                print(timeout_str)
                timeout_str += "\n"
            elif rc_exit is None:
                print(f"{identifier} waiting for exit")
                rc_exit = process.wait()
                print(f"{identifier} done")
            print(f"{identifier} joining io Threads")
            kill_children(identifier, children)
            thread1.join()
            thread2.join()
            print(f"{identifier} OK")

        # attach(str(rc_exit), f"Exit code: {str(rc_exit)}")

        if have_timeout or rc_exit != 0:
            res = (False, timeout_str,
                   # convert_result(result),
                   rc_exit, line_filter)
            #if expect_to_fail:
            return res
            #raise CliExecutionException("Execution failed. {res} {have_timeout}".format(
            # (res, have_timeout))

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
        raise CliExecutionException(
            f"{identifier} Execution was expected to fail, but exited successfully.",
            res, have_timeout)
