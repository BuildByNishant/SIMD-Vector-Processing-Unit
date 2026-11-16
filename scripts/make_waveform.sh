#!/bin/bash
# Dump a VCD for the 4-lane vadd run and regenerate the figures. View with: gtkwave build/vadd_L4.vcd
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
iverilog -g2012 -P tb_vpu_top.LANES=4 -o build/tb_wave tb/tb_vpu_top.v rtl/*.v
vvp build/tb_wave +WL=0 +HEX=asm/hex/vadd.hex +VCD=build/vadd_L4.vcd | grep RESULT
python3 scripts/make_figures.py
