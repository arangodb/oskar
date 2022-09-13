#!/usr/bin/python3
""" aimns to purge all resources that are stray and hinder ci work by blocking resources """
import collections
import os
import sys
import psutil
# pylint: disable=bare-except disable=broad-except
arango_processes = [
    "arangod",
    "arangodb",
    "arangosync",
    "arangosh",
    "arangodbtests"
]

def print_tree(parent, tree, indent=''):
    """ print the process tree """
    try:
        name = psutil.Process(parent).name()
    except psutil.Error:
        name = "?"
    print(parent, name)
    if parent not in tree:
        return
    children = tree[parent][:-1]
    for child in children:
        sys.stdout.write(indent + "|- ")
        print_tree(child, tree, indent + "| ")
    child = tree[parent][-1]
    sys.stdout.write(indent + "`_ ")
    print_tree(child, tree, indent + "  ")

def get_and_kill_all_processes():
    """fetch all possible running processes that we may have spawned"""
    print("searching for leftover processes")
    processes = psutil.process_iter(['pid', 'name', 'username'])
    interresting_processes = []
    pid = -1
    if 'SSH_AGENT_PID' in os.environ:
        pid = int(os.environ['SSH_AGENT_PID'])
        print("having agent PID: " + str(pid))
    for process in processes:
        try:
            name = process.name()
            print(f"{name} - {process.username()} {process.pid}")
            for match_process in arango_processes:
                if name.startswith(match_process):
                    interresting_processes.append(process)
            if pid >= 0:
                if (name.startswith('ssh-agent') and
                    (process.username() == 'jenkins') and
                    int(process.pid) != pid):
                    interresting_processes.append(process)
        except:
            pass

    if len(interresting_processes) == 0:
        print("system clean")
    else:
        for process in interresting_processes:
            try:
                print("will kill " + str(process))
            except:
                pass
            try:
                process.kill()
            except Exception as ex:
                print("failed to kill process!" + str(ex))

def main():
    """
    construct a dict where 'values' are all the processes
    having 'key' as their parent
    """
    tree = collections.defaultdict(list)
    for process in psutil.process_iter():
        try:
            tree[process.ppid()].append(process.pid)
        except (psutil.NoSuchProcess, psutil.ZombieProcess):
            pass
    # on systems supporting PID 0, PID 0's parent is usually 0
    if 0 in tree and 0 in tree[0]:
        tree[0].remove(0)
    print_tree(min(tree), tree)
    get_and_kill_all_processes()
main()
