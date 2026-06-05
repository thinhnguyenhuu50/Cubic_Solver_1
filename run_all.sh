#!/bin/bash

# Loop from 1 to 15
for i in {1..15}
do
    TB="tb_$i"
    
    echo "========================================"
    echo "Compiling and Running: $TB"
    echo "========================================"
    
    # Compile the Verilog files with the current testbench as the top module
    iverilog -g2012 -s $TB -o sim.vvp *.v
    
    # Check if the compilation was successful ($? gets the exit code of the last command)
    if [ $? -eq 0 ]; then
        # Run the simulation
        vvp sim.vvp
    else
        echo "Error: Compilation failed for $TB. Skipping simulation."
    fi
    
    echo "" # Add a blank line for readability between runs
done

echo "========================================"
echo "All testbenches completed!"
echo "========================================"