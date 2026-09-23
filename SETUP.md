# Simulation setup — Icarus Verilog + GTKWave + VS Code

Notes on how this project is wired for simulation, so it's re-derivable if the
environment ever needs rebuilding.

## Installed toolchain

Both live under `C:\iverilog` and are already on `PATH`:

| Tool | Version | Path |
|---|---|---|
| Icarus Verilog (`iverilog`, `vvp`) | 12.0 | `C:\iverilog\bin` |
| GTKWave | bundled | `C:\iverilog\gtkwave\bin` |

VS Code extension: **`mshr-h.veriloghdl`** (Verilog-HDL/SystemVerilog).

Check it's all still healthy with:

```powershell
iverilog -V
gtkwave --version
```

If `iverilog` isn't found, add `C:\iverilog\bin` and `C:\iverilog\gtkwave\bin` to
the user `PATH` environment variable and restart VS Code.

## Project files

| File | Purpose |
|---|---|
| `sim.ps1` | compile → run → open waves, one command |
| `.vscode/tasks.json` | `Ctrl+Shift+B` sims the open file; errors become clickable |
| `.vscode/settings.json` | lint-as-you-type via iverilog, `.sv` → SystemVerilog |
| `.gitignore` | ignores `build/`, `*.vcd`, `*.vvp` |

## Running a simulation

```powershell
.\sim.ps1 immgen_tb          # compile + run
.\sim.ps1 immgen_tb -Wave    # + open GTKWave
.\sim.ps1 immgen_tb -Lint    # syntax check only, no output file
```

`-Tb` accepts a bare module name, a relative path, or a full path — `immgen_tb`,
`tb/immgen_tb.sv`, and `C:\...\tb\immgen_tb.sv` all work.

Or from inside VS Code:

- **`Ctrl+Shift+B`** — sim whatever testbench file is currently open
- **`Ctrl+Shift+P` → Tasks: Run Task** — for the `-Wave`, `-Lint`, and
  "pick testbench" variants

Compile errors land in the Problems panel and are clickable through to the line.

## Layout and the two `-y` gotchas

Expected layout is `rtl/` for design files and `tb/` for testbenches, but the
compile line passes `-y . -y rtl -y tb`, so a flat root also works.

`-y` is what makes this low-maintenance: it auto-resolves any undefined module by
searching those directories, so **new files never need adding to a build list**.
Two constraints come with it:

1. **Filename must equal module name** — `immgen.sv` must contain `module immgen`.
   This is what lets a testbench instantiate a module without naming its file.
2. **Packages are not found by `-y`** — it only resolves *module* names. `sim.ps1`
   globs `*_pkg.sv` and places those first on the command line, so any package
   file needs that suffix to get picked up.

The full flag set, for reference:

```
-g2012          SystemVerilog-2012 subset
-Wall           all warnings
-y . -y rtl -y tb   dirs to auto-search for undefined modules
-Y .sv          extension -y should look for (default is .v, so .sv needs saying)
-I . -I rtl     include search path for `include
```

## Writing a testbench

A testbench is a module with **no ports** that instantiates the DUT, drives its
inputs, and checks its outputs. Four parts:

### 1. Dump waves

Nothing shows up in GTKWave without this:

```systemverilog
initial begin
  $dumpfile("build/foo_tb.vcd");  // path must match what sim.ps1 looks for
  $dumpvars(0, foo_tb);           // 0 = all signals, recursively, from here down
end
```

### 2. Stimulus

- **Combinational** DUTs (immgen, ALU, mux): set inputs, `#1` to let them settle,
  then check. No clock needed.
- **Clocked** DUTs (pipeline registers, regfile): generate a clock with
  `always #5 clk = ~clk;`, drive inputs on the **negedge**, sample on the
  **posedge**. Staying off the edge the DUT samples on is what stops the
  testbench racing it.

### 3. Self-check, don't eyeball

Write a `task` that takes the inputs plus the expected value, applies them,
compares, and bumps an error counter. Use `!==` rather than `!=` so `x` and `z`
count as failures. Print a `PASS`/`FAIL` summary at the end, then `$finish`.

Once this exists, regressions stop needing waveform inspection — GTKWave becomes
the tool you open only when something has already failed.

### 4. Timeout

```systemverilog
initial begin
  #100000;
  $display("TIMEOUT");
  $finish;
end
```

Without it, a bad handshake hangs the simulation forever instead of failing.

### Two things that bite

- Put `` `timescale 1ns/1ps `` at the top of **every** file. The `-Wall` warning
  about "no explicit time unit" is this.
- Every testbench needs `$finish` somewhere reachable, or `vvp` never exits.

## Waveform workflow

1. Run with `-Wave` to launch GTKWave on the VCD.
2. Drag the signals you care about into the wave pane.
3. **File → Write Save File** → save as `waves/<tb_name>.gtkw`.

`sim.ps1` auto-loads that `.gtkw` on subsequent runs, so signal selection,
ordering, grouping, and radix all survive. These files are worth committing —
`.gitignore` keeps them while dropping the regenerable VCDs.

After re-running a sim, **don't relaunch GTKWave** — press **`Ctrl+Shift+R`** to
reload the VCD in place and keep your view.

For the pipeline CPU, the save file worth building early: `clk`, `pc`, each
stage's instruction register, and the stall/flush signals grouped together. That
one view answers whether a hazard was actually handled.
