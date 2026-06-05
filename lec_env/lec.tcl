set_log_file lec.log -replace
read_library fast.lib -lib -revised
read_design pade_lut.v fp32_add.v fp32_mul.v fp32_div.v fp32_log2.v fp32_exp2.v fp32_sqrt.v fp32_cbrt.v fp32_cos.v fp32_acos.v cubic_solver.v -verilog -golden
read_design cubic_solver_m.v -verilog -revised
set_mapping_method -name only
set_system_mode lec
map_key_points
add_compared_points -all
# compare