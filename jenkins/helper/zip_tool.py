#!/bin/env python3
""" the testing runner actually manages launching the processes, creating reports, etc. """
from multiprocessing import Process
import shutil
import zipfile
import sys
import psutil

ZIPFORMAT="gztar"
ZIPEXT="tar.gz"
try:
    import py7zr
    shutil.register_archive_format('7zip', py7zr.pack_7zarchive, description='7zip archive')
    ZIPFORMAT="7zip"
    ZIPEXT="7z"
except ModuleNotFoundError:
    pass

def zipp_this(filenames, target_dir):
    """ worker function to zip one file a time in a subprocess """
    # pylint: disable=consider-using-with disable=broad-exception-caught
    for corefile in filenames:
        try:
            print(f'zipping {corefile}')
            zipfile.ZipFile(str(target_dir / (corefile.name + '.xz')),
                            mode='w', compression=zipfile.ZIP_LZMA).write(str(corefile))
        except Exception as exc:
            print(f'skipping {corefile} since {exc}')
        try:
            corefile.unlink(missing_ok=True)
        except Exception as ex:
            print(f"failed to delete {corefile} because of {ex}")

# pylint: disable=too-many-arguments
def mt_zip_tar(fnlist, zip_dir, tarfile, verb, filetype):
    """ use full machine to compress files in zip-tar """
    zip_slots = psutil.cpu_count(logical=False)
    count = 0
    zip_slot_array = []
    for _ in range(zip_slots):
        zip_slot_array.append([])
    for one_file in fnlist:
        if one_file.exists():
            zip_slot_array[count % zip_slots].append(one_file)
            count += 1
    zippers = []
    print(f"{verb} launching zipper sub processes {zip_slot_array}")
    for zip_slot in zip_slot_array:
        if len(zip_slot) > 0:
            proc = Process(target=zipp_this, args=(zip_slot, zip_dir))
            proc.start()
            zippers.append(proc)
    for zipper in zippers:
        zipper.join()
    print("compressing files done")

    for one_file in fnlist:
        if one_file.is_file():
            one_file.unlink(missing_ok=True)

    print(f"creating {filetype}: {str(tarfile)} with {str(fnlist)}.tar")
    sys.stdout.flush()
    shutil.make_archive(str(tarfile),
                        'tar',
                        (zip_dir / '..').resolve(),
                        zip_dir.name,
                        True)
