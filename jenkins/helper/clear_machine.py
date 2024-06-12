#!/usr/bin/python3
""" aimns to purge all resources that are stray and hinder ci work by blocking resources """
import collections
from datetime import datetime, timedelta
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
    remove_them = []
    now = datetime.now()
    print("Searching for volatile running docker containers")
    for container in client.containers.list(all=True):
        is_running = container.status not in ['exited', 'created']
        is_old = False
        workspace = ""
        if not container.attrs['Config']['Env'] is None:
            for var in container.attrs['Config']['Env']:
                if var.startswith('WORKSPACE'):
                    workspace = var
        else:
            print('no env')
        started_at = ""
        if 'StartedAt' in container.attrs:
            print('have started at')
            started_at = container.attrs['StartedAt']

        if 'Created' in container.attrs:
            created_at = datetime.strptime(container.attrs['Created'].split('.')[0], "%Y-%m-%dT%H:%M:%S")
            is_old = now - created_at > timedelta(days=14)
        labels = ""
        if 'Labels' in container.attrs['Config']:
            labels = container.attrs['Config']['Labels']

        print(f"{container.id} {container.attrs['Path']} {started_at} - {container.attrs['Created']} - {str(labels)} {workspace} {is_running} {is_old}")
        if not is_running and is_old:
            remove_them.append(container)
        if not container.attrs['Path'].startswith('/scripts/'):
            if container.attrs['Path'].startswith('/app/arangodb'):
                kill_first.append(container)
            elif container.attrs['Path'].startswith('sleep'):
                kill_first.append(container)
            else:
                kill_then.append(container)
    if len(kill_first) + len(kill_then) == 0:
        print("no containers to terminate found")
    else:
        for container in (kill_first + kill_then):
            try:
                print(f"Stopping {container.id} {container.attrs['Path']}")
                container.stop()
                container.kill()
            except Exception as ex:
                print(ex)
                print('next to come')
    if len(remove_them) == 0:
        print("No containers to remove")
    else:
        for container in remove_them:
            print(f'removing: {container.id} {container.remove()}')
    green_tags = [
        'centos',
        'ubuntu',
        'alpine',
        'debian',
        'minio',
        'arangodb/release-test-automation',
        'arangodb/ubuntubuildarangodb'
        ]
    stable_versions = []
    for k, v in os.environ.items():
        if k.find('IMAGE') > 0 and k.endswith('_NAME'):
            green_tags.append(v)
            bare_k = k[:-5]
            if bare_k in os.environ:
                stable_versions.append(os.environ[bare_k])
    print('pruning: ')
    print(client.images.prune())
    images_tags = {}
    delete_images = []
    for image in client.images.list():
        if len(image.tags) == 0:
            print(f'will delete tagless {image.id}')
            delete_images.append(image)
            continue
        datestr = image.attrs['Metadata']['LastTagTime']
        is_old = True
        legacy_timestamp = True
        if datestr.find('T'):
            # chop off sh* we don't want to parse:
            created_at = datetime.strptime(datestr.split('.')[0].split('Z')[0], "%Y-%m-%dT%H:%M:%S")
            is_old = now - created_at > timedelta(days=64)
            legacy_timestamp = False
        if legacy_timestamp:
            print('legacy timestamp - deleting: ')
            delete_images.append(image)
            continue
        is_latest = False
        green_tag_found = False
        for tag in image.tags:
            for stable in stable_versions:
                if tag.startswith(stable):
                    print(f"{tag} is a stable oskar one - skipping")
                    break
            for gtag in green_tags:
                if tag.find(gtag) == 0:
                    green_tag_found = True
                    print(f'tag found: {gtag} in {tag}')
                    if tag.find('latest') > 0:
                        is_latest = True
                    else:
                        struct = {
                            'tag': tag,
                            'image_object': image
                            }
                        if gtag not in images_tags:
                            images_tags[gtag] = struct
                        else:
                            if images_tags[gtag]['tag'] > tag:
                                delete_images.append(image)
                            else:
                                delete_images.append(images_tags[gtag]['image_object'])
                                images_tags[gtag] = struct
        if not green_tag_found:
            delete_images.append(image)
    if len(delete_images) == 0:
        print('no images to delete found!')
    else:
        for image in delete_images:
            try:
                print(f'deleting {image} {client.images.remove(image=image.id)}')
            except:
                pass
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
    #if IS_LINUX:
    #    clean_docker_containers()
main()
