$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
foreach ($file in 'src/app.ps1', 'ClevoTune.cmd') {
    $tokens = $null; $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $root $file)), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw (($errors | ForEach-Object { $_.Message }) -join '; ') }
}
$output = Join-Path $root 'build/core-validation.dll'
$null = New-Item -ItemType Directory -Force (Split-Path $output)
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /langversion:5 /target:library "/out:$output" (Join-Path $root 'src/core.cs')
if ($LASTEXITCODE -ne 0) { throw 'C# 5 compilation failed' }
Add-Type -AssemblyName PresentationFramework
$window = [Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $root 'src/main.xaml')))
if (-not $window.FindName('BtnRecheckPower')) { throw 'Missing recheck button' }
$positions = $window.FindName('CmbOvlPos').Items
if ($positions.Count -ne 7 -or $positions[4].Content -ne 'Center') { throw 'Overlay positions changed unexpectedly' }
if (-not $window.FindName('CmbOvlMonitor')) { throw 'Missing monitor selector' }
$window.Close()
Write-Output 'Windows PowerShell source/generated script parsing, C# 5 compilation and WPF markup checks passed.'
