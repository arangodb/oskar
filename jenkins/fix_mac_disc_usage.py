#!/usr/bin/env python3

from pathlib import Path
import subprocess

spoolFile = Path('/System/Library/Caches/com.apple.coresymbolicationd/data')

if spoolFile.stat().st_size > 5 * 1024 * 1024:
    # ok, we will have to deal with this!
    spoolFile.unlink()
    subprocess.call(['osascript', '-e', 'tell app "System Events" to shut down'])
