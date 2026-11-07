$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $root 'src/app.ps1')), [ref]$tokens, [ref]$errors)
$node = $ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Set-AutoStart'}, $true)
. ([scriptblock]::Create($node.Extent.Text))
function Assert($ok, $message) { if (-not $ok) { throw $message } }
function T($s) { $s }
function New-ScheduledTaskAction { param($Execute,$Argument,$WorkingDirectory) @{Execute=$Execute;Arguments=$Argument;WorkingDirectory=$WorkingDirectory} }
function New-ScheduledTaskTrigger { param([switch]$AtLogOn,$User) @{AtLogOn=[bool]$AtLogOn;User=$User} }
function New-ScheduledTaskPrincipal { param($UserId,$LogonType,$RunLevel) @{UserId=$UserId;LogonType=$LogonType;RunLevel=$RunLevel} }
function New-ScheduledTaskSettingsSet { param([switch]$AllowStartIfOnBatteries,[switch]$DontStopIfGoingOnBatteries,$ExecutionTimeLimit,$MultipleInstances,[switch]$StartWhenAvailable) $PSBoundParameters }
function Register-ScheduledTask { param($TaskName,$Action,$Trigger,$Principal,$Settings,$Description,[switch]$Force,$ErrorAction) if ($script:Fail) { throw 'registration denied' }; $script:Task=$PSBoundParameters }
function Get-ScheduledTask { param($TaskName,$ErrorAction) if ($script:Task) { $script:Task } }
function Unregister-ScheduledTask { param($TaskName,$Confirm,$ErrorAction) if ($script:Fail) { throw 'removal denied' }; $script:Task=$null }
$TaskName='ClevoTune'
$Self="C:\Test folder\Joao's app\ClevoTune.cmd"
$SelfDir=Split-Path $Self
$old=$env:CT_EXE
try {
    $env:CT_EXE='0'
    Set-AutoStart $true
    $task=$script:Task
    Assert ($task.Principal.RunLevel -eq 'Highest' -and $task.Principal.LogonType -eq 'Interactive') 'Must run elevated in interactive session'
    Assert ($task.Trigger.AtLogOn -and $task.Trigger.Delay -eq 'PT15S') 'Must delay user logon startup'
    Assert ($task.Settings.StartWhenAvailable -and $task.Settings.AllowStartIfOnBatteries -and $task.Settings.DontStopIfGoingOnBatteries) 'Must support missed starts and battery'
    Assert ($task.Settings.ExecutionTimeLimit -eq [TimeSpan]::Zero -and $task.Settings.MultipleInstances -eq 'IgnoreNew') 'Must allow continuous operation without duplicate task starts'
    Assert ($task.Action.WorkingDirectory -eq $SelfDir) 'CMD working directory missing'
    $encoded=($task.Action.Arguments -split ' ')[-1]
    $decoded=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encoded))
    $env:CT_SELF=''; $env:CT_ARGS=''
    # Execute just the environment assignments, never launch the app.
    . ([scriptblock]::Create(($decoded -split '; iex')[0]))
    Assert ($env:CT_SELF -eq $Self -and $env:CT_ARGS -eq '/tray') 'Encoded path or tray argument corrupted'
    $env:CT_EXE='1'; $Self='C:\Test folder\ClevoTune.exe'
    Set-AutoStart $true
    Assert ($script:Task.Action.Execute -eq $Self -and $script:Task.Action.Arguments -eq '/tray') 'EXE startup incorrect'
    $script:Fail=$true; $caught=$false
    try { Set-AutoStart $true } catch { $caught=$true }
    Assert $caught 'Registration errors must propagate'
    $caught=$false; try { Set-AutoStart $false } catch { $caught=$true }
    Assert $caught 'Removal errors must propagate'
    $script:Fail=$false; Set-AutoStart $false; Set-AutoStart $false
    Assert (-not $script:Task) 'Disable must remove task and be idempotent'
} finally { $env:CT_EXE=$old; Remove-Item Env:CT_SELF,Env:CT_ARGS -ErrorAction SilentlyContinue }
Write-Output 'Scheduled task action, elevation, logon, settings, quoting and failure checks passed (mock scheduler; no task registered).'
