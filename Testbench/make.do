# arinc_tx_tb.do - ModelSim do file for ARINC 429 transmitter testbench

# Clear previous simulation data
vlib work
vmap work work

# Compile the VHDL files
vcom -93 module_fifo_regs_no_flags.vhd
vcom -93 a429_tx.vhd
vcom -93 arinc_tx_tb.vhd

# Load the testbench
vsim work.arinc_tx_tb

# Load the saved waveform commands from wave.do
do wave.do



# Run the simulation
run 2 ms

# Optional: Save the waveform
# wave save -o arinc_tx_tb.wlf

