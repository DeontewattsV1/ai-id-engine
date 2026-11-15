floorplan / timing intent
# SPDX-License-Identifier: MIT
# Artix-7 / Kintex-7 class. Identity Engine in its own clock region.
create_clock -name pclk -period 4.000 [get_ports pclk]
create_clock -name puf_clk -period 10.000 [get_ports puf_clk]
set_clock_groups -asynchronous -group [get_clocks pclk] -group [get_clocks puf_clk]

set_property PACKAGE_PIN E3  [get_ports pclk]
set_property IOSTANDARD LVCMOS33 [get_ports pclk]

# PUF + UDS domain: keep tight, no routing through I/O banks
create_pblock pb_secure
add_cells_to_pblock pb_secure [get_cells u_puf]
resize_pblock pb_secure -add {SLICE_X0Y0:SLICE_X19Y199}

# Tamper mesh: dedicated I/O, no shared bank with untrusted peripherals
set_property IOSTANDARD LVCMOS18 [get_ports {tamper_sensors[*]}]

# False paths: OTP read is slow, fuses settle asynchronously
set_false_path -from [get_ports {otp_rd[*]}]

# Max skew on PCR fanout (16 x 256 flops)
set_max_skew -from [get_cells u_pcr/pcr_reg*] -skew 0.150
