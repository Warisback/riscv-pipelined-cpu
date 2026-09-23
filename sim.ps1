<#
  Build + run + view one Icarus Verilog testbench.

    .\sim.ps1 immgen_tb           compile & run
    .\sim.ps1 immgen_tb -Wave     compile, run, then open GTKWave
    .\sim.ps1 immgen_tb -Lint     syntax check only, produces no output file

  -Tb accepts a bare module name, a relative path, or a full path:
    immgen_tb  |  tb/immgen_tb.sv  |  C:\...\tb\immgen_tb.sv
#>
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Tb,
  [switch]$Wave,
  [switch]$Lint
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Push-Location $root

try {
  # ---------------------------------------------------------------- find the tb
  $candidates = @(
    $Tb,
    "$Tb.sv",
    "tb/$Tb",
    "tb/$Tb.sv",
    "$Tb.v",
    "tb/$Tb.v"
  )
  $tbFile = $null
  foreach ($c in $candidates) {
    if (Test-Path -PathType Leaf $c) { $tbFile = (Resolve-Path $c).Path; break }
  }
  if (-not $tbFile) {
    Write-Host "sim.ps1: no testbench found for '$Tb'" -ForegroundColor Red
    Write-Host "  looked for: $($candidates -join ', ')"
    exit 1
  }

  $name = [IO.Path]::GetFileNameWithoutExtension($tbFile)
  New-Item -ItemType Directory -Force -Path build | Out-Null

  # SystemVerilog packages are NOT auto-resolved by -y (that only works for
  # module names), so any *_pkg.sv has to be named on the command line, first.
  $pkgs = @(Get-ChildItem -Recurse -File -Include '*_pkg.sv', '*_pkg.v' |
            Where-Object { $_.FullName -notlike "*\build\*" } |
            ForEach-Object { $_.FullName })

  # -g2012  SystemVerilog-2012 subset
  # -y      dirs to auto-search for an undefined module (file must be <module>.sv)
  # -Y      extension -y should look for (default is .v, so .sv needs saying)
  # -I      include search path for `include
  $common = @(
    '-g2012', '-Wall',
    '-y', '.', '-y', 'rtl', '-y', 'tb',
    '-Y', '.sv',
    '-I', '.', '-I', 'rtl'
  )

  # ------------------------------------------------------------------- compile
  if ($Lint) {
    Write-Host "lint  $name" -ForegroundColor Cyan
    & iverilog @common '-t' 'null' @pkgs $tbFile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "ok" -ForegroundColor Green
    exit 0
  }

  $vvp = "build/$name.vvp"
  Write-Host "build $name" -ForegroundColor Cyan
  & iverilog @common '-o' $vvp @pkgs $tbFile
  if ($LASTEXITCODE -ne 0) {
    Write-Host "compile failed" -ForegroundColor Red
    exit $LASTEXITCODE
  }

  # ----------------------------------------------------------------------- run
  Write-Host "run   $name" -ForegroundColor Cyan
  & vvp $vvp
  $simExit = $LASTEXITCODE
  if ($simExit -ne 0) {
    Write-Host "simulation exited $simExit" -ForegroundColor Red
  }

  # --------------------------------------------------------------------- waves
  if ($Wave) {
    # matches whatever the tb passed to $dumpfile
    $vcd = Get-ChildItem -File -Path "build/$name.vcd", "$name.vcd", "build/dump.vcd", "dump.vcd" `
             -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $vcd) {
      Write-Host "no VCD found - does the tb call `$dumpfile/`$dumpvars?" -ForegroundColor Yellow
    }
    else {
      # A .gtkw save file remembers which signals you had open, and their order,
      # radix and grouping. Commit these - they save a lot of re-clicking.
      $gtkw = "waves/$name.gtkw"
      $args = if (Test-Path $gtkw) { @($vcd.FullName, (Resolve-Path $gtkw).Path) }
              else { @($vcd.FullName) }
      Write-Host "wave  $($vcd.Name)" -ForegroundColor Cyan
      Start-Process -FilePath 'gtkwave' -ArgumentList $args
    }
  }

  exit $simExit
}
finally {
  Pop-Location
}
