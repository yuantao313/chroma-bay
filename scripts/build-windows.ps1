# RP2040 cross-build script (Windows native, no MSVC required)
# Usage: powershell -File scripts/build-windows.ps1
# Note: keep comments ASCII-only; PowerShell 5 mis-parses UTF-8 without BOM.
$ErrorActionPreference = "Stop"

# winget portable CMake/Ninja and scoop Git are not on the system PATH; inject them here
# when present. Any missing entry simply drops out of the PATH.
$WingetPkgs = "$env:USERPROFILE\AppData\Local\Microsoft\WinGet\Packages"
$extraPath = @(
    (Get-ChildItem "$WingetPkgs\Kitware.CMake_*" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem "$($_.FullName)\cmake-*-windows-x86_64\bin" -Directory -ErrorAction SilentlyContinue } |
        Select-Object -First 1 -ExpandProperty FullName),
    (Get-ChildItem "$WingetPkgs\Ninja-build.Ninja_*" -Directory -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName),
    "$env:USERPROFILE\scoop\apps\git\current\cmd",
    [Environment]::GetEnvironmentVariable("Path", "Machine"),
    [Environment]::GetEnvironmentVariable("Path", "User")
) | Where-Object { $_ -and (Test-Path $_) }
$env:Path = ($extraPath + $env:Path) -join ";"

# Dependency locations: environment variable wins, otherwise fall back to the
# conventional per-user layout documented in docs/dependencies.md.
function Resolve-Dep([string]$Name, [string]$Default) {
    $fromEnv = [Environment]::GetEnvironmentVariable($Name)
    if ($fromEnv) { return $fromEnv }
    return $Default
}

$env:PICO_SDK_PATH = Resolve-Dep "PICO_SDK_PATH" "$env:USERPROFILE\pico\pico-sdk"
$PicotoolDir      = Resolve-Dep "PICOTOOL_DIR"  "$env:USERPROFILE\pico\picotool\picotool"
$PioasmDir        = Resolve-Dep "PIOASM_DIR"    "$env:USERPROFILE\pico\pico-sdk-tools\pioasm"

foreach ($dep in @(
        @{ Name = "pico-sdk"; Path = $env:PICO_SDK_PATH },
        @{ Name = "picotool"; Path = $PicotoolDir },
        @{ Name = "pioasm";   Path = $PioasmDir })) {
    if (-not (Test-Path $dep.Path)) {
        Write-Error "$($dep.Name) not found at '$($dep.Path)'. See docs/dependencies.md."
        exit 1
    }
}
if (-not (Get-Command arm-none-eabi-gcc -ErrorAction SilentlyContinue)) {
    Write-Warning "arm-none-eabi-gcc not found on PATH; CMake will fail unless it is installed."
}

# Prebuilt host tools: without them the SDK would compile picotool/pioasm on the host
# and demand a host C++ compiler. Point CMake at the official prebuilt packages instead.
cmake -S src -B build -G Ninja `
    -DPICO_BOARD=pico `
    -DCMAKE_BUILD_TYPE=Release `
    "-Dpicotool_DIR:PATH=$($PicotoolDir -replace '\\','/')" `
    "-Dpioasm_DIR:PATH=$($PioasmDir -replace '\\','/')"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

cmake --build build --parallel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output "---- build artifacts ----"
Get-ChildItem build\chroma_bay.* -ErrorAction SilentlyContinue |
    Select-Object Name, Length | Format-Table -AutoSize
