# Run with Windows PowerShell 5.1. No GPU, driver or application startup required.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $root 'src/app.ps1')), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw (($errors | ForEach-Object { $_.Message }) -join '; ') }
foreach ($name in 'Get-MVoltEnforcedPower', 'Apply-Tuning', 'Read-PowerState', 'Recheck-PowerLimits', 'Init-Tuning', 'Position-Overlay') {
    $node = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }.GetNewClosure(), $true)
    . ([scriptblock]::Create($node.Extent.Text))
}
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function T($s) { $s }
function Log($s) { $script:Logs += $s }
function Set-Status($s, $color) { }
function Fmt($v, $f) { $v.ToString($f) }
function Inv($f, $v) { $f -f $v }
function Update-Readback { }
function Update-TuneTexts { }
function Save-Config { $script:Saved = $true }
function Get-MVoltStatus { $script:Status }
function Invoke-MVolt($a) { $script:Writes++; [pscustomobject]@{ Code = 0; Out = '' } }
Add-Type @'
namespace ClevoTune {
 public static class NvApi {
  public static bool Ready = false;
  public static string LastError = "test";
  public static object GetPowerPolicy() { return new { Valid = false }; }
  public static object GetOffsets() { return new { Status = 1 }; }
 }
}
'@
function Reset-Test {
    $script:Cfg = [pscustomobject]@{ powerMax=''; powerLocked='test'; lastLock=0 }
    $script:Hw = [pscustomobject]@{ Driver='test'; DefaultPowerW=160.0; MinPowerW=80.0; MaxPowerW=192.0; GpuPowerLimit=160.0; PowerLimitSupported=$false; NvmlOk=$false }
    $script:Hw | Add-Member ScriptMethod RefreshPowerLimits { }
    $script:MVolt = 'mock'; $script:MVoltPowerW = [double]::NaN
    $script:PowerCapable = $true; $script:AppliedVolt = 0; $script:AppliedLock = 0
    $script:PowerUnverified = $false; $script:Writes = 0; $script:Logs = @(); $script:Saved = $false
    $script:Status = $null
    $script:ui = @{}
    foreach ($n in 'SlPower','LblPowerMin','LblPowerMax','SlCore','SlMem','SlLock','SlVolt','ChkLock','TxtLive') {
        $script:ui[$n] = [pscustomobject]@{ IsEnabled=$true; IsChecked=$false; Minimum=0; Maximum=192; Value=0; Text='' }
    }
}
foreach ($bad in $null, @{}, @{power_limits=@{}}, @{power_limits=@{enforced_mw=0}}, @{power_limits=@{enforced_mw=-1}}, @{power_limits=@{enforced_mw='185000'}}, @{power_limits=@{enforced_mw=$true}}, @{power_limits=@{enforced_mw=[double]::NaN}}, @{power_limits=@{enforced_mw=[double]::PositiveInfinity}}, @{power_limits=@{enforced_mw=9999000}}) {
    Assert ([double]::IsNaN((Get-MVoltEnforcedPower $bad))) 'Invalid status must be unverified'
}
Assert ((Get-MVoltEnforcedPower @{power_limits=@{enforced_mw=185000}}) -eq 185) '185 W readback'
Reset-Test
Apply-Tuning 180 0 0 0 'test'
Assert $script:PowerUnverified 'Missing status must not report enforcement'
Assert ([double]::IsNaN($script:MVoltPowerW)) 'Requested watts must not become readback'
Assert ($script:Cfg.powerMax -eq '') 'Missing status must not cache a ceiling'
Assert (-not (($script:Logs -join ' ') -match 'power enforced')) 'No false enforced log'
Reset-Test
$script:Status = @{power_limits=@{enforced_mw=160000}}
Apply-Tuning 180 0 0 0 'test'
Assert ($script:Cfg.powerMax -eq 'test|160') 'Verified lower limit should cache ceiling'
Reset-Test
$script:Cfg.powerMax = 'test|160'; $script:Cfg.powerLocked = 'test|mvolt'
$script:Status = @{power_limits=@{enforced_mw=185000}}
Recheck-PowerLimits
Assert ($script:Cfg.powerMax -eq '' -and $script:Cfg.powerLocked -eq '') 'Recheck clears both restrictions'
Assert $script:Saved 'Recheck persists cleared restrictions'
Assert ($script:Writes -eq 0) 'Recheck must never apply tuning'
Assert ($ui.SlPower.IsEnabled -and $ui.SlPower.Value -eq 185) 'Override restores slider with actual limit'
Assert ($ui.SlPower.Maximum -ge 185 -and $ui.SlPower.Maximum -lt 1000) 'Observed limit, not theoretical maximum'
# Stock advertised max can stay at 160 W while an external override enforces 185 W.
$script:Hw.MaxPowerW = 160.0
Init-Tuning
Assert ($ui.SlPower.Maximum -eq 185) 'Override above stock range must remain selectable'
Write-Output 'Power-limit regressions passed (invalid status, verified ceiling, read-only recheck, external override).'
Add-Type -AssemblyName PresentationFramework
$script:Cfg | Add-Member NoteProperty overlay ([pscustomobject]@{pos=4})
$script:ovl = [pscustomobject]@{ActualWidth=300.0; ActualHeight=120.0; Left=0.0; Top=0.0}
$wa = [System.Windows.SystemParameters]::WorkArea
Position-Overlay
Assert ($ovl.Left -eq $wa.Left + ($wa.Width - 300) / 2) 'Center horizontally'
Assert ($ovl.Top -eq $wa.Top + ($wa.Height - 120) / 2) 'Center vertically'
$ovl.ActualWidth = 420; $ovl.ActualHeight = 200
Position-Overlay
Assert ($ovl.Left -eq $wa.Left + ($wa.Width - 420) / 2 -and $ovl.Top -eq $wa.Top + ($wa.Height - 200) / 2) 'Recenter after size changes'
$script:Cfg.overlay.pos = 1
Position-Overlay
Assert ($ovl.Left -eq $wa.Right - 420 - 12 -and $ovl.Top -eq $wa.Top + 12) 'Existing top-right position preserved'
Write-Output 'Overlay placement checks passed.'
