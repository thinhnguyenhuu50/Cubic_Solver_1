
#!/bin/bash -f

# Link the RTL, Netlist and Library file from "synthesis_env"
# Note: Ensure the paths are correct relative to the lec_env directory
RTL_FILES="pade_lut.v fp32_add.v fp32_mul.v fp32_div.v fp32_log2.v fp32_exp2.v fp32_sqrt.v fp32_cbrt.v fp32_cos.v fp32_acos.v cubic_solver.v"
for f in $RTL_FILES; do
  ln -sf ../synthesis_env_1/Genus_BoundFlasher/RTL/$f .
done
ln -sf ../synthesis_env_1/Genus_BoundFlasher/LAB1/outputs_Jun05-11:51:42/cubic_solver_m.v .
ln -sf ../synthesis_env_1/Genus_BoundFlasher/LIB/fast.lib .
echo "Symbolic links created. Listing files:"

ls -l
