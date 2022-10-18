#!/usr/bin/python3
""" aimns to purge all resources that are stray and hinder ci work by blocking resources """
import collections
import os
import sys
import platform
import psutil
# pylint: disable=bare-except disable=broad-except
arango_processes = [
    "arangod",
    "arangodb",
    "arangosync",
    "arangosh",
    "arangodbtests"
]

IS_WINDOWS = platform.win32_ver()[0] != ""
IS_MAC = platform.mac_ver()[0] != ""
IS_LINUX = not IS_WINDOWS and not IS_MAC

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
    myself = psutil.Process(os.getpid())
    try:
        while True:
            print(str(myself))
            myself = myself.parent()
            if myself.name().startswith("java"):
                print(f"Found my parent java: {str(myself)}")
                break
    except:
        print("no parent java process found")
        myself = None
    # print(os.environ)
    if 'SSH_AGENT_PID' in os.environ:
        pid = int(os.environ['SSH_AGENT_PID'])
        print("having agent PID: " + str(pid))
    for process in processes:
        try:
            name = process.name()
            # print(f"{name} - {process.username()} {process.pid}")
            for match_process in arango_processes:
                if name.startswith(match_process):
                    interresting_processes.append(process)
            if (name.startswith('ssh-agent') and
                (process.username() == 'jenkins') and
                int(process.pid) != pid):
                interresting_processes.append(process)
            if myself and name.startswith('java') and process.pid != myself.pid:
                print(f"found a java process which is not my parent, adding to list: {str(process)}")
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

def clean_docker_containers():
    """ hunt and kill stray docker containers """
    #pylint: disable=import-outside-toplevel
    import docker
    client = docker.from_env()
    kill_first = []
    kill_then = []
    for container in client.containers.list():
        workspace = ""
        for var in container.attrs['Config']['Env']:
            if var.startswith('WORKSPACE'):
                workspace = var
        started_at = ""
        if 'StartedAt' in container.attrs:
            started_at = container.attrs['StartedAt']
        labels = ""
        if 'Labels' in container.attrs['Config']:
            labels = container.attrs['Config']['Labels']

        print(f"{container.id} {container.attrs['Path']} {started_at} - {container.attrs['Created']} - {str(labels)} {workspace} ")
        if not container.attrs['Path'].startswith('/scripts/'):
            if container.attrs['Path'].startswith('/app/arangodb'):
                kill_first.append(container)
            elif container.attrs['Path'].startswith('sleep'):
                kill_first.append(container)
            else:
                kill_then.append(container)
    for container in (kill_first + kill_then):
        try:
            print(f"Stopping {container.id} {container.attrs['Path']}")
            container.stop()
            #container.kill()
        except Exception as ex:
            print(ex)
            print('next to come')

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
    if IS_LINUX:
        clean_docker_containers()
main()
