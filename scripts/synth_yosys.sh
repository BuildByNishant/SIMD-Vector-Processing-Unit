#!/bin/bash
# Preliminary resource estimate with Yosys (Xilinx 7-series mapping) of the datapath blocks:
#   one SIMD lane ALU, and the vector register file for LANES = 1,2,4,8.
# Behavioural memories are excluded (they map to BRAM in Vivado - Phase II).
cd "$(dirname "$0")/.."
mkdir -p synth
yosys -q -p "read_verilog -sv rtl/simd_lane_alu.v; hierarchy -top simd_lane_alu; synth_xilinx -family xc7 -top simd_lane_alu; tee -o synth/stat_alu.txt stat" > synth/yosys_alu.log 2>&1
yosys -q -p "read_verilog -sv rtl/vpu_control.v; hierarchy -top vpu_control; synth_xilinx -family xc7 -top vpu_control; tee -o synth/stat_ctrl.txt stat" > synth/yosys_ctrl.log 2>&1
for L in 1 2 4 8; do
  yosys -q -p "read_verilog -sv rtl/vector_regfile.v; chparam -set LANES $L vector_regfile; hierarchy -top vector_regfile; synth_xilinx -family xc7 -top vector_regfile; tee -o synth/stat_vrf_L$L.txt stat" > synth/yosys_vrf_L$L.log 2>&1
done
for f in alu ctrl vrf_L1 vrf_L2 vrf_L4 vrf_L8; do echo "== $f"; grep -E "LUT[0-9]|FD[CRPS]E|DSP48|RAM|CARRY4|MUXF|Number of cells" synth/stat_$f.txt; done
