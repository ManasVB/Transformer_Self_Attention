# Scaled Dot-Product Attention for LLM Transformer Models using SystemVerilog
This document contains the instructions and commands to setup the directory.

### Setup script

```/setup.sh``` is provided to load Modelsim and Synopsys

To source the script:
```bash
source setup.sh
```
This script also enables you to <kbd>Tab</kbd> complete ```make``` commands

### Where to put your design

A Verilog file ```/rtl/dut.sv``` is provided with all the ports already connected to the test fixture

### How to compile your design

To compile your design

Change directory to ```/run/``` 

```bash
make build-dw
make build
```

All the .sv files in ```/rtl/``` will be compiled with this command.

### How to run your design

Run with Modelsim UI 564:
```bash
make debug
```

### Evaluation Testing
To evaluate you design headless/no-gui, change directory to ```/run/```
```
make eval
```
This will produce a set of log files that will highlight the results of your design. This should only be ran as a final step before Synthesis

All log files is in the following directory ```/run/logs```

All test resutls is in the results log file ```/run/logs/RESULTS.log```

All simulation resutls is in the following log file ```/run/logs/output.log```

All simulation info is in the following log file ```/run/logs/INFO.log```

## Synthesis

Once you have a functional design, you can synthesize it in ```/synthesis/```

### Synthesis Command
The following command will synthesize your design with a default clock period of 10 ns
```bash
make all
```
### Clock Period

To run synthesis with a different clock period
```bash
make all CLOCK_PER=<YOUR_CLOCK_PERIOD>
```
For example, the following command will set the target clock period to 4 ns.

```bash
make all CLOCK_PER=10
```

## Appendix

### Directory Rundown

You will find the following directories in ```/```

* ```inputs/``` 
  * Contains the .dat files for the input SRAMs used in HW 
* ```HW_specification/```
  * Contains the HW specification document
* ```rtl/```
  * All .v files will be compiled when executing ```make vlog-v``` in ```/run/```
  * A template ```dut.v``` that interfaces with the test fixture is provided
* ```run/```
  * Contains the ```Makefile``` to compile and simulate the design
* ```scripts/```
  * Contains the python script that generates a random input/output
* ```synthesis/```
  * The directory you will use to synthesize your design
  * Synthesis reports will be exported to ```synthesis/reports/```
  * Synthesized netlist will be generated to ```synthesis/gl/```
* ```testbench/```
  * Contains the test fixture of the HW


