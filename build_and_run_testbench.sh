#!/bin/bash
# 
# build_and_run_testbench.sh - Compile and simulate loader_sd_card with Icarus Verilog
#
# Usage: ./build_and_run_testbench.sh

set -e

VERILOG_DIR="src"
TESTBENCH_DIR="tb"
OUTPUT_DIR="sim/work"
VCD_FILE="${OUTPUT_DIR}/loader_sd_card_tb.vcd"

echo "========================================"
echo "Loader SD Card Upload_req Testbench"
echo "========================================"

# Create output directory
mkdir -p ${OUTPUT_DIR}

echo ""
echo "[1/3] Compiling with Icarus Verilog..."
echo "------"

# Compile the module and testbench
iverilog -g2009 \
    -DVERILATOR \
    -o ${OUTPUT_DIR}/loader_sd_card_tb \
    ${VERILOG_DIR}/loader_sd_card.sv \
    ${TESTBENCH_DIR}/loader_sd_card_tb.sv

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed"
    exit 1
fi

echo "Compilation successful: ${OUTPUT_DIR}/loader_sd_card_tb"

echo ""
echo "[2/3] Running simulation..."
echo "------"

# Run the simulation and generate VCD
cd ${OUTPUT_DIR}
vvp loader_sd_card_tb

if [ $? -ne 0 ]; then
    echo "ERROR: Simulation failed"
    exit 1
fi

cd - > /dev/null

echo "Simulation complete: ${VCD_FILE}"

echo ""
echo "[3/3] View waveform with GTKWave..."
echo "------"
echo "Run: gtkwave ${VCD_FILE}"
echo ""
echo "Signal traces:"
echo "  - ioctl_upload_req     : Upload request from host"
echo "  - upload_req           : Internal flag (latched edge)"
echo "  - old_upload_req       : Previous cycle value (for edge detection)"
echo "  - ioctl_upload         : Active upload transaction"
echo "  - loader_busy          : Module busy indicator"
echo "  - io_state             : State machine state"
echo "  - addr                 : Current address in sector"
echo "  - cnt                  : Byte counter (0-511)"
echo "  - ioctl_wr             : Write strobe"
echo "  - ioctl_addr           : I/O control address"
echo "  - sd_wr                : SD write request"
echo "  - sd_busy              : SD busy acknowledgement"
echo "  - sd_done              : SD operation complete"
echo ""
echo "========================================"
echo "Testbench run complete!"
echo "========================================"
