# 32-bit pipelined RISC-V CPU

A five-stage pipelined RV32I core in SystemVerilog, built from scratch and verified
module by module with self-checking testbenches. In progress: the datapath modules are
being built and verified individually first, then integrated into a single-cycle core,
then pipelined.

## Planned architecture

Classic five-stage pipeline:

```
IF  →  ID  →  EX  →  MEM  →  WB
```

- **IF**: program counter, instruction memory, +4 / branch-target select
- **ID**: register file read, immediate generation, control decode
- **EX**: ALU, branch resolution, forwarding muxes
- **MEM**: data memory read/write
- **WB**: write-back select into the register file

Hazard handling is the point of the exercise:

- data forwarding from EX/MEM and MEM/WB into EX
- load-use hazard detection with a one-cycle stall
- pipeline flush on taken branches

## Status

- [x] Simulation toolchain: Icarus Verilog + GTKWave, one-command builds (`sim.ps1`),
      lint-as-you-type in VS Code (see [SETUP.md](SETUP.md))
- [ ] Immediate generator (`immgen.sv`), in progress
- [ ] Register file (`regfile.sv`)
- [ ] ALU and ALU control
- [ ] Control unit
- [ ] Single-cycle integration and bring-up
- [ ] Pipeline registers and hazard unit
- [ ] Per-instruction self-checking testbenches across RV32I

## Running a simulation

```powershell
.\sim.ps1 <testbench>          # compile + run
.\sim.ps1 <testbench> -Wave    # compile, run, open waves in GTKWave
.\sim.ps1 <testbench> -Lint    # syntax check only
```

## Why

Successor to my single-cycle core: same ISA, but built for the questions that matter in
real microarchitecture, namely who needs a value before it is written back, and what has
to happen on a mispredicted branch. Verified in simulation with waveform inspection and
testbenches that check results, not just run to completion.
