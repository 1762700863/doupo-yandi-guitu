#!/bin/bash
# usage: shot.sh name args...
name=$1; shift
cd /var/tmp/w/repo
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" /var/tmp/w/godot --path . --resolution 960x540 -- shot=/var/tmp/w/shots/$name.png "$@" 2>&1 | grep -E "SCRIPT ERROR|at: |ERROR|ROOM_RESULT|FIRE|ALC" | grep -v "resources still in use\|ObjectDB\|core/object\|core/io/resource" | head -30
