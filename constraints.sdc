# ==============================================================================
# File:        constraints.sdc
# Description: Synopsys Design Constraints (SDC) file for the 16-bit Barrel Shifter.
#              This drives timing-driven synthesis and Place-and-Route (PnR).
#              Target clock frequency: 400 MHz (2.5ns period)
# ==============================================================================

# Set operating units (Modify based on your PDK library spec, e.g., ns/pF/kOhm)
set_units -time ns -resistance kOhm -capacitance pF -voltage V -current mA

# 1. Define Clock Target (400 MHz clock target to match config.json)
create_clock -name virtual_clk -period 2.5 [get_ports clk]

# 2. Clock Uncertainties & Jitter
# Account for setup clock skew, jitter, and guardband margin
set_clock_uncertainty -setup 0.150 [get_clocks virtual_clk]
set_clock_uncertainty -hold  0.100 [get_clocks virtual_clk]

# Clock transition times (slew rate limiters)
set_clock_transition 0.100 [get_clocks virtual_clk]

# 3. Input Delays (Assuming 30% of clock period is spent in the sending block)
# 30% of 2.5ns is 0.75ns
set_input_delay -clock virtual_clk -max 0.750 [get_ports {din[*]}]
set_input_delay -clock virtual_clk -max 0.750 [get_ports {shift_amt[*]}]
set_input_delay -clock virtual_clk -max 0.750 [get_ports {mode[*]}]
set_input_delay -clock virtual_clk -max 0.750 [get_ports rst_n]

# Min input delays to guarantee hold-time integrity at inputs
set_input_delay -clock virtual_clk -min 0.100 [get_ports {din[*]}]
set_input_delay -clock virtual_clk -min 0.100 [get_ports {shift_amt[*]}]
set_input_delay -clock virtual_clk -min 0.100 [get_ports {mode[*]}]
set_input_delay -clock virtual_clk -min 0.100 [get_ports rst_n]

# 4. Output Delays (Assuming 30% of clock period is reserved for the receiving block)
set_output_delay -clock virtual_clk -max 0.750 [get_ports {dout[*]}]
set_output_delay -clock virtual_clk -min 0.100 [get_ports {dout[*]}]

# 5. Environment Rules (Change names to match standard cells from your target PDK/tech-node)
# For Sky130, sky130_fd_sc_hd__buf_4 is a robust buffer to drive inputs
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [remove_from_collection [all_inputs] [get_ports clk]]

# Output load constraint: assume output pin drives equivalent of 4 small load gates
set_load 0.034 [all_outputs]

# 6. Max Fanout Limits to avoid physical electromigration and slew degradation
set_max_fanout 16 [current_design]
set_max_transition 0.150 [current_design]
