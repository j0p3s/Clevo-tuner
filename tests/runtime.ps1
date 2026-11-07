# Tests run without starting ClevoTune or touching real GPU/EC settings.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
Add-Type -AssemblyName PresentationFramework, System.Windows.Forms
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $root 'src/app.ps1')), [ref]$tokens, [ref]$errors)
foreach ($name in 'Pump-Ui','Invoke-MVolt','Wait-UiTask','Get-ResponsiveWeb','Invoke-UiOperation','Get-OverlayWorkArea','Refresh-OverlayMonitors','Save-OverlayUi') {
    $node = $ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name}.GetNewClosure(), $true)
    . ([scriptblock]::Create($node.Extent.Text))
}
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function T($s) { $s }
function Apply-OverlayStyle { }
function Update-Overlay { }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$script:MVolt = Join-Path $root 'build/SlowTool.exe'
& $compiler /nologo /langversion:5 /target:exe "/out:$script:MVolt" (Join-Path $PSScriptRoot 'SlowTool.cs')
if ($LASTEXITCODE) { throw 'Fixture compilation failed' }
$script:Polls = 0
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(20)
$timer.Add_Tick({$script:Polls++})
$timer.Start()
try {
    $result = Invoke-MVolt @('slow') 5000
    Assert ($result.Code -eq 0 -and $result.Raw.EndsWith("completed`r`n")) 'Large stdout/stderr must drain without deadlock'
    Assert ($script:Polls -gt 3) 'Dispatcher polling must continue during slow CLI calls'
    $script:Polls = 0
    $result = Invoke-MVolt @('hang') 250
    Assert ($result.Code -eq -1) 'Timed-out CLI must fail'
    Assert ($script:Polls -gt 2) 'Dispatcher polling must continue until timeout'
    $script:Polls = 0
    $null = Wait-UiTask ([Threading.Tasks.Task]::Delay(200))
    Assert ($script:Polls -gt 2) 'Asynchronous network task wait must keep dispatcher running'
} finally { $timer.Stop() }
$info = New-Object Diagnostics.ProcessStartInfo($script:MVolt, 'http')
$info.UseShellExecute = $false; $info.CreateNoWindow = $true; $info.RedirectStandardOutput = $true
$server = [Diagnostics.Process]::Start($info)
try {
    $port = $server.StandardOutput.ReadLine()
    $script:Polls = 0; $timer.Start()
    $web = Get-ResponsiveWeb "http://127.0.0.1:$port/test" '' 5000
    Assert ($web.Content -eq 'download ok' -and $script:Polls -gt 3) 'Real HTTP response must keep dispatcher polling'
    $download = Join-Path $root 'build/download-test.txt'
    Get-ResponsiveWeb "http://127.0.0.1:$port/download" $download 5000
    Assert ([IO.File]::ReadAllText($download) -eq 'download ok') 'Asynchronous download must preserve bytes'
    $failed = $false
    try { $null = Get-ResponsiveWeb "http://127.0.0.1:$port/timeout" '' 50 } catch { $failed = $true }
    Assert $failed 'HTTP timeout must fail rather than report success'
} finally {
    $timer.Stop()
    try { if (-not $server.HasExited) { $server.Kill() } } catch { }
    $server.Dispose()
}
$script:ui = @{Tabs=[pscustomobject]@{IsEnabled=$true}}
$script:Nested = $false
Invoke-UiOperation { Invoke-UiOperation {$script:Nested = $true} }
Assert (-not $script:Nested -and $ui.Tabs.IsEnabled -and -not $script:OperationBusy) 'No overlapping operations; controls restored'
try { Invoke-UiOperation {throw 'expected failure'} } catch { }
Assert ($ui.Tabs.IsEnabled -and -not $script:OperationBusy) 'Operation failure must restore controls'
$script:Exiting = $true
$cancelled = $false
try { $null = Invoke-MVolt @('slow') } catch { $cancelled = $true }
Assert $cancelled 'Do not start subprocesses during shutdown'
$script:Exiting = $false

# Use real WPF controls without showing a window or starting the application.
$window = [Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $root 'src/main.xaml')))
$script:ovl = New-Object Windows.Window
$script:Cfg = [pscustomobject]@{overlay=[pscustomobject]@{monitor='disconnected';pos=4;enabled=$false;font=14;opacity=55;cpu=$true;gpu=$true;clk=$true;fan=$true;mem=$false}}
foreach ($name in 'CmbOvlMonitor','CmbOvlPos','ChkOverlay','SlOvlFont','SlOvlOp','OvlCpu','OvlGpu','OvlClk','OvlFan','OvlMem') { $script:ui[$name] = $window.FindName($name) }
Refresh-OverlayMonitors
Assert ($ui.CmbOvlMonitor.SelectedIndex -eq 0 -and $Cfg.overlay.monitor -eq 'disconnected') 'Missing display falls back without discarding saved selection'
$bounds = Get-OverlayWorkArea
Assert ($bounds.Left -eq [Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Left) 'Missing display uses primary work area'
$script:Loading = $false
$ui.CmbOvlPos.SelectedIndex = 6
Save-OverlayUi
Assert ($Cfg.overlay.pos -eq 6 -and $Cfg.overlay.monitor -eq 'disconnected') 'Position persists without overwriting disconnected display'
$ui.CmbOvlMonitor.SelectedIndex = 1; $script:MonitorSelectionChanged = $true
Save-OverlayUi
Assert ($Cfg.overlay.monitor -eq [Windows.Forms.Screen]::AllScreens[0].DeviceName) 'Explicit monitor selection persists'
$window.Close(); $ovl.Close()

[Reflection.Assembly]::LoadFrom((Join-Path $root 'build/core-validation.dll')) | Out-Null
Assert ([ClevoTune.FanSafety]::UseAutomatic(1,$false,[double]::NaN,60)) 'Missing CPU temperature returns CPU fan to EC'
Assert ([ClevoTune.FanSafety]::UseAutomatic(2,$false,60,[double]::NaN)) 'Missing GPU temperature returns GPU fan to EC'
Assert (-not [ClevoTune.FanSafety]::UseAutomatic(2,$false,60,65)) 'Valid temperatures permit manual fan control'
Assert (-not [ClevoTune.FanSafety]::UseAutomatic(2,$true,95,[double]::NaN)) 'Detected overheat takes precedence over missing sensor and forces full cooling'
Assert ([ClevoTune.FanSafety]::UseAutomatic(2,$false,60,[double]::PositiveInfinity)) 'Invalid temperatures are not usable thermal feedback'
Write-Output 'Runtime checks passed: responsive waits/timeouts, operation serialization, overlay monitor persistence/fallback, and thermal failover policy.'
