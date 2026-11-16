#!/bin/bash
# Live-demo script for the video:  bash scripts/demo.sh [vadd|saxpy|threshold]
# Assembles a program, runs the lane-ALU unit test, runs the program on 1, 4 and 8 lanes,
# prints a sample of results (DUT vs expected) and the cycle count / speed-up table.
cd "$(dirname "$0")/.."
mkdir -p build
WL=${1:-vadd}
case $WL in vadd) IDX=0;; saxpy) IDX=1;; threshold) IDX=2;; *) echo "unknown workload"; exit 1;; esac

echo; echo "=== 1. Assemble asm/$WL.asm into machine code ==="
python3 asm/assembler.py asm/$WL.asm asm/hex/$WL.hex
cat asm/hex/$WL.lst

echo; echo "=== 2. Unit test of one SIMD lane (19 corner cases) ==="
iverilog -g2012 -o build/tb_lane tb/tb_lane_alu.v rtl/simd_lane_alu.v && vvp build/tb_lane | grep LANE_ALU_TEST

echo; echo "=== 3. Run $WL on the 4-lane VPU (first 8 results, DUT vs expected) ==="
iverilog -g2012 -P tb_vpu_top.LANES=4 -o build/tb_4 tb/tb_vpu_top.v rtl/*.v
vvp build/tb_4 +WL=$IDX +HEX=asm/hex/$WL.hex +VERBOSE | grep -v -E "WARNING|finish"

echo; echo "=== 4. Scalar (1 lane) vs SIMD (4 and 8 lanes) ==="
printf "%-8s %-8s %-8s %-8s\n" LANES CYCLES ERRORS SPEEDUP
base=0
for L in 1 4 8; do
  iverilog -g2012 -P tb_vpu_top.LANES=$L -o build/tb_$L tb/tb_vpu_top.v rtl/*.v
  line=$(vvp build/tb_$L +WL=$IDX +HEX=asm/hex/$WL.hex | grep RESULT)
  cyc=$(echo $line | cut -d, -f4); err=$(echo $line | cut -d, -f6)
  [ $L -eq 1 ] && base=$cyc
  printf "%-8s %-8s %-8s %.2fx\n" $L $cyc $err $(echo "$base $cyc" | awk '{print $1/$2}')
done
echo; echo "Done. Waveform: bash scripts/make_waveform.sh  then  gtkwave build/vadd_L4.vcd"
