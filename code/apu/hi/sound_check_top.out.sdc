## Generated SDC file "sound_check_top.out.sdc"

## Copyright (C) 2024  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details, at
## https://fpgasoftware.intel.com/eula.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 23.1std.1 Build 993 05/14/2024 SC Standard Edition"

## DATE    "Fri Mar 14 17:54:32 2025"

##
## DEVICE  "EP4CE115F29C7"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLOCK_50} -period 50.000 -waveform { 0.000 25.000 } [get_ports { CLOCK_50 }]
create_clock -name {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE} -period 50.000 -waveform { 0.000 25.000 } [get_registers { wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE }]


#**************************************************************
# Create Generated Clock
#**************************************************************



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}] -rise_to [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}] -fall_to [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}] -rise_to [get_clocks {CLOCK_50}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}] -fall_to [get_clocks {CLOCK_50}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}] -rise_to [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}] -fall_to [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}] -rise_to [get_clocks {CLOCK_50}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}] -fall_to [get_clocks {CLOCK_50}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}]  0.030  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}]  0.020  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {wm8731_configurator:u_config|i2c_master:u_i2c|state.I2C_COMPLETE}]  0.030  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}]  0.020  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}]  0.020  


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

