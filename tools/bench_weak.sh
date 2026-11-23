#!/bin/bash
# Weak-hardware stand-in: runs the real-window bench on a software Vulkan rasteriser (Mesa lavapipe) under Xvfb.
# The numbers are CPU raster time, not an integrated GPU: use them to compare builds and quality levels against
# each other (A/B), never as an absolute fps. Needs: godot, mesa-vulkan-drivers, xvfb.
#   tools/bench_weak.sh out.json [WxH] [bench args...]      e.g.  tools/bench_weak.sh low.json 1280x720 --quality=low --frames=90
set -e
out=${1:-shots/bench_weak.json}; res=${2:-1280x720}; shift 2 || true
GODOT=${GODOT:-godot}
export VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.x86_64.json}
export HOME=${HOME_OVERRIDE:-/tmp/plinky_weak_home}; mkdir -p "$HOME"   # isolated user folder: never touches a real save
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver vulkan --resolution "$res" --script tools/bench.gd -- "$@"
cp shots/bench.json "$out"
python3 tools/check_frame_budget.py "$out" 150 300
