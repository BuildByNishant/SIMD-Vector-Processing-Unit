#!/bin/bash
# Build + run every workload for LANES = 1,2,4,8,16. Output: results/results.csv
set -e
cd "$(dirname "$0")/.."
mkdir -p build results
: > results/sim.log
for p in vadd saxpy threshold opcover; do python3 asm/assembler.py asm/$p.asm asm/hex/$p.hex >/dev/null; done

echo "== Lane ALU unit test =="
iverilog -g2012 -o build/tb_lane tb/tb_lane_alu.v rtl/simd_lane_alu.v && vvp build/tb_lane | tee results/lane_alu_test.log

echo "workload,lanes,cycles,instrs,errors" > results/results.csv
WLS=(vadd saxpy threshold opcover)
for L in 1 2 4 8 16; do
  iverilog -g2012 -P tb_vpu_top.LANES=$L -o build/tb_$L tb/tb_vpu_top.v rtl/*.v
  for w in 0 1 2 3; do
    vvp build/tb_$L +WL=$w +HEX=asm/hex/${WLS[$w]}.hex | grep -E "RESULT|MISMATCH|TIMEOUT" | tee -a results/sim.log \
      | grep RESULT | sed 's/RESULT,//' >> results/results.csv
  done
done
cat results/results.csv

# ---- pass/fail gate (used by CI): any non-zero error column or failed unit test -> exit 1
if awk -F, 'NR>1 && $5!=0 {bad=1} END{exit bad}' results/results.csv && grep -q "PASS" results/lane_alu_test.log; then
  echo "ALL TESTS PASSED"
else
  echo "TESTS FAILED"; exit 1
fi
