$ErrorActionPreference = 'Stop'
$AppName    = 'ClevoTune'
$AppVersion = '1.7.1'

$Self = $env:CT_SELF
if (-not $Self) { $Self = $PSCommandPath }
$SelfDir   = Split-Path -Parent $Self
$TrayStart = ("$env:CT_ARGS" -match '(?i)(^|\s)[/-]tray')

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing, Microsoft.VisualBasic

# ---------------------------------------------------------------- languages (key = English text)
$LangTable = @'
__LANG_TSV__
'@
# built-in languages (columns of the table above) and their file names in the Language folder
$BuiltinLangs = @(
    @{ Code = 'en-us'; Name = 'English'; Col = 0 },
    @{ Code = 'pt'; Name = 'Português'; Col = 1 },
    @{ Code = 'fr'; Name = 'Français'; Col = 2 },
    @{ Code = 'es'; Name = 'Español'; Col = 3 },
    @{ Code = 'de'; Name = 'Deutsch'; Col = 4 },
    @{ Code = 'it'; Name = 'Italiano'; Col = 5 }
)
$script:LangRows = New-Object System.Collections.ArrayList
$script:LangKeys = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($line in ($LangTable -split "`r?`n")) {
    if (-not $line) { continue }
    $cols = $line -split "`t"
    [void]$script:LangRows.Add($cols)
    [void]$script:LangKeys.Add($cols[0])
}
$script:LangMap = New-Object 'System.Collections.Generic.Dictionary[string,string]'
$script:Lang = 'pt'
$script:Langs = New-Object System.Collections.ArrayList   # @{ Code; Name; File; Map; Col }

function Get-LangDir {
    $d = Join-Path $SelfDir 'Language'
    try {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        $probe = Join-Path $d '.write-test'
        [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
        return $d
    } catch {
        if (Test-Path -LiteralPath (Join-Path $d '*.lng')) { return $d }   # read-only but already populated
        $d = Join-Path (Join-Path $env:APPDATA 'ClevoTune') 'Language'
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        return $d
    }
}

function New-LangFileText($bl) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('; ClevoTune language file - edit the text after the first "=" on each line.')
    [void]$sb.AppendLine('; The text before "=" is the original English text and must not be changed.')
    [void]$sb.AppendLine('; Missing or empty lines fall back to the built-in text. Lines starting with ; are comments.')
    [void]$sb.AppendLine('[info]')
    [void]$sb.AppendLine('name=' + $bl.Name)
    [void]$sb.AppendLine('code=' + $bl.Code)
    [void]$sb.AppendLine('base=en')
    [void]$sb.AppendLine('version=' + $AppVersion)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('[strings]')
    foreach ($r in $script:LangRows) { [void]$sb.AppendLine($r[0] + '=' + $r[$bl.Col]) }
    return $sb.ToString()
}

function Read-LangFile([string]$path) {
    $info = @{}; $map = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $sec = ''
    foreach ($line in [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)) {
        if (-not $line -or $line.StartsWith(';')) { continue }
        if ($line.StartsWith('[') -and $line.TrimEnd().EndsWith(']')) { $sec = $line.Trim().Trim('[', ']').ToLowerInvariant(); continue }
        $i = $line.IndexOf('=')
        if ($i -le 0) { continue }
        $k = $line.Substring(0, $i); $v = $line.Substring($i + 1)
        if ($sec -eq 'info') { $info[$k.Trim().ToLowerInvariant()] = $v.Trim() }
        else { [void]$seen.Add($k); if ($v.Length -gt 0) { $map[$k] = $v } }
    }
    return @{ Info = $info; Map = $map; Seen = $seen }
}

$script:LangNotes = New-Object System.Collections.ArrayList
# files from versions before 1.4.0 used the Portuguese text as key: convert them to English keys
function Convert-OldLangFile([string]$path, $d) {
    $pt2en = @{}
    foreach ($r in $script:LangRows) { if ($r.Count -gt 1 -and $r[1]) { $pt2en[$r[1]] = $r[0] } }
    try { Copy-Item -LiteralPath $path -Destination ($path + '.old') -Force } catch { }
    $code = [IO.Path]::GetFileNameWithoutExtension($path).ToLowerInvariant()
    $bl = $BuiltinLangs | Where-Object { $_.Code -eq $code } | Select-Object -First 1
    if ($bl) {
        # built-in language: start from the current built-in text, keep the user's own edits
        $text = New-LangFileText $bl
        $lines = New-Object System.Collections.ArrayList
        foreach ($l in ($text -split "`r?`n")) { [void]$lines.Add($l) }
        foreach ($k in $d.Map.Keys) {
            if (-not $pt2en.ContainsKey($k)) { continue }
            $en = $pt2en[$k]
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].StartsWith($en + '=')) { $lines[$i] = $en + '=' + $d.Map[$k]; break }
            }
        }
        [IO.File]::WriteAllText($path, (($lines -join "`r`n").TrimEnd() + "`r`n"), (New-Object Text.UTF8Encoding($true)))
    } else {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('; ClevoTune language file - edit the text after the first "=" on each line.')
        [void]$sb.AppendLine('; The text before "=" is the original English text and must not be changed.')
        [void]$sb.AppendLine('[info]')
        foreach ($k in $d.Info.Keys) { if ($k -ne 'base') { [void]$sb.AppendLine($k + '=' + $d.Info[$k]) } }
        [void]$sb.AppendLine('base=en')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('[strings]')
        foreach ($k in $d.Map.Keys) { $en = $(if ($pt2en.ContainsKey($k)) { $pt2en[$k] } else { $k }); [void]$sb.AppendLine($en + '=' + $d.Map[$k]) }
        [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object Text.UTF8Encoding($true)))
    }
    [void]$script:LangNotes.Add('Language file converted to English keys: ' + [IO.Path]::GetFileName($path) + ' (backup: .old)')
}

function Load-Languages {
    $script:Langs.Clear()
    $dir = $null
    try { $dir = Get-LangDir } catch { }
    if ($dir) {
        # write any missing built-in language file; never overwrite the user's edits
        foreach ($bl in $BuiltinLangs) {
            $f = Join-Path $dir ($bl.Code + '.lng')
            if (-not (Test-Path -LiteralPath $f)) {
                try { [IO.File]::WriteAllText($f, (New-LangFileText $bl), (New-Object Text.UTF8Encoding($true))) } catch { }
            }
        }
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Filter '*.lng' -ErrorAction SilentlyContinue | Sort-Object Name)) {
            try {
                $d = Read-LangFile $file.FullName
                if ($d.Info['base'] -ne 'en') { Convert-OldLangFile $file.FullName $d; $d = Read-LangFile $file.FullName }
                $code = $file.BaseName.ToLowerInvariant()
                $bl = $BuiltinLangs | Where-Object { $_.Code -eq $code } | Select-Object -First 1
                if ($bl) {
                    # texts added in newer versions: append them so the file stays complete for translators
                    $add = New-Object System.Text.StringBuilder
                    foreach ($r in $script:LangRows) { if (-not $d.Seen.Contains($r[0])) { [void]$add.AppendLine($r[0] + '=' + $r[$bl.Col]) } }
                    if ($add.Length -gt 0) { try { [IO.File]::AppendAllText($file.FullName, $add.ToString(), (New-Object Text.UTF8Encoding($false))) } catch { } }
                }
                $name = $d.Info['name']; if (-not $name) { if ($bl) { $name = $bl.Name } else { $name = $code } }
                $col = -1; if ($bl) { $col = $bl.Col }
                [void]$script:Langs.Add(@{ Code = $code; Name = $name; File = $file.FullName; Map = $d.Map; Col = $col })
            } catch { }
        }
    }
    # built-ins are always available, even without the folder
    foreach ($bl in $BuiltinLangs) {
        if (-not ($script:Langs | Where-Object { $_.Code -eq $bl.Code })) {
            [void]$script:Langs.Add(@{ Code = $bl.Code; Name = $bl.Name; File = $null; Map = $null; Col = $bl.Col })
        }
    }
    $order = @{}; for ($i = 0; $i -lt $BuiltinLangs.Count; $i++) { $order[$BuiltinLangs[$i].Code] = $i }
    $sorted = @($script:Langs | Sort-Object { if ($order.ContainsKey($_.Code)) { $order[$_.Code] } else { 100 } }, { $_.Name })
    $script:Langs.Clear(); foreach ($l in $sorted) { [void]$script:Langs.Add($l) }
    $script:LangDir = $dir
}

function Find-Lang([string]$code) {
    if (-not $code) { return $null }
    $c = $code.ToLowerInvariant()
    foreach ($l in $script:Langs) { if ($l.Code -eq $c) { return $l } }
    $two = $c.Split('-')[0]
    foreach ($l in $script:Langs) { if ($l.Code -eq $two -or $l.Code.Split('-')[0] -eq $two) { return $l } }
    return $null
}

function Resolve-Lang([string]$pref) {
    if ($pref -and $pref -ne 'auto') { $l = Find-Lang $pref; if ($l) { return $l.Code } }
    $sys = 'en-us'
    try { $sys = [Globalization.CultureInfo]::CurrentUICulture.Name } catch { }
    $l = Find-Lang $sys; if ($l) { return $l.Code }
    $l = Find-Lang 'en-us'; if ($l) { return $l.Code }
    return 'en-us'
}

function Set-Lang([string]$code) {
    $l = Find-Lang $code
    if (-not $l) { $l = Find-Lang 'en-us' }
    $script:Lang = $l.Code
    $m = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    if ($l.Col -gt 0) { foreach ($r in $script:LangRows) { if ($r.Count -gt $l.Col -and $r[$l.Col]) { $m[$r[0]] = $r[$l.Col] } } }
    if ($l.Map) { foreach ($k in $l.Map.Keys) { $m[$k] = $l.Map[$k] } }
    $script:LangMap = $m
    if ('ClevoTune.L' -as [type]) { [ClevoTune.L]::Load($m) }
}
function T([string]$k) { if ($null -ne $k -and $script:LangMap.ContainsKey($k)) { return $script:LangMap[$k] }; return $k }
Load-Languages
Set-Lang (Resolve-Lang 'auto')

trap {
    try { if ($script:Hw) { $script:Hw.ReleaseAll() } } catch { }
    try { [System.Windows.MessageBox]::Show("$(T 'Startup error:')`n`n$($_.Exception.Message)`n`n$($_.InvocationInfo.PositionMessage)", 'ClevoTune', 'OK', 'Error') | Out-Null } catch { }
    break
}

# ---------------------------------------------------------------- single instance
$createdNew = $false
$script:SingleMutex = New-Object System.Threading.Mutex($true, 'Local\ClevoTune.Single', [ref]$createdNew)
$script:ShowEvent   = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Local\ClevoTune.Show')
if (-not $createdNew) { [void]$script:ShowEvent.Set(); return }

# ---------------------------------------------------------------- paths
$DataDir  = Join-Path $env:APPDATA 'ClevoTune'
$CacheDir = Join-Path $env:LOCALAPPDATA 'ClevoTune'
$CfgPath  = Join-Path $DataDir 'config.json'
$LogPath  = Join-Path $DataDir 'clevotune.log'
foreach ($d in $DataDir, $CacheDir) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
$ModDir = Join-Path $SelfDir 'modules'

function Find-Module([string]$name) {
    foreach ($p in (Join-Path $ModDir $name), (Join-Path $SelfDir $name), (Join-Path (Join-Path $DataDir 'modules') $name)) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ---------------------------------------------------------------- C# core
$CoreSource = @'
__CORE_CS__
'@

try {
    if (-not ('ClevoTune.Hw' -as [type])) {
        $sha  = New-Object System.Security.Cryptography.SHA1Managed
        $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($CoreSource))).Replace('-', '').Substring(0, 12)
        $dll  = Join-Path $CacheDir "core-$hash.dll"
        if (-not (Test-Path -LiteralPath $dll)) {
            Get-ChildItem -LiteralPath $CacheDir -Filter 'core-*.dll' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Add-Type -TypeDefinition $CoreSource -OutputAssembly $dll -OutputType Library
        }
        if (-not ('ClevoTune.Hw' -as [type])) { Add-Type -LiteralPath $dll }
    }
} catch {
    [System.Windows.MessageBox]::Show("$(T 'Failed to compile the core:')`n`n$($_.Exception.Message)", $AppName, 'OK', 'Error') | Out-Null
    return
}

# ---------------------------------------------------------------- log (buffered until UI exists)
$ProgressPreference = 'SilentlyContinue'
$ui = $null
$script:PendingLog = New-Object 'System.Collections.Generic.List[string]'
function Log([string]$m) {
    $line = '[{0:HH:mm:ss}] {1}' -f (Get-Date), $m
    if ($ui -and $ui.TxtLog) { try { $ui.TxtLog.AppendText($line + "`r`n"); $ui.TxtLog.ScrollToEnd() } catch { } }
    else { $script:PendingLog.Add($line) }
    try {
        if ((Test-Path -LiteralPath $LogPath) -and (Get-Item -LiteralPath $LogPath).Length -gt 512KB) { Remove-Item -LiteralPath $LogPath -Force }
        [IO.File]::AppendAllText($LogPath, $line + "`r`n")
    } catch { }
}
foreach ($n in $script:LangNotes) { Log $n }

# ---------------------------------------------------------------- config
function New-Pts($pairs) {
    $o = @()
    for ($i = 0; $i -lt $pairs.Count; $i += 2) { $o += [pscustomobject]@{ t = $pairs[$i]; p = $pairs[$i + 1] } }
    return , $o
}
$LoadPresets = @{
    0 = @(0, 20, 25, 25, 50, 35, 75, 55, 100, 75)
    1 = @(0, 25, 20, 30, 40, 45, 60, 60, 80, 80, 100, 95)
    2 = @(0, 35, 20, 45, 40, 60, 60, 75, 80, 90, 100, 100)
    3 = @(0, 100, 100, 100)
}
$Presets = @{
    0 = @(45, 25, 55, 35, 65, 50, 75, 70, 85, 100)
    1 = @(40, 30, 50, 40, 60, 55, 70, 70, 80, 85, 88, 100)
    2 = @(35, 40, 45, 55, 55, 70, 65, 85, 75, 100)
    3 = @(30, 100, 100, 100)
}

function New-DefaultConfig {
    [pscustomobject]@{
        selectedProfile = 'Stock'
        autoApply       = $false
        applyOnOpen     = $true
        lastProfile     = ''
        profiles        = @([pscustomobject]@{ name = 'Stock'; power = 0; core = 0; mem = 0; lock = 0 })
        fans            = @(
            [pscustomobject]@{ index = 1; mode = 0; source = 0; fixed = 60; points = (New-Pts $Presets[1]) },
            [pscustomobject]@{ index = 2; mode = 0; source = 1; fixed = 60; points = (New-Pts $Presets[1]) }
        )
        hyst        = 3
        down        = 3
        failsafe    = 92
        interval    = 1000
        closeToTray = $true
        cfcGrid     = $false
        powerLocked = ''
        mvoltPath   = ''
        mvoltChecked = ''
        powerMax    = ''
        lastVolt    = 0
        lang        = 'auto'
        loadSmooth  = 3
        lastLock    = 0
        overlay     = [pscustomobject]@{ enabled = $false; pos = 1; monitor = ''; font = 14; opacity = 55; cpu = $true; gpu = $true; clk = $true; fan = $true; mem = $false }
    }
}

function Merge-Defaults($cfg, $def) {
    foreach ($p in $def.PSObject.Properties) {
        if (-not ($cfg.PSObject.Properties.Name -contains $p.Name)) {
            $cfg | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
        } elseif ($p.Value -is [pscustomobject] -and $cfg.($p.Name) -is [pscustomobject]) {
            Merge-Defaults $cfg.($p.Name) $p.Value
        }
    }
}

function Read-ConfigFile([string]$path) {
    $c = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $c) { throw 'empty settings file' }
    return $c
}

function Load-Config {
    $def = New-DefaultConfig
    if (Test-Path -LiteralPath $CfgPath) {
        $c = $null
        try { $c = Read-ConfigFile $CfgPath } catch {
            # unreadable (e.g. a write cut short by a power loss or reboot): keep the broken file and use the last good copy
            Log ('Settings file unreadable: {0}' -f $_.Exception.Message)
            try { Copy-Item -LiteralPath $CfgPath -Destination ($CfgPath + '.corrupt') -Force } catch { }
            if (Test-Path -LiteralPath ($CfgPath + '.bak')) {
                try { $c = Read-ConfigFile ($CfgPath + '.bak'); Log 'Settings restored from config.json.bak' } catch { }
            }
        }
        if ($c) {
            try {
                Merge-Defaults $c $def
                $c.profiles = @($c.profiles)
                $c.fans = @($c.fans)
                $c.fans = @($c.fans | Where-Object { [int]$_.index -le 2 })
                foreach ($f in $c.fans) { $f.points = @($f.points) }
                if ($c.profiles.Count -eq 0) { $c.profiles = $def.profiles }
                return $c
            } catch { }
        }
    }
    return $def
}

$script:FirstRun = -not (Test-Path -LiteralPath $CfgPath)
$script:Cfg = Load-Config
Set-Lang (Resolve-Lang ([string]$script:Cfg.lang))
$script:Dirty = $false
$script:LastSave = [DateTime]::MinValue

function Get-FanSnapshot {
    # current fan settings (mode, source, fixed %, curve points) as plain objects, stored in settings and in profiles
    $fans = @()
    foreach ($f in $script:Hw.Fans) {
        $pts = @()
        foreach ($p in $f.Points) { $pts += [pscustomobject]@{ t = $p.Temp; p = $p.Pct } }
        $fans += [pscustomobject]@{ index = $f.Index; mode = $f.Mode; source = $f.Source; fixed = $f.Fixed; points = $pts }
    }
    return , $fans
}

function Save-Config {
    try {
        $script:Cfg.fans = Get-FanSnapshot
        $json = $script:Cfg | ConvertTo-Json -Depth 8
        # write to a temporary file first, then swap it in and keep the previous version as config.json.bak,
        # so a power loss or reboot in the middle of a save can never leave profiles and curves half-written
        $tmp = $CfgPath + '.tmp'
        [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $CfgPath) { [IO.File]::Replace($tmp, $CfgPath, ($CfgPath + '.bak')) }
        else { [IO.File]::Move($tmp, $CfgPath) }
        $script:Dirty = $false
        $script:LastSave = Get-Date
    } catch { Log ((T 'Error saving settings: {0}') -f $_.Exception.Message) }
}

# ---------------------------------------------------------------- system info
$CpuName = 'CPU'; $BaseMhz = 3700; $Model = ''
try {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $CpuName = ($cpu.Name -replace '\s+', ' ').Trim()
    if ($cpu.MaxClockSpeed -gt 0) { $BaseMhz = [double]$cpu.MaxClockSpeed }
    $Model = (Get-CimInstance Win32_ComputerSystem).Model
} catch { }

# ---------------------------------------------------------------- automatic dependencies (PawnIO driver + modules)
$PawnSetupUrl = 'https://github.com/namazso/PawnIO.Setup/releases/latest/download/PawnIO_setup.exe'
$script:RebootNeeded = $false

function Test-PawnDriver { try { return [ClevoTune.PawnIo]::DriverPresent() } catch { return $false } }
function Test-PawnInstalled {
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO') {
        if (Test-Path $k) { return $true }
    }
    return $false
}

function Get-ModTargetDir {
    try {
        if (-not (Test-Path -LiteralPath $ModDir)) { New-Item -ItemType Directory -Path $ModDir -Force | Out-Null }
        $probe = Join-Path $ModDir '.write-test'
        [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
        return $ModDir
    } catch {
        $d = Join-Path $DataDir 'modules'
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        return $d
    }
}

function Wait-UiTask($task) {
    while (-not $task.IsCompleted) {
        if ($script:Exiting) { throw [OperationCanceledException]::new('Application is exiting') }
        Pump-Ui
        Start-Sleep -Milliseconds 15
    }
    if ($script:Exiting) { throw [OperationCanceledException]::new('Application is exiting') }
    return $task.GetAwaiter().GetResult()
}
function Get-ResponsiveWeb([string]$url, [string]$out = '', [int]$timeout = 60000) {
    Add-Type -AssemblyName System.Net.Http
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $client = New-Object Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromMilliseconds($timeout)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('ClevoTune')
    $response = $null
    try {
        $response = Wait-UiTask ($client.GetAsync($url))
        [void]$response.EnsureSuccessStatusCode()
        if ($out) {
            $bytes = Wait-UiTask ($response.Content.ReadAsByteArrayAsync())
            [IO.File]::WriteAllBytes($out, [byte[]]$bytes)
        } else {
            $content = Wait-UiTask ($response.Content.ReadAsStringAsync())
            return @{ Content = $content; Url = $response.RequestMessage.RequestUri.AbsoluteUri }
        }
    } finally { if ($response) { $response.Dispose() }; $client.Dispose() }
}
function Invoke-Download([string]$url, [string]$out) { Get-ResponsiveWeb $url $out }

# Serialize tuning/update operations while dispatcher events continue.
function Invoke-UiOperation([scriptblock]$action) {
    if ($script:OperationBusy -or $script:Exiting) { return }
    $script:OperationBusy = $true
    if ($ui -and $ui.Tabs) { $ui.Tabs.IsEnabled = $false }
    try { & $action }
    finally {
        $script:OperationBusy = $false
        if (-not $script:Exiting -and $ui -and $ui.Tabs) { $ui.Tabs.IsEnabled = $true }
    }
}

function Install-PawnIO {
    $tmp = Join-Path $env:TEMP ('PawnIO_setup-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        Invoke-Download $PawnSetupUrl $tmp
        $sig = Get-AuthenticodeSignature -LiteralPath $tmp
        if ($sig.Status -ne 'Valid') { throw ((T 'invalid installer signature ({0})') -f $sig.Status) }
        Log ((T 'PawnIO installer verified: {0}') -f $sig.SignerCertificate.Subject)
        $p = Start-Process -FilePath $tmp -ArgumentList '-install', '-silent' -Wait -PassThru
        switch ($p.ExitCode) {
            0       { Log (T 'PawnIO driver installed') }
            3010    { Log (T 'PawnIO driver installed — Windows requests a restart'); $script:RebootNeeded = $true }
            default { throw ((T 'the PawnIO installer exited with code {0}') -f $p.ExitCode) }
        }
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-ModulesZipUrl {
    $hdr = @{ 'User-Agent' = 'ClevoTune' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/namazso/PawnIO.Modules/releases/latest' -Headers $hdr -UseBasicParsing -TimeoutSec 30
        $asset = @($rel.assets | Where-Object { $_.name -like '*.zip' }) | Select-Object -First 1
        if ($asset) { return @($asset.browser_download_url, $rel.tag_name) }
    } catch { Log ((T 'GitHub API unavailable ({0}), trying the releases page') -f $_.Exception.Message) }
    # fallback without the API (rate limit): follow /releases/latest and read the asset list
    $r = Invoke-WebRequest -Uri 'https://github.com/namazso/PawnIO.Modules/releases/latest' -Headers $hdr -UseBasicParsing -TimeoutSec 30
    $tag = ($r.BaseResponse.ResponseUri.AbsoluteUri -split '/')[-1]
    $page = Invoke-WebRequest -Uri "https://github.com/namazso/PawnIO.Modules/releases/expanded_assets/$tag" -Headers $hdr -UseBasicParsing -TimeoutSec 30
    $m = [regex]::Match($page.Content, 'href="(/namazso/PawnIO\.Modules/releases/download/[^"]+?\.zip)"')
    if (-not $m.Success) { throw (T 'could not find the modules .zip in the latest release') }
    return @(('https://github.com' + $m.Groups[1].Value), $tag)
}

function Install-Modules {
    $info = Get-ModulesZipUrl
    $tmp = Join-Path $env:TEMP ('clevotune-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp 'modules.zip'
        Invoke-Download $info[0] $zip
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $x = Join-Path $tmp 'x'
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $x)
        $dest = Get-ModTargetDir
        $got = 0
        foreach ($n in 'LpcACPIEC.bin', 'IntelMSR.bin') {
            $f = Get-ChildItem -LiteralPath $x -Recurse -Filter $n | Where-Object { $_.FullName -notmatch '(?i)arm' } | Select-Object -First 1
            if ($f) {
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dest $n) -Force
                $shared = Join-Path $DataDir 'modules'
                if ($dest -ne $shared) { try { if (-not (Test-Path -LiteralPath $shared)) { New-Item -ItemType Directory -Path $shared -Force | Out-Null }; Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $shared $n) -Force } catch { } }
                Log ((T 'Module {0} installed ({1})') -f $n, $info[1]); $got++
            }
            else { Log ((T 'Module {0} not found in the zip ({1})') -f $n, $info[1]) }
        }
        return $got
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

# small progress window (the console is hidden)
$script:Splash = $null
function Show-Splash([string]$text) {
    if (-not $script:Splash) {
        $w = New-Object System.Windows.Window
        $w.WindowStyle = 'None'; $w.ResizeMode = 'NoResize'; $w.SizeToContent = 'WidthAndHeight'; $w.Topmost = $true
        $w.WindowStartupLocation = 'CenterScreen'; $w.ShowInTaskbar = $true; $w.Title = 'ClevoTune'
        $w.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#15181B')
        $w.BorderBrush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#45D3B4'); $w.BorderThickness = New-Object System.Windows.Thickness 1
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = New-Object System.Windows.Thickness 28, 22, 28, 22; $sp.Width = 380
        $t1 = New-Object System.Windows.Controls.TextBlock; $t1.Text = (T 'ClevoTune — first-time setup'); $t1.FontSize = 15; $t1.FontWeight = 'SemiBold'
        $t1.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#E6E8EA')
        $t2 = New-Object System.Windows.Controls.TextBlock; $t2.Margin = New-Object System.Windows.Thickness 0, 10, 0, 12; $t2.TextWrapping = 'Wrap'
        $t2.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#A9AFB5')
        $pb = New-Object System.Windows.Controls.ProgressBar; $pb.IsIndeterminate = $true; $pb.Height = 4; $pb.BorderThickness = New-Object System.Windows.Thickness 0
        $pb.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#45D3B4')
        $pb.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#2A2F34')
        [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2); [void]$sp.Children.Add($pb)
        $w.Content = $sp
        $w.Tag = $t2
        $w.Show()
        $script:Splash = $w
    }
    $script:Splash.Tag.Text = $text
    Pump-Ui
}
function Close-Splash { if ($script:Splash) { $script:Splash.Close(); $script:Splash = $null } }
function Pump-Ui {
    $script:UiFrame = New-Object System.Windows.Threading.DispatcherFrame
    [void][System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{ $script:UiFrame.Continue = $false })
    [System.Windows.Threading.Dispatcher]::PushFrame($script:UiFrame)
}

function Ensure-Dependencies([bool]$force) {
    $needDrv = $force -or -not (Test-PawnDriver)
    $needMod = $force -or -not (Find-Module 'LpcACPIEC.bin') -or -not (Find-Module 'IntelMSR.bin')
    if (-not $needDrv -and -not $needMod) { return }
    if (-not $IsAdmin) { Log (T 'Not running as administrator: PawnIO cannot be installed.'); return }
    try {
        if ($needDrv) {
            Show-Splash (T 'Downloading and installing the PawnIO driver (signed)…')
            try { Install-PawnIO } catch { Log ((T 'PawnIO installation failed: {0}') -f $_.Exception.Message) }
            if (-not (Test-PawnDriver) -and -not $script:RebootNeeded -and (Test-PawnInstalled)) {
                Log (T 'PawnIO is installed but the driver is not active yet — a restart may be needed.')
                $script:RebootNeeded = $true
            }
        }
        if ($needMod) {
            Show-Splash (T 'Downloading the PawnIO modules (fan EC and CPU MSR)…')
            try { [void](Install-Modules) } catch { Log ((T 'Module download failed: {0}') -f $_.Exception.Message) }
        }
    } finally { Close-Splash }
}

Ensure-Dependencies $false
try {
    $shared = Join-Path $DataDir 'modules'
    foreach ($n in 'LpcACPIEC.bin', 'IntelMSR.bin') {
        $f = Find-Module $n
        if ($f -and -not (Test-Path -LiteralPath (Join-Path $shared $n))) {
            if (-not (Test-Path -LiteralPath $shared)) { New-Item -ItemType Directory -Path $shared -Force | Out-Null }
            Copy-Item -LiteralPath $f -Destination (Join-Path $shared $n) -Force
        }
    }
} catch { }

# ---------------------------------------------------------------- hardware
function New-HwInstance {
    $ec  = Find-Module 'LpcACPIEC.bin'
    $msr = Find-Module 'IntelMSR.bin'
    $h = New-Object ClevoTune.Hw($ec, $msr, $BaseMhz)
    $h.Hysteresis   = [double]$script:Cfg.hyst
    $h.DownRate     = [double]$script:Cfg.down
    $h.FailsafeTemp = [double]$script:Cfg.failsafe
    $h.LoadSmoothSec = [double]$script:Cfg.loadSmooth
    foreach ($cf in $script:Cfg.fans) {
        $i = [int]$cf.index - 1
        if ($i -lt 0 -or $i -ge $h.Fans.Count) { continue }
        $f = $h.Fans[$i]
        $f.Mode = [int]$cf.mode; $f.Source = [int]$cf.source; $f.Fixed = [int]$cf.fixed
        $f.Points.Clear()
        foreach ($p in $cf.points) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$p.t, [int]$p.p))) }
        if ($f.Points.Count -eq 0) { foreach ($q in (New-Pts $Presets[1])) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$q.t, [int]$q.p))) } }
    }
    return $h
}
$script:Hw = New-HwInstance

# ---------------------------------------------------------------- mVolt+ (optional, by b00nz) via its command line
function Inv([string]$f, $v) { return [string]::Format([Globalization.CultureInfo]::InvariantCulture, $f, $v) }
function Get-MVoltDir {
    # mVolt+ lives in a mVolt+ folder next to ClevoTune (falls back to %APPDATA% if that folder is read-only)
    $d = Join-Path $SelfDir 'mVolt+'
    try {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        $probe = Join-Path $d '.write-test'
        [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
        return $d
    } catch {
        $d = Join-Path $DataDir 'mVolt+'
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        return $d
    }
}
function Get-LocalMVolt {
    foreach ($d in (Join-Path $SelfDir 'mVolt+'), (Join-Path $DataDir 'mVolt+')) {
        $f = Join-Path $d 'mVolt+.exe'
        if (Test-Path -LiteralPath $f) { return $f }
    }
    return $null
}
function Get-LocalMVoltVersion([string]$exe) {
    $vf = Join-Path (Split-Path -Parent $exe) 'version.txt'
    if (Test-Path -LiteralPath $vf) { return ([IO.File]::ReadAllText($vf)).Trim() }
    try { $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe).ProductVersion; if ($v) { return $v.Trim() } } catch { }
    return ''
}
function Find-MVolt {
    $l = Get-LocalMVolt
    if ($l) { return $l }
    # fallbacks while the local copy is missing (offline first start)
    $p = [string]$script:Cfg.mvoltPath
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    foreach ($root in (Join-Path $env:ProgramFiles 'mVolt+'), (Join-Path $env:LOCALAPPDATA 'mVolt+')) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $f = Get-ChildItem -LiteralPath $root -Recurse -Filter 'mVolt*.exe' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}
function Get-MVoltRelease {
    $hdr = @{ 'User-Agent' = 'ClevoTune' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        $rel = (Get-ResponsiveWeb 'https://api.github.com/repos/b00nz/mVolt/releases/latest' '' 20000).Content | ConvertFrom-Json
        $as = @($rel.assets | Where-Object { $_.name -match '(?i)\.exe$' }) + @($rel.assets | Where-Object { $_.name -match '(?i)\.zip$' })
        if ($as.Count -gt 0) { return @{ Tag = [string]$rel.tag_name; Url = [string]$as[0].browser_download_url } }
    } catch { }
    $r = Get-ResponsiveWeb 'https://github.com/b00nz/mVolt/releases/latest' '' 20000
    $tag = ($r.Url -split '/')[-1]
    $page = Get-ResponsiveWeb "https://github.com/b00nz/mVolt/releases/expanded_assets/$tag" '' 20000
    $m = [regex]::Match($page.Content, 'href="(/b00nz/mVolt/releases/download/[^"]+?\.(?:exe|zip))"')
    if (-not $m.Success) { throw 'no .exe or .zip in the latest mVolt+ release' }
    return @{ Tag = $tag; Url = ('https://github.com' + $m.Groups[1].Value) }
}
function Install-MVolt($rel) {
    $dir = Get-MVoltDir
    $tmp = Join-Path $dir ('download-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $name = [Uri]::UnescapeDataString(($rel.Url -split '/')[-1])
        $file = Join-Path $tmp $name
        Invoke-Download $rel.Url $file
        if ($file -match '(?i)\.zip$') {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $x = Join-Path $tmp 'x'
            [IO.Compression.ZipFile]::ExtractToDirectory($file, $x)
            $exe = Get-ChildItem -LiteralPath $x -Recurse -Filter 'mVolt*.exe' | Select-Object -First 1
            if (-not $exe) { throw 'mVolt+ .exe not found in the zip' }
            $file = $exe.FullName
        }
        $sig = Get-AuthenticodeSignature -LiteralPath $file
        if ($sig.Status -eq 'Valid') { Log ((T 'mVolt+: {0}') -f ('signed by ' + $sig.SignerCertificate.Subject)) }
        $target = Join-Path $dir 'mVolt+.exe'
        try { Copy-Item -LiteralPath $file -Destination $target -Force }
        catch {
            # the running mVolt+ keeps the file locked: install on the next start
            Copy-Item -LiteralPath $file -Destination (Join-Path $dir 'mVolt+.exe.new') -Force
            [IO.File]::WriteAllText((Join-Path $dir 'version.new'), $rel.Tag)
            Log (T 'mVolt+ update will be installed next start (file in use)')
            return $null
        }
        [IO.File]::WriteAllText((Join-Path $dir 'version.txt'), $rel.Tag)
        return $target
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
function Update-MVolt([bool]$force) {
    # finish an update that was waiting for the old file to be released
    foreach ($d in (Join-Path $SelfDir 'mVolt+'), (Join-Path $DataDir 'mVolt+')) {
        $n = Join-Path $d 'mVolt+.exe.new'
        if (Test-Path -LiteralPath $n) {
            try {
                Move-Item -LiteralPath $n -Destination (Join-Path $d 'mVolt+.exe') -Force
                $vn = Join-Path $d 'version.new'
                if (Test-Path -LiteralPath $vn) { Move-Item -LiteralPath $vn -Destination (Join-Path $d 'version.txt') -Force }
            } catch { }
        }
    }
    $local = Get-LocalMVolt
    if (-not $force -and $local -and $script:Cfg.mvoltChecked) {
        try { if (((Get-Date) - [DateTime]::Parse([string]$script:Cfg.mvoltChecked, [Globalization.CultureInfo]::InvariantCulture)).TotalHours -lt 12) { return } } catch { }
    }
    try {
        $rel = Get-MVoltRelease
        $script:Cfg.mvoltChecked = (Get-Date).ToString('s', [Globalization.CultureInfo]::InvariantCulture)
        $script:Dirty = $true
        $cur = $(if ($local) { Get-LocalMVoltVersion $local } else { '' })
        if ($local -and $cur -and ($cur.TrimStart('v') -eq $rel.Tag.TrimStart('v'))) {
            Log ((T 'mVolt+ is up to date ({0})') -f $rel.Tag)
            return
        }
        Show-Splash (T 'Checking mVolt+ updates…')
        $new = Install-MVolt $rel
        if ($new) {
            if ($local) { Log ((T 'mVolt+ updated: {0} → {1}') -f $(if ($cur) { $cur } else { '?' }), $rel.Tag) }
            else { Log ((T 'mVolt+ downloaded: {0}') -f "$new ($($rel.Tag))") }
        }
    } catch {
        Log ((T 'mVolt+ update check failed: {0}') -f $_.Exception.Message)
    } finally { Close-Splash }
}
function Invoke-MVolt([string[]]$a, [int]$timeout = 30000) {
    if ($script:Exiting) { throw [OperationCanceledException]::new('Application is exiting') }
    $psi = New-Object System.Diagnostics.ProcessStartInfo($script:MVolt)
    $psi.Arguments = ($a | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = Split-Path -Parent $script:MVolt
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        $o = $proc.StandardOutput.ReadToEndAsync(); $e = $proc.StandardError.ReadToEndAsync()
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while (-not $proc.HasExited -or -not $o.IsCompleted -or -not $e.IsCompleted) {
            if ($script:Exiting) { throw [OperationCanceledException]::new('Application is exiting') }
            if ($watch.ElapsedMilliseconds -ge $timeout) {
                try { $proc.Kill() } catch { }
                return @{ Code = -1; Out = (T 'mVolt+ did not respond in time'); Raw = '' }
            }
            Pump-Ui
            Start-Sleep -Milliseconds 15
        }
        if ($script:Exiting) { throw [OperationCanceledException]::new('Application is exiting') }
        $raw = $o.GetAwaiter().GetResult()
        $txt = (($raw + ' ' + $e.GetAwaiter().GetResult()) -replace '\s+', ' ').Trim()
        if ($txt.Length -gt 300) { $txt = $txt.Substring(0, 300) + '…' }
        return @{ Code = $proc.ExitCode; Out = $txt; Raw = $raw }
    } finally {
        try { if (-not $proc.HasExited) { $proc.Kill() } } catch { }
        $proc.Dispose()
    }
}
function Get-MVoltStatus {
    try {
        $r = Invoke-MVolt @('--status') 20000
        if ($r.Code -ne 0) { return $null }
        $i = $r.Raw.IndexOf('{')
        if ($i -lt 0) { return $null }
        return ($r.Raw.Substring($i) | ConvertFrom-Json)
    } catch { if ($script:Exiting) { throw }; return $null }
}
# Only a finite, positive readback is evidence that a power request was enforced.
function Get-MVoltEnforcedPower($status) {
    if ($null -eq $status -or $null -eq $status.power_limits) { return [double]::NaN }
    $value = $status.power_limits.enforced_mw
    if ($value -is [string] -or $value -is [bool] -or $null -eq $value) { return [double]::NaN }
    try { $mw = [double]$value } catch { return [double]::NaN }
    if ([double]::IsNaN($mw) -or [double]::IsInfinity($mw) -or $mw -le 0 -or $mw -ge 1000000) { return [double]::NaN }
    return $mw / 1000
}

if ($IsAdmin) { Update-MVolt $false }
$script:MVolt = Find-MVolt
$script:AppliedVolt = [int]$script:Cfg.lastVolt
$script:AppliedVoltKnown = $false
$script:AppliedLockKnown = $false
$script:MVoltPowerW = [double]::NaN
$script:PowerUnverified = $false

# ---------------------------------------------------------------- UI
$Xaml = @'
__MAIN_XAML__
'@

$app = New-Object System.Windows.Application
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
$win = [Windows.Markup.XamlReader]::Parse($Xaml)
$ui = @{}
foreach ($m in [regex]::Matches($Xaml, 'x:Name="(\w+)"')) { $n = $m.Groups[1].Value; $ui[$n] = $win.FindName($n) }
foreach ($l in $script:PendingLog) { $ui.TxtLog.AppendText($l + "`r`n") }
$script:PendingLog.Clear()

$script:LangTargets = New-Object System.Collections.ArrayList
function Collect-LangTargets($o) {
    if ($null -eq $o) { return }
    if ($o -is [System.Windows.Controls.TextBlock]) {
        if ($o.Text -and $script:LangKeys.Contains($o.Text)) { [void]$script:LangTargets.Add(@{ O = $o; P = 'Text'; K = $o.Text }) }
    }
    if ($o -is [System.Windows.Controls.HeaderedContentControl] -and $o.Header -is [string]) {
        if ($script:LangKeys.Contains($o.Header)) { [void]$script:LangTargets.Add(@{ O = $o; P = 'Header'; K = $o.Header }) }
    }
    if ($o -is [System.Windows.Controls.ContentControl] -and $o.Content -is [string]) {
        if ($script:LangKeys.Contains($o.Content)) { [void]$script:LangTargets.Add(@{ O = $o; P = 'Content'; K = $o.Content }) }
    }
    if ($o -is [System.Windows.Controls.DataGrid]) {
        foreach ($col in $o.Columns) { if ($col.Header -is [string] -and $script:LangKeys.Contains($col.Header)) { [void]$script:LangTargets.Add(@{ O = $col; P = 'Header'; K = $col.Header }) } }
    }
    if ($o -is [System.Windows.DependencyObject]) {
        foreach ($c in [System.Windows.LogicalTreeHelper]::GetChildren($o)) { if ($c -is [System.Windows.DependencyObject]) { Collect-LangTargets $c } }
    }
}
function Apply-LangTargets { foreach ($t in $script:LangTargets) { try { $t.O.($t.P) = (T $t.K) } catch { } } }
Collect-LangTargets $win
Apply-LangTargets

$BC = New-Object System.Windows.Media.BrushConverter
function Brush([string]$hex) { return $BC.ConvertFromString($hex) }
function Thick([double]$l, [double]$t, [double]$r, [double]$b) { return New-Object System.Windows.Thickness($l, $t, $r, $b) }
$Green = Brush '#45D3B4'; $Yellow = Brush '#F2C94C'; $Red = Brush '#F07A7A'; $Grey = Brush '#6C727A'

function Fmt($v, [string]$f) { if ($null -eq $v -or [double]::IsNaN([double]$v)) { return '—' }; return ([double]$v).ToString($f) }
function Signed([double]$v) { if ($v -gt 0) { return '+' + $v.ToString('0') }; return $v.ToString('0') }

function Set-Status([string]$m, $brush) {
    if (-not $brush) { $brush = $Green }
    $ui.TxtStatus.Text = $m
    $ui.DotStatus.Fill = $brush
}

# ---------------------------------------------------------------- icon
$bmp = New-Object System.Drawing.Bitmap 32, 32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 28, 43, 39))), 0, 0, 31, 31)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 69, 211, 180)), 3
$g.DrawEllipse($pen, 10, 10, 12, 12); $g.DrawLine($pen, 2, 16, 10, 16); $g.DrawLine($pen, 22, 16, 30, 16); $g.DrawLine($pen, 16, 22, 16, 30)
$g.Dispose()
$AppIcon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
try {
    $win.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($AppIcon.Handle, [System.Windows.Int32Rect]::Empty, [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
} catch { }

# ---------------------------------------------------------------- sensor cards
$script:Cards = @{}
function New-Card([string]$key, [string]$title, [string]$unit, [string]$color, [double]$min, [double]$max) {
    $b = New-Object System.Windows.Controls.Border
    $b.Background = Brush '#15181B'; $b.BorderBrush = Brush '#272B30'; $b.BorderThickness = Thick 1 1 1 1
    $b.CornerRadius = New-Object System.Windows.CornerRadius 8
    $b.Margin = Thick 6 6 6 6; $b.Padding = Thick 16 14 16 12; $b.Height = 140

    $grid = New-Object System.Windows.Controls.Grid
    foreach ($h in 'Auto', 'Auto', '*') {
        $rd = New-Object System.Windows.Controls.RowDefinition
        if ($h -eq '*') { $rd.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { $rd.Height = [System.Windows.GridLength]::Auto }
        $grid.RowDefinitions.Add($rd)
    }
    $top = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $top.ColumnDefinitions.Add($c0); $top.ColumnDefinitions.Add($c1)
    $t = New-Object System.Windows.Controls.TextBlock; $t.Text = (T $title); $t.Foreground = Brush '#A9AFB5'; $t.FontSize = 12; $t.FontWeight = 'SemiBold'
    $t.TextTrimming = 'CharacterEllipsis'; $t.VerticalAlignment = 'Center'
    $extra = New-Object System.Windows.Controls.TextBlock; $extra.Foreground = Brush '#6C727A'; $extra.FontSize = 11; $extra.HorizontalAlignment = 'Right'
    $extra.VerticalAlignment = 'Center'; $extra.Margin = Thick 8 0 0 0; $extra.TextTrimming = 'CharacterEllipsis'
    [System.Windows.Controls.Grid]::SetColumn($extra, 1)
    [void]$top.Children.Add($t); [void]$top.Children.Add($extra)
    [System.Windows.Controls.Grid]::SetRow($top, 0); [void]$grid.Children.Add($top)

    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'; $sp.Margin = Thick 0 8 0 0
    $v = New-Object System.Windows.Controls.TextBlock; $v.Text = '—'; $v.FontSize = 30; $v.Foreground = Brush $color
    $u = New-Object System.Windows.Controls.TextBlock; $u.Text = $unit; $u.FontSize = 14; $u.Foreground = Brush '#8B9198'; $u.Margin = Thick 6 0 0 6; $u.VerticalAlignment = 'Bottom'
    $s = New-Object System.Windows.Controls.TextBlock; $s.Text = ''; $s.FontSize = 14; $s.Foreground = Brush '#6C727A'; $s.Margin = Thick 6 0 0 6; $s.VerticalAlignment = 'Bottom'
    [void]$sp.Children.Add($v); [void]$sp.Children.Add($u); [void]$sp.Children.Add($s)
    [System.Windows.Controls.Grid]::SetRow($sp, 1); [void]$grid.Children.Add($sp)

    $cv = New-Object System.Windows.Controls.Canvas; $cv.Margin = Thick 0 8 0 0; $cv.ClipToBounds = $true
    $fill = New-Object System.Windows.Shapes.Polygon
    $fc = (Brush $color).Color; $fill.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(40, $fc.R, $fc.G, $fc.B))
    $line = New-Object System.Windows.Shapes.Polyline; $line.Stroke = Brush $color; $line.StrokeThickness = 1.6; $line.StrokeLineJoin = 'Round'
    [void]$cv.Children.Add($fill); [void]$cv.Children.Add($line)
    [System.Windows.Controls.Grid]::SetRow($cv, 2); [void]$grid.Children.Add($cv)

    $b.Child = $grid
    [void]$ui.CardsGrid.Children.Add($b)
    $script:Cards[$key] = @{ Title = $t; TitleKey = $title; Value = $v; Unit = $u; Sub = $s; Extra = $extra; Canvas = $cv; Line = $line; Fill = $fill; Hist = (New-Object 'System.Collections.Generic.List[double]'); Min = $min; Max = $max }
}

New-Card 'cpuTemp' 'CPU TEMP'    '°C'  '#59D9A6' 20 100
New-Card 'cpuFan'  'CPU FAN'     '%'   '#B4E37A' 0 100
New-Card 'cpuClk'  'CPU CLOCK'   'MHz' '#8EC5FF' 0 5000
New-Card 'cpuLoad' 'CPU LOAD'    '%'   '#D98BD9' 0 100
New-Card 'cpuPow'  'CPU POWER'   'W'   '#F2C94C' 0 60
New-Card 'ram'     'RAM'         'GB'  '#8FA2FF' 0 32
New-Card 'gpuTemp' 'GPU TEMP'    '°C'  '#59D9A6' 20 100
New-Card 'gpuFan'  'GPU FAN'     '%'   '#B4E37A' 0 100
New-Card 'gpuClk'  'GPU CLOCK'   'MHz' '#8EC5FF' 0 2100
New-Card 'gpuLoad' 'GPU LOAD'    '%'   '#D98BD9' 0 100
New-Card 'gpuPow'  'GPU POWER'   'W'   '#F2C94C' 0 150
New-Card 'vram'    'VRAM'        'GB'  '#8FA2FF' 0 16

function Push-Card([string]$key, $val, [string]$fmt, [string]$sub, [string]$extra) {
    $c = $script:Cards[$key]
    $d = [double]::NaN
    if ($null -ne $val) { $d = [double]$val }
    $c.Hist.Add($d)
    while ($c.Hist.Count -gt 60) { $c.Hist.RemoveAt(0) }
    if (-not $win.IsVisible) { return }
    $c.Value.Text = Fmt $d $fmt
    if ($null -ne $sub) { $c.Sub.Text = $sub }
    if ($null -ne $extra) { $c.Extra.Text = $extra }
    $w = $c.Canvas.ActualWidth; $h = $c.Canvas.ActualHeight
    if ($w -lt 10 -or $h -lt 6) { return }
    $max = $c.Max
    foreach ($x in $c.Hist) { if (-not [double]::IsNaN($x) -and $x -gt $max) { $max = $x } }
    $min = $c.Min
    if ($max - $min -lt 1) { $max = $min + 1 }
    $pts = New-Object System.Windows.Media.PointCollection
    $n = $c.Hist.Count
    $step = $w / 59.0
    $x0 = $w - ($n - 1) * $step
    for ($i = 0; $i -lt $n; $i++) {
        $y = $c.Hist[$i]; if ([double]::IsNaN($y)) { $y = $min }
        $py = $h - 1 - (($y - $min) / ($max - $min)) * ($h - 3)
        $pts.Add((New-Object System.Windows.Point(($x0 + $i * $step), $py)))
    }
    $c.Line.Points = $pts
    $poly = $pts.Clone()
    if ($n -gt 0) { $poly.Add((New-Object System.Windows.Point($w, $h))); $poly.Add((New-Object System.Windows.Point($x0, $h))) }
    $c.Fill.Points = $poly
}

function Update-Cards {
    $hw = $script:Hw
    $f1 = $null; $f2 = $null
    if ($hw.Fans.Count -gt 1) { $f1 = $hw.Fans[0]; $f2 = $hw.Fans[1] }
    Push-Card 'cpuTemp' $hw.CpuTemp '0' $null $null
    $rpm1 = ''; if ($f1 -and $f1.Present -and $hw.Ec) { $rpm1 = "$($f1.Rpm) RPM" }
    $d1 = [double]::NaN; if ($f1 -and $hw.Ec) { $d1 = $f1.DutyPct }
    Push-Card 'cpuFan' $d1 '0' $null $rpm1
    Push-Card 'cpuClk' $hw.CpuClock '0' $null $null
    Push-Card 'cpuLoad' $hw.CpuLoad '0' $null $null
    Push-Card 'cpuPow' $hw.CpuPower '0' $null $null
    $script:Cards['ram'].Max = [Math]::Ceiling($hw.RamTotal)
    Push-Card 'ram' $hw.RamUsed '0.0' (' / ' + (Fmt $hw.RamTotal '0')) $null
    $gt = $hw.GpuTemp; $gx = ''
    if ([double]::IsNaN($gt) -and $f2 -and $hw.Ec -and -not [double]::IsNaN($f2.EcTemp)) { $gt = $f2.EcTemp; $gx = 'EC' }
    Push-Card 'gpuTemp' $gt '0' $null $gx
    $rpm2 = ''; if ($f2 -and $f2.Present -and $hw.Ec) { $rpm2 = "$($f2.Rpm) RPM" }
    $d2 = [double]::NaN; if ($f2 -and $hw.Ec) { $d2 = $f2.DutyPct }
    Push-Card 'gpuFan' $d2 '0' $null $rpm2
    Push-Card 'gpuClk' $hw.GpuClock '0' $null ('MEM ' + (Fmt $hw.MemClock '0'))
    Push-Card 'gpuLoad' $hw.GpuLoad '0' $null $null
    if (-not [double]::IsNaN($hw.GpuPowerLimit)) { $script:Cards['gpuPow'].Max = $hw.GpuPowerLimit }
    Push-Card 'gpuPow' $hw.GpuPower '0' (' / ' + (Fmt $hw.GpuPowerLimit '0') + ' W') $null
    if (-not [double]::IsNaN($hw.VramTotal)) { $script:Cards['vram'].Max = [Math]::Ceiling($hw.VramTotal) }
    Push-Card 'vram' $hw.VramUsed '0.0' (' / ' + (Fmt $hw.VramTotal '0')) $null
}

# ---------------------------------------------------------------- header / chips
function Update-Header {
    $hw = $script:Hw
    $ui.TxtGpuName.Text = $hw.GpuName
    $parts = @()
    if ($hw.Driver) { $parts += "Driver $($hw.Driver)" }
    if (-not [double]::IsNaN($hw.DefaultPowerW)) { $parts += ('Stock {0:0} W' -f $hw.DefaultPowerW) }
    $parts += $CpuName
    $ui.TxtGpuSub.Text = ($parts -join '  ·  ')
    $ui.TxtModel.Text = $Model
    $ui.TxtVersion.Text = "v$AppVersion"

    if ($hw.Ec -and $hw.Msr) { $ui.DotPawn.Fill = $Green; $ui.ChipPawn.Text = (T 'PawnIO ready') }
    elseif ($hw.Ec -or $hw.Msr) { $ui.DotPawn.Fill = $Yellow; $ui.ChipPawn.Text = (T 'PawnIO partial') }
    else { $ui.DotPawn.Fill = $Red; $ui.ChipPawn.Text = (T 'PawnIO missing') }

    if ([ClevoTune.NvApi]::Ready) { $ui.DotNv.Fill = $Green; $ui.ChipNv.Text = (T 'NVAPI ready') } else { $ui.DotNv.Fill = $Red; $ui.ChipNv.Text = (T 'NVAPI unavailable') }
    if ($IsAdmin) { $ui.DotAdmin.Fill = $Green; $ui.ChipAdmin.Text = (T 'Administrator') } else { $ui.DotAdmin.Fill = $Red; $ui.ChipAdmin.Text = (T 'No admin') }
    Update-AutoChip

    $drv = $false; try { $drv = [ClevoTune.PawnIo]::DriverPresent() } catch { }
    $lines = @()
    $lines += (T 'PawnIO driver: {0}') -f $(if ($drv) { T 'installed' } else { T 'NOT installed' })
    $lines += (T 'EC / fans (LpcACPIEC.bin): {0}') -f $(if ($hw.Ec) { 'OK' } else { T $hw.EcError })
    $lines += (T 'CPU temp/power (IntelMSR.bin): {0}') -f $(if ($hw.Msr) { 'OK' } else { T $hw.MsrError })
    $lines += 'NVML: ' + $(if ($hw.NvmlOk) { 'OK' } else { $hw.NvmlError }) + '    NVAPI: ' + $(if ([ClevoTune.NvApi]::Ready) { 'OK' } else { [ClevoTune.NvApi]::LastError })
    $ui.TxtPawnStatus.Text = ($lines -join "`n")
    $ui.TxtPaths.Text = "Script: $Self`n" + ((T 'Modules: {0}') -f $ModDir) + "`n" + ((T 'Settings: {0}') -f $CfgPath) + "`n" + 'Language: ' + $script:LangDir
}

function Update-AutoChip {
    $lp = Get-LastProfile
    if (($script:Cfg.autoApply -or $script:Cfg.applyOnOpen) -and $lp) { $ui.DotAuto.Fill = $Green; $ui.ChipAuto.Text = ((T 'Auto-apply: {0}') -f $lp.name) }
    else { $ui.DotAuto.Fill = $Grey; $ui.ChipAuto.Text = (T 'Auto-apply: off') }
}

# ---------------------------------------------------------------- GPU tuning
$script:Loading = $true
$script:OI = $null
$script:AppliedLock = [int]$script:Cfg.lastLock

function Clamp([double]$v, [double]$a, [double]$b) { return [Math]::Max($a, [Math]::Min($b, $v)) }

function Init-Tuning {
    $hw = $script:Hw
    $script:Loading = $true
    # power limit: NVML first, NVAPI power target (% of default) as the laptop-friendly fallback
    $pp = [ClevoTune.NvApi]::GetPowerPolicy()
    $script:PP = $pp
    $defW = $hw.DefaultPowerW
    $script:PowerViaNvapi = $pp.Valid -and -not [double]::IsNaN($defW) -and ($pp.MaxPct - $pp.MinPct) -ge 1
    $script:PowerCapable = $hw.PowerLimitSupported -or $script:PowerViaNvapi
    if ($script:PowerCapable -and -not $script:PowerViaNvapi -and [string]$script:Cfg.powerLocked -and [string]$script:Cfg.powerLocked -eq [string]$hw.Driver) {
        $script:PowerCapable = $false   # already confirmed locked on this driver version
    }
    $minW = $hw.MinPowerW; $maxW = $hw.MaxPowerW
    if ($script:PowerViaNvapi) {
        $nMin = $defW * $pp.MinPct / 100; $nMax = $defW * $pp.MaxPct / 100
        if ([double]::IsNaN($minW) -or -not $hw.PowerLimitSupported) { $minW = $nMin; $maxW = $nMax }
        Log ('NVAPI power target: {0:0}–{1:0} % (default {2:0} %, now {3}) = {4:0}–{5:0} W' -f $pp.MinPct, $pp.MaxPct, $pp.DefPct, $(if ([double]::IsNaN($pp.CurPct)) { '?' } else { '{0:0} %' -f $pp.CurPct }), $nMin, $nMax)
    } elseif ([ClevoTune.NvApi]::Ready) {
        if ($pp.InfoStatus -eq 0) { Log 'NVAPI power target: no client power policies on this GPU' }
        else { Log ('NVAPI power target: ' + [ClevoTune.NvApi]::StatusText($pp.InfoStatus)) }
    }
    $mvLocked = ([string]$script:Cfg.powerLocked -eq ([string]$hw.Driver + '|mvolt'))
    if (-not $script:PowerCapable -and $script:MVolt -and -not $mvLocked -and -not [double]::IsNaN($defW)) {
        $script:PowerCapable = $true     # mVolt+ can change it when the driver blocks NVML/NVAPI
        if ([double]::IsNaN($minW) -or [double]::IsNaN($maxW) -or $maxW - $minW -lt 1) { $minW = $defW * 0.5; $maxW = $defW * 1.2 }
    }
    $pm = ([string]$script:Cfg.powerMax).Split('|')
    if ($pm.Count -eq 2 -and $pm[0] -eq [string]$hw.Driver -and [double]$pm[1] -gt 0 -and -not [double]::IsNaN($maxW)) {
        $maxW = [Math]::Min($maxW, [double]$pm[1])   # measured: the card can't go above this
    }
    # An externally applied BIOS override can exceed the stock advertised range.
    # Use the observed enforced limit, never mVolt+'s theoretical maximum.
    $activeW = $hw.GpuPowerLimit
    if (-not [double]::IsNaN($script:MVoltPowerW)) { $activeW = $script:MVoltPowerW }
    if (-not [double]::IsNaN($activeW) -and -not [double]::IsNaN($maxW)) { $maxW = [Math]::Max($maxW, $activeW) }
    if ($script:PowerCapable) {
        $ui.SlPower.IsEnabled = $true
        $ui.SlPower.Minimum = [Math]::Floor($minW)
        $ui.SlPower.Maximum = [Math]::Ceiling($maxW)
        $ui.LblPowerMin.Text = ('{0:0} W' -f $minW)
        $ui.LblPowerMax.Text = ('{0:0} W' -f $maxW)
        if (-not [double]::IsNaN($activeW)) { $ui.SlPower.Value = [Math]::Round($activeW) } else { $ui.SlPower.Value = [Math]::Round($hw.DefaultPowerW) }
    } else {
        $ui.SlPower.IsEnabled = $false
        $ui.LblPowerMin.Text = ''; $ui.LblPowerMax.Text = ''
    }

    $oi = [ClevoTune.NvApi]::GetOffsets()
    $script:OI = $oi
    if ($oi.Status -eq 0 -and $oi.CoreFound) {
        $mn = Clamp $oi.CoreMin -1000 0; $mx = Clamp $oi.CoreMax 0 1000
        if ($mx -le $mn) { $mn = -300; $mx = 300 }
        $ui.SlCore.Minimum = $mn; $ui.SlCore.Maximum = $mx
        $ui.LblCoreMin.Text = "$(Signed $mn) MHz"; $ui.LblCoreMax.Text = "$(Signed $mx) MHz"
        $ui.SlCore.Value = $oi.CoreMHz
        $ui.SlCore.IsEnabled = $oi.CoreEditable
    } else { $ui.SlCore.IsEnabled = [ClevoTune.NvApi]::Ready }
    if ($oi.Status -eq 0 -and $oi.MemFound) {
        $mn = Clamp $oi.MemMin -1000 0; $mx = Clamp $oi.MemMax 0 3000
        if ($mx -le $mn) { $mn = -500; $mx = 1500 }
        $ui.SlMem.Minimum = $mn; $ui.SlMem.Maximum = $mx
        $ui.LblMemMin.Text = "$(Signed $mn) MHz"; $ui.LblMemMax.Text = "$(Signed $mx) MHz"
        $ui.SlMem.Value = $oi.MemMHz
        $ui.SlMem.IsEnabled = $oi.MemEditable
    } else { $ui.SlMem.IsEnabled = [ClevoTune.NvApi]::Ready }

    $ui.ChkLock.IsEnabled = $hw.NvmlOk
    $ui.ChkLock.IsChecked = ($script:AppliedLock -gt 0)
    if ($script:AppliedLock -gt 0) { $ui.SlLock.Value = $script:AppliedLock }
    $ui.SlLock.IsEnabled = [bool]$ui.ChkLock.IsChecked
    $ui.SlVolt.IsEnabled = [bool]$script:MVolt
    $ui.SlVolt.Value = $script:AppliedVolt
    $script:Loading = $false
    Update-TuneTexts
    Update-Readback
}

function Update-TuneTexts {
    $hw = $script:Hw
    if ($ui.SlPower.IsEnabled) {
        $v = $ui.SlPower.Value
        $ui.ValPower.Text = ('{0:0} W' -f $v)
        if (-not [double]::IsNaN($hw.DefaultPowerW)) { $ui.DeltaPower.Text = ((T '{0} W vs stock') -f (Signed ($v - $hw.DefaultPowerW))) }
    } else {
        $ui.ValPower.Text = (Fmt $hw.GpuPowerLimit '0') + ' W'
        $ui.DeltaPower.Text = (T 'locked by vBIOS/driver')
    }
    $ui.ValCore.Text = "$(Signed $ui.SlCore.Value) MHz"; $ui.DeltaCore.Text = ((T '{0} MHz vs stock') -f (Signed $ui.SlCore.Value))
    $ui.ValMem.Text = "$(Signed $ui.SlMem.Value) MHz"; $ui.DeltaMem.Text = ((T '{0} MHz vs stock') -f (Signed $ui.SlMem.Value))
    if ($ui.ChkLock.IsChecked) { $ui.ValLock.Text = ('{0:0} MHz' -f $ui.SlLock.Value) } else { $ui.ValLock.Text = (T 'off') }
    $ui.ValVolt.Text = "$(Signed $ui.SlVolt.Value) mV"
    $ui.DeltaVolt.Text = ((T '{0} mV vs stock') -f (Signed $ui.SlVolt.Value))
}

function Update-Readback {
    $hw = $script:Hw
    if ($script:MVolt -and -not $script:AppliedVoltKnown) { $ui.CardVolt.Text = (T 'Applied value unknown; apply to confirm') }
    elseif ($script:MVolt) { $ui.CardVolt.Text = ((T 'applied: {0} mV') -f (Signed $script:AppliedVolt)) } else { $ui.CardVolt.Text = (T 'requires mVolt+') }
    if ($script:PowerCapable) {
        $ui.CardPower.Text = ((T 'on card: {0} W') -f (Fmt $hw.GpuPowerLimit '0'))
        if (-not [double]::IsNaN($script:MVoltPowerW)) { $ui.CardPower.Text = ((T 'on card: {0} W') -f (Fmt $script:MVoltPowerW '0')) + ' (mVolt+)' }
    }
    elseif ($hw.NvmlOk) { $ui.CardPower.Text = ((T 'on card: {0} W (not adjustable)') -f (Fmt $hw.GpuPowerLimit '0')) }
    else { $ui.CardPower.Text = (T 'NVML unavailable') }
    if ($script:PowerUnverified) { $ui.CardPower.Text = (T 'Power request unverified') }
    $oi = [ClevoTune.NvApi]::GetOffsets()
    $script:OI = $oi
    if ($oi.Status -eq 0) {
        if ($oi.CoreFound) { $ui.CardCore.Text = ((T 'on card: {0} MHz') -f (Signed $oi.CoreMHz)) + $(if (-not $oi.CoreEditable) { ' ' + (T '(locked)') } else { '' }) }
        if ($oi.MemFound) { $ui.CardMem.Text = ((T 'on card: {0} MHz') -f (Signed $oi.MemMHz)) + $(if (-not $oi.MemEditable) { ' ' + (T '(locked)') } else { '' }) }
    } else {
        $t = (T 'on card: {0}') -f [ClevoTune.NvApi]::StatusText($oi.Status)
        $ui.CardCore.Text = $t; $ui.CardMem.Text = $t
    }
    if (-not $script:AppliedLockKnown) { $ui.CardLock.Text = (T 'Applied value unknown; apply to confirm') }
    elseif ($script:AppliedLock -gt 0) { $ui.CardLock.Text = ((T 'applied: {0} MHz') -f $script:AppliedLock) } else { $ui.CardLock.Text = (T 'applied: off') }
}

function Apply-TuningCore([int]$power, [int]$core, [int]$mem, [int]$lock, [string]$label, [int]$volt = 0) {
    $hw = $script:Hw
    $generation = $hw.NvmlReinits
    if ($power -gt 0) { Read-PowerState }
    $ok = $true; $done = @()
    $mvPower = 0
    # a profile above the measured ceiling of this card is reduced to it (avoids retrying every start)
    $pm = ([string]$script:Cfg.powerMax).Split('|')
    if ($power -gt 0 -and $pm.Count -eq 2 -and $pm[0] -eq [string]$hw.Driver -and [double]$pm[1] -gt 0 -and $power -gt [double]$pm[1]) { $power = [int][double]$pm[1] }
    $curW = $hw.GpuPowerLimit
    if (-not [double]::IsNaN($script:MVoltPowerW)) { $curW = $script:MVoltPowerW }
    if ($power -gt 0 -and $script:PowerCapable -and -not [double]::IsNaN($curW) -and [Math]::Abs($power - $curW) -lt 0.5) {
        $power = 0   # already enforced: nothing to change
    }
    if ($power -gt 0 -and $script:PowerCapable) {
        $how = ''; $pdone = $false
        $known = [string]$script:Cfg.powerLocked -and ([string]$script:Cfg.powerLocked).Split('|')[0] -eq [string]$hw.Driver
        if (-not $known) {
            $st = 999
            if ($hw.PowerLimitSupported) { $st = $hw.SetPowerLimitW($power); $how = 'NVML ' + $hw.NvmlText($st) }
            if ($st -eq 0) { $pdone = $true }
            elseif ([ClevoTune.NvApi]::Ready -and -not [double]::IsNaN($hw.DefaultPowerW)) {
                $pp = $script:PP
                $pct = $power / $hw.DefaultPowerW * 100
                if ($script:PowerViaNvapi) { $pct = [Math]::Max($pp.MinPct, [Math]::Min($pp.MaxPct, $pct)) }
                $st2 = [ClevoTune.NvApi]::SetPowerTarget($pct)
                $how += $(if ($how) { ' → ' } else { '' }) + ('NVAPI {0:0.#} %: ' -f $pct) + [ClevoTune.NvApi]::StatusText($st2)
                if ($st2 -eq 0) { $pdone = $true }
            }
            if (-not $pdone) { $script:Cfg.powerLocked = [string]$hw.Driver; $script:Dirty = $true }
        }
        if ($pdone) {
            Log ((T 'Power {0} W: {1}') -f $power, $how)
            $hw.RefreshPowerLimits()
            $script:MVoltPowerW = [double]::NaN
            $script:PowerUnverified = [double]::IsNaN($hw.GpuPowerLimit)
            if ($script:PowerUnverified) { Log (T 'Power request unverified'); $ok = $false }
            else {
                Log ((T 'Power requested {0} W; enforced {1} W') -f $power, (Fmt $hw.GpuPowerLimit '0.###'))
                if ([Math]::Abs($hw.GpuPowerLimit - $power) -gt 1) { $ok = $false } else { $done += "$power W" }
            }
        } elseif ($script:MVolt -and -not [double]::IsNaN($hw.DefaultPowerW)) {
            if ($how) { Log ((T 'Power {0} W: {1}') -f $power, ($how + ' → mVolt+')) }
            $mvPower = $power
        } else {
            if ($how) { Log ((T 'Power {0} W: {1}') -f $power, $how) }
            $ok = $false
            $script:PowerCapable = $false
            $ui.SlPower.IsEnabled = $false
            $ui.LblPowerMin.Text = ''; $ui.LblPowerMax.Text = ''
            Log (T 'The power limit is locked on this GPU (vBIOS/driver), so the slider was disabled. Use mVolt+ to change power limits.')
        }
    }
    if ([ClevoTune.NvApi]::Ready) {
        $oi = $script:OI
        $known = ($oi -and $oi.Status -eq 0)
        if (-not $known -or ($oi.CoreFound -and $oi.CoreEditable)) {
            $st = [ClevoTune.NvApi]::SetOffset(0, $core)
            Log ((T 'Core offset {0} MHz: {1}') -f (Signed $core), [ClevoTune.NvApi]::StatusText($st))
            if ($st -eq 0) { $done += ((T 'core {0}') -f (Signed $core)) } else { $ok = $false }
        } elseif ($core -ne 0) { Log (T 'Core offset: locked by the driver on this GPU') }
        if (-not $known -or ($oi.MemFound -and $oi.MemEditable)) {
            $st = [ClevoTune.NvApi]::SetOffset(4, $mem)
            Log ((T 'Memory offset {0} MHz: {1}') -f (Signed $mem), [ClevoTune.NvApi]::StatusText($st))
            if ($st -eq 0) { $done += "mem $(Signed $mem)" } else { $ok = $false }
        } elseif ($mem -ne 0) { Log (T 'Memory offset: locked by the driver on this GPU') }
    } else { Log ((T 'NVAPI unavailable: {0}') -f [ClevoTune.NvApi]::LastError); $ok = $false }
    if ($hw.NvmlOk) {
        $script:AppliedLockKnown = $false
        if ($lock -gt 0) {
            $st = $hw.LockClocks(210, $lock)
            Log ((T 'Clock limit {0} MHz: {1}') -f $lock, $hw.NvmlText($st))
            if ($st -eq 0) { $script:AppliedLock = $lock; $script:AppliedLockKnown = $true; $done += ((T 'limit {0}') -f $lock) } else { $ok = $false }
        } else {
            $st = $hw.ResetClocks()
            if ($st -eq 0) { $script:AppliedLock = 0; $script:AppliedLockKnown = $true }
            elseif ($script:AppliedLock -gt 0) { Log ((T 'Remove clock limit: {0}') -f $hw.NvmlText($st)); $ok = $false }
        }
        $script:Cfg.lastLock = $script:AppliedLock; $script:Dirty = $true
    }
    # mVolt+: power and voltage in separate calls, so one refused option doesn't block the other
    if ($mvPower -gt 0) {
        $script:MVoltPowerW = [double]::NaN
        $script:PowerUnverified = $true
        $def = $hw.DefaultPowerW
        $runs = @()
        if ($mvPower -lt $def - 0.5) { $runs += ,@('--power-cap-watts', (Inv '{0:0.###}' $mvPower)) }
        elseif ($mvPower -le $def + 0.5) { $runs += ,@('--return-to-percentage') }
        else { $runs += ,@('--power', [string][int][Math]::Round($mvPower / $def * 100)); $runs += ,@('--power-cap-watts', (Inv '{0:0.###}' $mvPower)) }
        $r = $null
        foreach ($cmd in $runs) {
            $r = Invoke-MVolt $cmd
            Log ((T 'mVolt+: {0}') -f ('[' + ($cmd -join ' ') + '] exit ' + $r.Code + $(if ($r.Out) { ' — ' + $r.Out } else { '' })))
            if ($r.Code -eq 0) { break }
        }
        if ($r -and $r.Code -eq 0) {
            $s = Get-MVoltStatus
            $script:MVoltPowerW = Get-MVoltEnforcedPower $s
            $script:PowerUnverified = [double]::IsNaN($script:MVoltPowerW)
            if ($script:PowerUnverified) {
                Log (T 'Power request unverified')
                $ok = $false
            } else { Log ((T 'Power requested {0} W; enforced {1} W') -f $mvPower, (Fmt $script:MVoltPowerW '0.###')) }
            if (-not $script:PowerUnverified -and $script:MVoltPowerW -lt $mvPower - 1) {
                # accepted, but the card won't go that high: remember the real ceiling for this driver
                $ceil = [int][Math]::Round([Math]::Max($script:MVoltPowerW, $def))
                $script:Cfg.powerMax = [string]$hw.Driver + '|' + $ceil; $script:Dirty = $true
                $ui.SlPower.Maximum = $ceil; $ui.LblPowerMax.Text = ('{0:0} W' -f $ceil)
                Log ((T 'The card still enforces {0} W: on this GPU the power limit can be lowered, but not raised above {1} W. The slider maximum is now {1} W.') -f (Fmt $script:MVoltPowerW '0'), $ceil)
                $ok = $false
            } elseif (-not $script:PowerUnverified -and [Math]::Abs($script:MVoltPowerW - $mvPower) -gt 1) {
                $ok = $false
            } elseif (-not $script:PowerUnverified) { $done += "$mvPower W" }
        } else {
            $ok = $false
            $script:Cfg.powerLocked = [string]$hw.Driver + '|mvolt'; $script:Dirty = $true
            $script:PowerCapable = $false
            $ui.SlPower.IsEnabled = $false
            $ui.LblPowerMin.Text = ''; $ui.LblPowerMax.Text = ''
            Log (T 'The power limit is locked on this GPU: NVML, NVAPI and mVolt+ all refused it, so the slider was disabled.')
        }
    }
    if ($script:MVolt -and (-not $script:AppliedVoltKnown -or $volt -ne $script:AppliedVolt)) {
        $script:AppliedVoltKnown = $false
        $vArg = Inv '{0}' $volt
        $r = Invoke-MVolt @('--core-vdemand', $vArg)
        Log ((T 'mVolt+: {0}') -f ("[--core-vdemand $vArg] exit " + $r.Code + $(if ($r.Out) { ' — ' + $r.Out } else { '' })))
        if ($r.Code -eq 0) {
            $script:AppliedVolt = $volt; $script:AppliedVoltKnown = $true; $script:Cfg.lastVolt = $volt; $script:Dirty = $true
            $done += ((T 'voltage {0} mV') -f (Signed $volt))
        } else { $ok = $false }
    }
    if ($hw.NvmlReinits -ne $generation) { Invalidate-TuningReadback; $done = @(); $ok = $false }
    $when = (Get-Date).ToString('HH:mm:ss')
    $txt = "$label " + ($done -join ' / ') + "  ($when)"
    if ($ok) { Set-Status $txt $Green; $ui.TxtLive.Text = (T 'Applied to card') } else { Set-Status ((T '{0} — see log') -f $txt) $Yellow; $ui.TxtLive.Text = (T 'Applied with warnings') }
    Update-Readback
}

function Apply-Tuning([int]$power, [int]$core, [int]$mem, [int]$lock, [string]$label, [int]$volt = 0) {
    Invoke-UiOperation { Apply-TuningCore $power $core $mem $lock $label $volt }
}
function Invalidate-TuningReadback {
    $script:AppliedVoltKnown = $false; $script:AppliedLockKnown = $false
    $script:MVoltPowerW = [double]::NaN
    $script:PowerUnverified = [double]::IsNaN($script:Hw.GpuPowerLimit)
    Log (T 'GPU reset: previous voltage and clock-lock values are unverified')
}
$ui.SlPower.Add_ValueChanged({ Update-TuneTexts })
$ui.SlCore.Add_ValueChanged({ Update-TuneTexts })
$ui.SlMem.Add_ValueChanged({ Update-TuneTexts })
$ui.SlLock.Add_ValueChanged({ Update-TuneTexts })
$ui.SlVolt.Add_ValueChanged({ Update-TuneTexts })
$ui.ChkLock.Add_Click({ $ui.SlLock.IsEnabled = [bool]$ui.ChkLock.IsChecked; Update-TuneTexts })

function Current-Sliders {
    $p = 0; if ($ui.SlPower.IsEnabled) { $p = [int]$ui.SlPower.Value }
    $l = 0; if ($ui.ChkLock.IsChecked) { $l = [int]$ui.SlLock.Value }
    $v = 0; if ($script:MVolt) { $v = [int]$ui.SlVolt.Value }
    return [pscustomobject]@{ power = $p; core = [int]$ui.SlCore.Value; mem = [int]$ui.SlMem.Value; lock = $l; volt = $v }
}

$ui.BtnApply.Add_Click({
    try { $s = Current-Sliders; Apply-Tuning $s.power $s.core $s.mem $s.lock (T 'Applied') $s.volt } catch { Log ((T 'Error: {0}') -f $_.Exception.Message) }
})
$ui.BtnStock.Add_Click({
    try {
        $hw = $script:Hw
        $script:Loading = $true
        if ($ui.SlPower.IsEnabled -and -not [double]::IsNaN($hw.DefaultPowerW)) { $ui.SlPower.Value = [Math]::Round($hw.DefaultPowerW) }
        $ui.SlCore.Value = 0; $ui.SlMem.Value = 0; $ui.SlVolt.Value = 0; $ui.ChkLock.IsChecked = $false; $ui.SlLock.IsEnabled = $false
        $script:Loading = $false
        Update-TuneTexts
        $s = Current-Sliders
        Apply-Tuning $s.power 0 0 0 (T 'Stock:') 0
    } catch { Log ((T 'Error: {0}') -f $_.Exception.Message) }
})
function Read-PowerState {
    $script:Hw.RefreshPowerLimits()
    $script:MVoltPowerW = [double]::NaN
    if ($script:MVolt) { $script:MVoltPowerW = Get-MVoltEnforcedPower (Get-MVoltStatus) }
    $script:PowerUnverified = [double]::IsNaN($script:MVoltPowerW) -and [double]::IsNaN($script:Hw.GpuPowerLimit)
}

function Recheck-PowerLimits {
    # Read-only hardware queries: no profiles, clock changes or fan commands.
    $script:Cfg.powerMax = ''; $script:Cfg.powerLocked = ''; $script:Dirty = $true
    Save-Config
    Read-PowerState
    Init-Tuning
    $message = if ($script:PowerUnverified) { T 'Power request unverified' } else { T 'Power limits rechecked; no tuning applied' }
    Log $message
    Set-Status $message $(if ($script:PowerUnverified) { $Yellow } else { $Green })
}
$ui.BtnRecheckPower.Add_Click({ Invoke-UiOperation { Recheck-PowerLimits } })
$ui.BtnRefresh.Add_Click({ Invoke-UiOperation { Read-PowerState; Update-Readback; Set-Status (T 'Values re-read from the card') $(if ($script:PowerUnverified) { $Yellow } else { $Green }) } })

# ---------------------------------------------------------------- profiles
function Profile-Text($p) {
    $a = @()
    if ([int]$p.power -gt 0) { $a += "$($p.power) W" } else { $a += (T 'stock power') }
    $a += ((T 'core {0}') -f (Signed $p.core)); $a += "mem $(Signed $p.mem)"
    if ([int]$p.lock -gt 0) { $a += (((T 'limit {0}') -f $p.lock) + ' MHz') }
    if ([int]$p.volt -ne 0) { $a += ((T 'voltage {0} mV') -f (Signed ([int]$p.volt))) }
    if ($p.PSObject.Properties.Name -contains 'fans' -and @($p.fans).Count -gt 0) { $a += (T 'fan curves') }
    return ($a -join ' / ') + '   —   ' + (T 'Load fills the sliders, Apply writes them')
}
function Load-ProfileFans($p, [int]$only = 0) {
    # restore the fan curves saved with a profile (only = 1 CPU fan, 2 GPU fan, 0 both); false if the profile has none
    if (-not $p -or -not ($p.PSObject.Properties.Name -contains 'fans') -or @($p.fans).Count -eq 0) { return $false }
    $done = $false
    foreach ($cf in @($p.fans)) {
        $idx = [int]$cf.index
        if ($idx -lt 1 -or $idx -gt $script:Hw.Fans.Count) { continue }
        if ($only -gt 0 -and $idx -ne $only) { continue }
        $f = $script:Hw.Fans[$idx - 1]
        $pts = @($cf.points)
        if ($pts.Count -eq 0) { continue }
        $f.Mode = [int]$cf.mode; $f.Source = [int]$cf.source; $f.Fixed = [int]$cf.fixed
        $f.Points.Clear()
        foreach ($q in $pts) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$q.t, [int]$q.p))) }
        if ($script:Cfg.cfcGrid -and -not (Test-OnGrid $f)) { Set-GridPoints $f (Get-GridValues $f) }
        $f.EffTemp = [double]::NaN
        $done = $true
    }
    if ($done) {
        $script:Dirty = $true
        if ($script:SelFan) { Select-Fan $script:SelFan }
        Save-Config
    }
    return $done
}
function Get-Profile([string]$name) { foreach ($p in $script:Cfg.profiles) { if ($p.name -eq $name) { return $p } }; return $null }
function Get-LastProfile {
    # the profile most recently created/saved by the user; the built-in 'Stock' alone does not count
    if ($script:Cfg.lastProfile) { $p = Get-Profile ([string]$script:Cfg.lastProfile); if ($p) { return $p } }
    $all = @($script:Cfg.profiles)
    if ($all.Count -gt 1) { return $all[$all.Count - 1] }
    if ($all.Count -eq 1 -and [string]$all[0].name -ne 'Stock') { return $all[0] }
    return $null
}
function Fill-Profiles {
    $script:Loading = $true
    $ui.CmbProfiles.Items.Clear()
    foreach ($p in $script:Cfg.profiles) { [void]$ui.CmbProfiles.Items.Add([string]$p.name) }
    $ui.CmbProfiles.SelectedItem = [string]$script:Cfg.selectedProfile
    if ($ui.CmbProfiles.SelectedIndex -lt 0 -and $ui.CmbProfiles.Items.Count -gt 0) { $ui.CmbProfiles.SelectedIndex = 0; $script:Cfg.selectedProfile = [string]$ui.CmbProfiles.SelectedItem }
    $script:Loading = $false
    $p = Get-Profile $script:Cfg.selectedProfile
    if ($p) { $ui.TxtProfileInfo.Text = Profile-Text $p }
    Update-AutoChip
    Build-TrayMenu
}
$ui.CmbProfiles.Add_SelectionChanged({
    if ($script:Loading -or -not $ui.CmbProfiles.SelectedItem) { return }
    $script:Cfg.selectedProfile = [string]$ui.CmbProfiles.SelectedItem
    $p = Get-Profile $script:Cfg.selectedProfile
    if ($p) { $ui.TxtProfileInfo.Text = Profile-Text $p }
    $script:Dirty = $true
    Update-AutoChip
})
function Load-ProfileToSliders($p) {
    $hw = $script:Hw
    $script:Loading = $true
    if ($ui.SlPower.IsEnabled) {
        if ([int]$p.power -gt 0) { $ui.SlPower.Value = [int]$p.power } elseif (-not [double]::IsNaN($hw.DefaultPowerW)) { $ui.SlPower.Value = [Math]::Round($hw.DefaultPowerW) }
    }
    $ui.SlCore.Value = [int]$p.core; $ui.SlMem.Value = [int]$p.mem
    $ui.ChkLock.IsChecked = ([int]$p.lock -gt 0); $ui.SlLock.IsEnabled = [bool]$ui.ChkLock.IsChecked
    if ([int]$p.lock -gt 0) { $ui.SlLock.Value = [int]$p.lock }
    $ui.SlVolt.Value = [int]$p.volt
    $script:Loading = $false
    Update-TuneTexts
    [void](Load-ProfileFans $p)
}
$ui.BtnLoad.Add_Click({
    $p = Get-Profile ([string]$ui.CmbProfiles.SelectedItem)
    if ($p) { Load-ProfileToSliders $p; Set-Status ((T "Profile '{0}' loaded into the sliders — press Apply") -f $p.name) $Green }
})
$ui.BtnSaveAs.Add_Click({
    $def = [string]$ui.CmbProfiles.SelectedItem
    $name = [Microsoft.VisualBasic.Interaction]::InputBox((T 'Profile name:'), $AppName, $def)
    $name = "$name".Trim()
    if (-not $name) { return }
    $s = Current-Sliders
    $p = Get-Profile $name
    if ($p) {
        $r = [System.Windows.MessageBox]::Show(((T "Replace profile '{0}'?") -f $name), $AppName, 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
        $p.power = $s.power; $p.core = $s.core; $p.mem = $s.mem; $p.lock = $s.lock
        $p | Add-Member -NotePropertyName volt -NotePropertyValue $s.volt -Force
        $p | Add-Member -NotePropertyName fans -NotePropertyValue (Get-FanSnapshot) -Force
    } else {
        $script:Cfg.profiles = @($script:Cfg.profiles) + [pscustomobject]@{ name = $name; power = $s.power; core = $s.core; mem = $s.mem; lock = $s.lock; volt = $s.volt; fans = (Get-FanSnapshot) }
    }
    $script:Cfg.selectedProfile = $name
    $script:Cfg.lastProfile = $name
    Save-Config
    Fill-Profiles
    Set-Status ((T "Profile '{0}' saved") -f $name) $Green
})
$ui.BtnDelete.Add_Click({
    $name = [string]$ui.CmbProfiles.SelectedItem
    if (-not $name) { return }
    if (@($script:Cfg.profiles).Count -le 1) { Set-Status (T 'At least one profile must exist') $Yellow; return }
    $r = [System.Windows.MessageBox]::Show(((T "Delete profile '{0}'?") -f $name), $AppName, 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    $script:Cfg.profiles = @($script:Cfg.profiles | Where-Object { $_.name -ne $name })
    $script:Cfg.selectedProfile = [string]$script:Cfg.profiles[0].name
    if ([string]$script:Cfg.lastProfile -eq $name) { $script:Cfg.lastProfile = '' }
    Save-Config
    Fill-Profiles
})

# ---------------------------------------------------------------- autostart (scheduled task)
$TaskName = 'ClevoTune'
function Test-AutoStart { try { return [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) } catch { return $false } }
function Set-AutoStart([bool]$on) {
    if ($on) {
        $p = $Self.Replace("'", "''")
        # Encode the script so spaces, apostrophes and Unicode paths survive task quoting.
        $command = "`$env:CT_SELF='$p'; `$env:CT_ARGS='/tray'; iex ([IO.File]::ReadAllText(`$env:CT_SELF))"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $arg = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -EncodedCommand $encoded"
        $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ($env:CT_EXE -eq '1') { $act = New-ScheduledTaskAction -Execute $Self -Argument '/tray' -WorkingDirectory $SelfDir }
        else { $act = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arg -WorkingDirectory $SelfDir }
        $trg = New-ScheduledTaskTrigger -AtLogOn -User $user
        $trg.Delay = 'PT15S'
        $prn = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -StartWhenAvailable
        Register-ScheduledTask -TaskName $TaskName -Action $act -Trigger $trg -Principal $prn -Settings $set -Description (T 'ClevoTune: GPU profile + fan curves at logon') -Force -ErrorAction Stop | Out-Null
    } else {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        }
    }
}
$ui.ChkApplyOnOpen.Add_Click({
    $script:Cfg.applyOnOpen = [bool]$ui.ChkApplyOnOpen.IsChecked
    Save-Config
    Update-AutoChip
})
function Set-StartWithWindows([bool]$want) {
    try {
        Set-AutoStart $want
        $script:Cfg.autoApply = $want
        Save-Config
        $lp = Get-LastProfile; $pn = $(if ($lp) { $lp.name } else { 'Stock' })
        Log $(if ($want) { (T "Start with Windows enabled (profile '{0}')") -f $pn } else { T 'Start with Windows disabled' })
        Set-Status $(if ($want) { T 'Starts with Windows at sign-in' } else { T 'Start with Windows disabled' }) $Green
    } catch {
        Log ((T 'Scheduled task failed: {0}') -f $_.Exception.Message)
        Set-Status (T 'Could not create the scheduled task — see log') $Red
    }
    # keep every copy of the option in sync with the real state of the task
    $on = Test-AutoStart
    $script:Cfg.autoApply = $on
    Save-Config
    $ui.ChkAutoApply.IsChecked = $on
    $ui.ChkStartup.IsChecked = $on
    Update-AutoChip
    Build-TrayMenu
}
$ui.ChkAutoApply.Add_Click({ Set-StartWithWindows ([bool]$ui.ChkAutoApply.IsChecked) })
$ui.ChkStartup.Add_Click({ Set-StartWithWindows ([bool]$ui.ChkStartup.IsChecked) })

# ---------------------------------------------------------------- fans tab
$script:SelFan = $null
$script:FanItems = @{}
$script:Drag = $null
$script:PtSig = ''
function Mode-Name([int]$i) { return T (@('Auto (EC)', 'Curve', 'Fixed')[$i]) }

function Build-FanList {
    $ui.FanList.Children.Clear()
    $script:FanItems = @{}
    $hw = $script:Hw
    $enabled = [bool]$hw.Ec
    foreach ($c in 'CmbFanMode', 'CmbFanSource', 'CmbPreset', 'SlFixed', 'GridPoints', 'BtnAddPt', 'BtnDelPt', 'BtnAllAuto', 'ChkCfcGrid', 'BtnImportCfc', 'BtnExportCfc', 'BtnSaveCurves') { $ui[$c].IsEnabled = $enabled }
    if (-not $enabled) {
        $ui.TxtFanNote.Text = ((T 'Fan control unavailable: {0}. See the Settings tab.') -f (T $hw.EcError))
        $ui.TxtFanNote.Foreground = $Yellow
    } else {
        $ui.TxtFanNote.Text = (T 'Closing the app returns the fans to the EC''s automatic control.')
        $ui.TxtFanNote.Foreground = Brush '#8B9198'
    }
    $first = $null
    foreach ($f in $hw.Fans) {
        if ($enabled -and -not $f.Present) { continue }
        $b = New-Object System.Windows.Controls.Border
        $b.CornerRadius = New-Object System.Windows.CornerRadius 6
        $b.Padding = Thick 12 9 12 9; $b.Margin = Thick 0 0 10 8; $b.Cursor = 'Hand'
        $b.BorderThickness = Thick 1 1 1 1; $b.BorderBrush = Brush '#30353B'; $b.Background = Brush '#101315'
        $sp = New-Object System.Windows.Controls.StackPanel
        $t = New-Object System.Windows.Controls.TextBlock; $t.Text = ((T 'Fan {0} · {1}') -f $f.Index, $f.Name); $t.FontSize = 14
        $s = New-Object System.Windows.Controls.TextBlock; $s.Foreground = Brush '#8B9198'; $s.FontSize = 12; $s.Margin = Thick 0 3 0 0
        [void]$sp.Children.Add($t); [void]$sp.Children.Add($s)
        $b.Child = $sp
        $b.Tag = $f
        $b.Add_MouseLeftButtonUp({ param($sender, $e) Select-Fan $sender.Tag })
        [void]$ui.FanList.Children.Add($b)
        $script:FanItems[$f.Index] = @{ Border = $b; Sub = $s }
        if (-not $first) { $first = $f }
    }
    $sel = $first
    if ($script:SelFan) { foreach ($f in $hw.Fans) { if ($f.Index -eq $script:SelFan.Index -and $script:FanItems.ContainsKey($f.Index)) { $sel = $f } } }
    if ($sel) { Select-Fan $sel }
}

function Select-Fan($f) {
    $script:SelFan = $f
    $script:Loading = $true
    foreach ($k in $script:FanItems.Keys) {
        $it = $script:FanItems[$k]
        if ($k -eq $f.Index) { $it.Border.BorderBrush = $Green; $it.Border.Background = Brush '#14231F' } else { $it.Border.BorderBrush = Brush '#30353B'; $it.Border.Background = Brush '#101315' }
    }
    $ui.CmbFanMode.SelectedIndex = $f.Mode
    $ui.CmbFanSource.SelectedIndex = $f.Source
    $ui.CmbPreset.SelectedIndex = -1
    $ui.SlFixed.Value = $f.Fixed
    $ui.ValFixed.Text = "$($f.Fixed) %"
    $ui.GridPoints.ItemsSource = $f.Points
    $script:Loading = $false
    Update-FanPanels
    Update-GridLock
    Update-AxisUi
    Draw-Curve
}

function Update-FanPanels {
    $f = $script:SelFan
    if (-not $f) { return }
    if ($f.Mode -eq 2) { $ui.PnlFixed.Visibility = 'Visible' } else { $ui.PnlFixed.Visibility = 'Collapsed' }
    $ui.PnlCurve.Opacity = $(if ($f.Mode -eq 1) { 1.0 } else { 0.45 })
    $ui.CmbFanSource.IsEnabled = ($f.Mode -eq 1 -and [bool]$script:Hw.Ec)
}

function Sort-Points($f) {
    $arr = @($f.Points | Sort-Object Temp)
    $same = $true
    for ($i = 0; $i -lt $arr.Count; $i++) { if (-not [object]::ReferenceEquals($arr[$i], $f.Points[$i])) { $same = $false; break } }
    if ($same) { return }
    $f.Points.Clear()
    foreach ($p in $arr) { $f.Points.Add($p) }
}

$ui.CmbFanMode.Add_SelectionChanged({
    if ($script:Loading -or -not $script:SelFan -or $ui.CmbFanMode.SelectedIndex -lt 0) { return }
    $script:SelFan.Mode = $ui.CmbFanMode.SelectedIndex
    Log ((T 'Fan {0} ({1}): mode {2}') -f $script:SelFan.Index, $script:SelFan.Name, (Mode-Name $script:SelFan.Mode))
    $script:Dirty = $true
    Update-FanPanels; Draw-Curve
})
$ui.CmbFanSource.Add_SelectionChanged({
    if ($script:Loading -or -not $script:SelFan -or $ui.CmbFanSource.SelectedIndex -lt 0) { return }
    $script:SelFan.Source = $ui.CmbFanSource.SelectedIndex
    $script:SelFan.EffTemp = [double]::NaN
    $script:SelFan.LoadEma = [double]::NaN
    $src = $ui.CmbFanSource.SelectedItem.Content
    Log ((T 'Fan {0} ({1}): input {2}') -f $script:SelFan.Index, $script:SelFan.Name, $src)
    Update-AxisUi
    Draw-Curve
    $script:Dirty = $true
})
$ui.CmbPreset.Add_SelectionChanged({
    if ($script:Loading -or -not $script:SelFan -or $ui.CmbPreset.SelectedIndex -lt 0) { return }
    $f = $script:SelFan
    $f.Points.Clear()
    $set = $Presets; if ($f.IsLoad) { $set = $LoadPresets }
    foreach ($q in (New-Pts $set[$ui.CmbPreset.SelectedIndex])) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$q.t, [int]$q.p))) }
    if ($script:Cfg.cfcGrid) { Set-GridPoints $f (Get-GridValues $f) }
    $script:Dirty = $true
    Draw-Curve
})
$ui.SlFixed.Add_ValueChanged({
    $ui.ValFixed.Text = ('{0:0} %' -f $ui.SlFixed.Value)
    if ($script:Loading -or -not $script:SelFan) { return }
    $script:SelFan.Fixed = [int]$ui.SlFixed.Value
    $script:Dirty = $true
})
$ui.BtnAddPt.Add_Click({
    $f = $script:SelFan; if (-not $f) { return }
    Sort-Points $f
    $t = 60; $p = 50
    if ($f.Points.Count -gt 0) { $last = $f.Points[$f.Points.Count - 1]; $t = [Math]::Min(105, $last.Temp + 5); $p = [Math]::Min(100, $last.Pct + 10) }
    $f.Points.Add((New-Object ClevoTune.CurvePoint($t, $p)))
    $script:Dirty = $true; Draw-Curve
})
$ui.BtnDelPt.Add_Click({
    $f = $script:SelFan; if (-not $f -or $f.Points.Count -le 1) { return }
    $sel = $ui.GridPoints.SelectedItem
    if ($sel) { [void]$f.Points.Remove($sel) } else { $f.Points.RemoveAt($f.Points.Count - 1) }
    $script:Dirty = $true; Draw-Curve
})
$ui.GridPoints.Add_CellEditEnding({
    [void]$win.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{ Draw-Curve })
})

# curve geometry
$script:XMin = 20; $script:XMax = 100; $script:XUnit = '°'; $CL = 40; $CR = 14; $CTp = 12; $CB = 26
function Update-AxisUi {
    $f = $script:SelFan
    if ($f -and $f.IsLoad) { $script:XMin = 0; $script:XMax = 100; $script:XUnit = '%'; $hdr = (T 'Load (%)') }
    else { $script:XMin = 20; $script:XMax = 100; $script:XUnit = '°'; $hdr = (T 'Temp. (°C)') }
    try { $ui.GridPoints.Columns[0].Header = $hdr } catch { }
}
function CX([double]$t) { $w = $ui.CurveCanvas.ActualWidth; return $CL + ($t - $script:XMin) / ($script:XMax - $script:XMin) * ($w - $CL - $CR) }
function CY([double]$p) { $h = $ui.CurveCanvas.ActualHeight; return $CTp + ($h - $CTp - $CB) * (1 - $p / 100.0) }
function InvX([double]$x) { $w = $ui.CurveCanvas.ActualWidth; return $script:XMin + ($x - $CL) / ($w - $CL - $CR) * ($script:XMax - $script:XMin) }
function InvY([double]$y) { $h = $ui.CurveCanvas.ActualHeight; return 100.0 * (1 - ($y - $CTp) / ($h - $CTp - $CB)) }

function Add-Shape($s) { [void]$ui.CurveCanvas.Children.Add($s) }
function New-Line([double]$x1, [double]$y1, [double]$x2, [double]$y2, $brush, [double]$th) {
    $l = New-Object System.Windows.Shapes.Line
    $l.X1 = $x1; $l.Y1 = $y1; $l.X2 = $x2; $l.Y2 = $y2; $l.Stroke = $brush; $l.StrokeThickness = $th
    return $l
}
function New-Label([string]$txt, [double]$x, [double]$y, $brush) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $txt; $t.FontSize = 11; $t.Foreground = $brush
    [System.Windows.Controls.Canvas]::SetLeft($t, $x); [System.Windows.Controls.Canvas]::SetTop($t, $y)
    return $t
}

function Draw-Curve {
    $cv = $ui.CurveCanvas
    $f = $script:SelFan
    $w = $cv.ActualWidth; $h = $cv.ActualHeight
    if (-not $f -or $w -lt 80 -or $h -lt 60) { return }
    $cv.Children.Clear()
    $gridB = Brush '#22272C'; $lblB = Brush '#6C727A'
    for ($t = $script:XMin; $t -le $script:XMax; $t += 10) {
        $x = CX $t
        Add-Shape (New-Line $x (CY 100) $x (CY 0) $gridB 1)
        Add-Shape (New-Label "${t}$($script:XUnit)" ($x - 8) ((CY 0) + 5) $lblB)
    }
    for ($p = 0; $p -le 100; $p += 20) {
        $y = CY $p
        Add-Shape (New-Line (CX $script:XMin) $y (CX $script:XMax) $y $gridB 1)
        Add-Shape (New-Label "${p}%" 4 ($y - 8) $lblB)
    }
    $sorted = @($f.Points | Sort-Object Temp)
    if ($sorted.Count -eq 0) { return }
    $pc = New-Object System.Windows.Media.PointCollection
    $pc.Add((New-Object System.Windows.Point((CX $script:XMin), (CY $sorted[0].Pct))))
    foreach ($p in $sorted) { $pc.Add((New-Object System.Windows.Point((CX ([Math]::Max($script:XMin, [Math]::Min($script:XMax, $p.Temp)))), (CY $p.Pct)))) }
    $pc.Add((New-Object System.Windows.Point((CX $script:XMax), (CY $sorted[$sorted.Count - 1].Pct))))
    $fillPts = $pc.Clone()
    $fillPts.Add((New-Object System.Windows.Point((CX $script:XMax), (CY 0))))
    $fillPts.Add((New-Object System.Windows.Point((CX $script:XMin), (CY 0))))
    $poly = New-Object System.Windows.Shapes.Polygon
    $poly.Points = $fillPts
    $poly.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(36, 69, 211, 180))
    Add-Shape $poly
    $pl = New-Object System.Windows.Shapes.Polyline
    $pl.Points = $pc; $pl.Stroke = $Green; $pl.StrokeThickness = 2.2; $pl.StrokeLineJoin = 'Round'
    Add-Shape $pl

    # live marker
    if ($f.Mode -ne 0 -and -not [double]::IsNaN($f.InputTemp)) {
        $x = CX (Clamp $f.InputTemp $script:XMin $script:XMax)
        $ml = New-Line $x (CY 100) $x (CY 0) $Yellow 1
        $ml.StrokeDashArray = [System.Windows.Media.DoubleCollection]::Parse('4 3')
        Add-Shape $ml
        if (-not [double]::IsNaN($f.CurPct)) {
            $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 9; $dot.Height = 9; $dot.Fill = $Yellow
            [System.Windows.Controls.Canvas]::SetLeft($dot, $x - 4.5); [System.Windows.Controls.Canvas]::SetTop($dot, (CY $f.CurPct) - 4.5)
            Add-Shape $dot
        }
    }

    foreach ($p in $f.Points) {
        $e = New-Object System.Windows.Shapes.Ellipse
        $e.Width = 13; $e.Height = 13; $e.Fill = Brush '#0E1012'; $e.Stroke = $Green; $e.StrokeThickness = 2.5; $e.Cursor = 'SizeAll'
        $e.Tag = $p
        $e.ToolTip = "$($p.Temp) °C → $($p.Pct) %"
        [System.Windows.Controls.Canvas]::SetLeft($e, (CX ([Math]::Max($script:XMin, [Math]::Min($script:XMax, $p.Temp)))) - 6.5)
        [System.Windows.Controls.Canvas]::SetTop($e, (CY $p.Pct) - 6.5)
        $e.Add_MouseLeftButtonDown({ param($sender, $ev)
            if ($script:SelFan.Mode -ne 1) { return }
            $script:Drag = $sender.Tag
            [void]$ui.CurveCanvas.CaptureMouse()
            $ui.GridPoints.SelectedItem = $sender.Tag
            $ev.Handled = $true
        })
        $e.Add_MouseRightButtonDown({ param($sender, $ev)
            $ff = $script:SelFan
            if ($ff.Points.Count -gt 1 -and -not $script:Cfg.cfcGrid) { [void]$ff.Points.Remove($sender.Tag); $script:Dirty = $true; Draw-Curve }
            $ev.Handled = $true
        })
        Add-Shape $e
    }
}

$ui.CurveCanvas.Add_SizeChanged({ Draw-Curve })
$ui.CurveCanvas.Add_MouseMove({ param($sender, $ev)
    if (-not $script:Drag) { return }
    $pos = $ev.GetPosition($ui.CurveCanvas)
    if (-not $script:Cfg.cfcGrid) { $script:Drag.Temp = [int][Math]::Round((Clamp (InvX $pos.X) $script:XMin ([Math]::Min(105, $script:XMax + 5)))) }
    $script:Drag.Pct  = [int][Math]::Round((Clamp (InvY $pos.Y) 0 100))
    Draw-Curve
})
$ui.CurveCanvas.Add_MouseLeftButtonUp({
    if ($script:Drag) {
        $script:Drag = $null
        $ui.CurveCanvas.ReleaseMouseCapture()
        Sort-Points $script:SelFan
        $script:Dirty = $true
        Draw-Curve
    }
})
$ui.CurveCanvas.Add_MouseLeftButtonDown({ param($sender, $ev)
    if ($ev.ClickCount -ne 2 -or -not $script:SelFan -or $script:SelFan.Mode -ne 1 -or $script:Cfg.cfcGrid) { return }
    $pos = $ev.GetPosition($ui.CurveCanvas)
    $t = [int][Math]::Round((Clamp (InvX $pos.X) $script:XMin ([Math]::Min(105, $script:XMax + 5)))); $p = [int][Math]::Round((Clamp (InvY $pos.Y) 0 100))
    $script:SelFan.Points.Add((New-Object ClevoTune.CurvePoint($t, $p)))
    Sort-Points $script:SelFan
    $script:Dirty = $true
    Draw-Curve
})

function Update-FanUi {
    $hw = $script:Hw
    foreach ($k in @($script:FanItems.Keys)) {
        $f = $hw.Fans[$k - 1]
        $duty = Fmt $f.DutyPct '0'
        $script:FanItems[$k].Sub.Text = "$(Mode-Name $f.Mode) · $($f.Rpm) RPM · $duty %"
    }
    $f = $script:SelFan
    if ($f -and $hw.Ec) {
        if ($f.Mode -eq 0) { $ui.TxtFanLive.Text = ((T 'EC automatic · {0} RPM · {1} %') -f $f.Rpm, (Fmt $f.DutyPct '0')) }
        else {
            $src = T (@('CPU', 'GPU', 'max', 'CPU load', 'GPU load', 'max load')[$f.Source])
            $u = $(if ($f.IsLoad) { '%' } else { '°C' })
            $ui.TxtFanLive.Text = "$src $(Fmt $f.InputTemp '0') $u → $(Fmt $f.CurPct '0') % · $($f.Rpm) RPM"
            if ($hw.FailsafeActive) { $ui.TxtFanLive.Text += '  · ' + (T 'SAFETY') }
        }
    } else { $ui.TxtFanLive.Text = '' }
    # detect table edits
    if ($f) {
        $sig = ($f.Points | ForEach-Object { "$($_.Temp):$($_.Pct)" }) -join ','
        if ($sig -ne $script:PtSig) { if ($script:PtSig) { $script:Dirty = $true }; $script:PtSig = $sig }
    }
    if ($ui.Tabs.SelectedIndex -eq 1 -and -not $script:Drag) { Draw-Curve }
}

$ui.SlHyst.Add_ValueChanged({ $ui.ValHyst.Text = ('{0:0}' -f $ui.SlHyst.Value); if ($script:Loading) { return }; $script:Hw.Hysteresis = $ui.SlHyst.Value; $script:Cfg.hyst = [int]$ui.SlHyst.Value; $script:Dirty = $true })
$ui.SlDown.Add_ValueChanged({ $ui.ValDown.Text = ('{0:0} %/s' -f $ui.SlDown.Value); if ($script:Loading) { return }; $script:Hw.DownRate = $ui.SlDown.Value; $script:Cfg.down = [int]$ui.SlDown.Value; $script:Dirty = $true })
$ui.SlLoadSm.Add_ValueChanged({ $ui.ValLoadSm.Text = ('{0:0} s' -f $ui.SlLoadSm.Value); if ($script:Loading) { return }; $script:Hw.LoadSmoothSec = $ui.SlLoadSm.Value; $script:Cfg.loadSmooth = [int]$ui.SlLoadSm.Value; $script:Dirty = $true })
$ui.SlFail.Add_ValueChanged({ $ui.ValFail.Text = ('{0:0} °C' -f $ui.SlFail.Value); if ($script:Loading) { return }; $script:Hw.FailsafeTemp = $ui.SlFail.Value; $script:Cfg.failsafe = [int]$ui.SlFail.Value; $script:Dirty = $true })
function Set-AllAuto {
    foreach ($f in $script:Hw.Fans) { $f.Mode = 0 }
    $script:Hw.ReleaseAll()
    if ($script:SelFan) { Select-Fan $script:SelFan }
    $script:Dirty = $true
    Log (T 'All fans returned to the EC (auto)')
    Set-Status (T 'Fans in EC automatic mode') $Green
}
$ui.BtnAllAuto.Add_Click({ Set-AllAuto })


# ---------------------------------------------------------------- ClevoFanControl format (userfancurve.cfg)
# 20 lines: CPU fan % at 40,45,...,85 °C, then GPU fan % at the same temperatures
$CfcTemps = @(40, 45, 50, 55, 60, 65, 70, 75, 80, 85)

function Get-CfcDefaultPath {
    try {
        $probe = Join-Path $SelfDir '.write-test'
        [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
        return (Join-Path $SelfDir 'userfancurve.cfg')
    } catch { return (Join-Path $DataDir 'userfancurve.cfg') }
}

function Set-GridPoints($f, $vals) {
    $f.Points.Clear()
    for ($i = 0; $i -lt 10; $i++) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$CfcTemps[$i], [int]$vals[$i]))) }
    $f.EffTemp = [double]::NaN
}

function Get-GridValues($f) {
    $v = @()
    foreach ($t in $CfcTemps) {
        $x = [ClevoTune.Hw]::Interp($f.Points, [double]$t)
        if ([double]::IsNaN($x)) { $x = 100 }
        $v += [int][Math]::Round($x)
    }
    return , $v
}

function Test-OnGrid($f) {
    if ($f.Points.Count -ne 10) { return $false }
    $temps = @($f.Points | Sort-Object Temp | ForEach-Object { $_.Temp })
    for ($i = 0; $i -lt 10; $i++) { if ($temps[$i] -ne $CfcTemps[$i]) { return $false } }
    return $true
}

function Read-CfcFile([string]$path) {
    $nums = @()
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        $l = $line.Trim()
        if (-not $l) { continue }
        $n = 0
        if (-not [int]::TryParse($l, [ref]$n)) { throw ((T "invalid line: '{0}'") -f $l) }
        $nums += [Math]::Max(0, [Math]::Min(100, $n))
    }
    if ($nums.Count -lt 10) { throw ((T 'expected 20 values (10 CPU + 10 GPU), found {0}') -f $nums.Count) }
    return , $nums
}

function Import-Cfc([string]$path, [bool]$quiet) {
    $nums = Read-CfcFile $path
    $hw = $script:Hw
    if ($nums.Count -ge 20) {
        Set-GridPoints $hw.Fans[0] $nums[0..9]
        Set-GridPoints $hw.Fans[1] $nums[10..19]
        foreach ($i in 0, 1) { $hw.Fans[$i].Mode = 1; $hw.Fans[$i].Source = $i }
        Log ((T 'Curves imported from {0}: CPU {1} | GPU {2}') -f (Split-Path -Leaf $path), ($nums[0..9] -join ' '), ($nums[10..19] -join ' '))
    } else {
        $f = $script:SelFan; if (-not $f) { $f = $hw.Fans[0] }
        Set-GridPoints $f $nums[0..9]
        $f.Mode = 1
        Log ((T 'Curve imported from {0} to fan {1}: {2}') -f (Split-Path -Leaf $path), $f.Name, ($nums[0..9] -join ' '))
    }
    $script:Cfg.cfcGrid = $true
    $script:Dirty = $true
    if (-not $quiet) {
        Save-Config
        $ui.ChkCfcGrid.IsChecked = $true
        if ($script:SelFan) { Select-Fan $script:SelFan }
        Set-Status (T 'Curves imported and active (Curve mode)') $Green
    }
}

function Export-Cfc([string]$path) {
    $hw = $script:Hw
    $lines = @()
    $lossy = $false
    foreach ($i in 0, 1) {
        if (-not (Test-OnGrid $hw.Fans[$i])) { $lossy = $true }
        $lines += (Get-GridValues $hw.Fans[$i])
    }
    [IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), (New-Object Text.ASCIIEncoding))
    $msg = (T 'Curves exported to {0}') -f $path
    if ($lossy) { $msg += ' ' + (T '(points outside the 40–85 °C grid converted by interpolation)') }
    Log $msg
}

function Set-CfcGrid([bool]$on) {
    $script:Cfg.cfcGrid = $on
    if ($on) {
        foreach ($f in $script:Hw.Fans) { if (-not (Test-OnGrid $f)) { Set-GridPoints $f (Get-GridValues $f) } }
    }
    $script:Dirty = $true
    Update-GridLock
    Draw-Curve
}

function Update-GridLock {
    $g = [bool]$script:Cfg.cfcGrid
    try { $ui.GridPoints.Columns[0].IsReadOnly = $g } catch { }
    $ed = [bool]$script:Hw.Ec
    $ui.BtnAddPt.IsEnabled = $ed -and -not $g
    $ui.BtnDelPt.IsEnabled = $ed -and -not $g
    if ($g) { $ui.TxtCurveHelp.Text = T 'Fixed grid: 10 points at 40, 45 … 85 °C, as in ClevoFanControl. Edit only the % in the table or drag the points vertically. Below 40 °C the 1st value is used, above 85 °C the last.' }
    else { $ui.TxtCurveHelp.Text = T 'Drag the points on the chart or type the values in the table. Double-click the chart to add a point; right-click a point to remove it.' }
}

$ui.ChkCfcGrid.Add_Click({ Set-CfcGrid ([bool]$ui.ChkCfcGrid.IsChecked) })
$ui.BtnImportCfc.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = (T 'ClevoFanControl curves (*.cfg)|*.cfg|All files (*.*)|*.*')
    $dlg.InitialDirectory = $SelfDir
    $dlg.FileName = 'userfancurve.cfg'
    if ($dlg.ShowDialog($win)) {
        try { Import-Cfc $dlg.FileName $false }
        catch { Log ((T 'Import failed: {0}') -f $_.Exception.Message); Set-Status (T 'Invalid curve file — see log') $Red }
    }
})
$ui.BtnExportCfc.Add_Click({
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = (T 'ClevoFanControl curves (*.cfg)|*.cfg|All files (*.*)|*.*')
    $dlg.InitialDirectory = $SelfDir
    $dlg.FileName = 'userfancurve.cfg'
    if ($dlg.ShowDialog($win)) {
        try { Export-Cfc $dlg.FileName; Set-Status ((T 'Exported: {0}') -f $dlg.FileName) $Green }
        catch { Log ((T 'Export failed: {0}') -f $_.Exception.Message); Set-Status (T 'Export failed — see log') $Red }
    }
})
$ui.BtnSaveCurves.Add_Click({
    try {
        Save-Config
        $p = Get-CfcDefaultPath
        Export-Cfc $p
        Set-Status ((T 'Curves saved (settings + {0})') -f (Split-Path -Leaf $p)) $Green
    } catch { Log ((T 'Save failed: {0}') -f $_.Exception.Message); Set-Status (T 'Save failed — see log') $Red }
})

# ---------------------------------------------------------------- overlay
$ovl = New-Object System.Windows.Window
$ovl.WindowStyle = 'None'; $ovl.AllowsTransparency = $true; $ovl.Background = [System.Windows.Media.Brushes]::Transparent
$ovl.Topmost = $true; $ovl.ShowInTaskbar = $false; $ovl.SizeToContent = 'WidthAndHeight'; $ovl.ShowActivated = $false
$ovl.ResizeMode = 'NoResize'; $ovl.Focusable = $false; $ovl.Title = 'ClevoTune overlay'
$ovlBorder = New-Object System.Windows.Controls.Border
$ovlBorder.CornerRadius = New-Object System.Windows.CornerRadius 6
$ovlBorder.Padding = Thick 10 6 10 6
$ovlText = New-Object System.Windows.Controls.TextBlock
$ovlText.FontFamily = New-Object System.Windows.Media.FontFamily 'Consolas'
$ovlText.Foreground = [System.Windows.Media.Brushes]::White
$fx = New-Object System.Windows.Media.Effects.DropShadowEffect; $fx.ShadowDepth = 1; $fx.BlurRadius = 3; $fx.Opacity = 0.9
$ovlText.Effect = $fx
$ovlBorder.Child = $ovlText
$ovl.Content = $ovlBorder
$ovl.Add_SourceInitialized({ [ClevoTune.Win]::ClickThrough((New-Object System.Windows.Interop.WindowInteropHelper($ovl)).Handle) })
function Get-OverlayWorkArea {
    $screens = @([Windows.Forms.Screen]::AllScreens)
    $screen = @($screens | Where-Object { $_.DeviceName -eq [string]$script:Cfg.overlay.monitor } | Select-Object -First 1)
    if ($screen.Count) { $screen = $screen[0] } else { $screen = [Windows.Forms.Screen]::PrimaryScreen }
    $bounds = $screen.WorkingArea
    # Screen bounds are device pixels; WPF window coordinates are logical units.
    $source = [Windows.PresentationSource]::FromVisual($ovl)
    $matrix = [Windows.Media.Matrix]::Identity
    if ($source -and $source.CompositionTarget) { $matrix = $source.CompositionTarget.TransformFromDevice }
    $origin = $matrix.Transform((New-Object Windows.Point $bounds.Left, $bounds.Top))
    $size = $matrix.Transform((New-Object Windows.Vector $bounds.Width, $bounds.Height))
    return [pscustomobject]@{ Left=$origin.X; Top=$origin.Y; Width=$size.X; Height=$size.Y; Right=$origin.X+$size.X; Bottom=$origin.Y+$size.Y }
}
function Refresh-OverlayMonitors {
    $wasLoading = $script:Loading; $script:Loading = $true
    try {
        $ui.CmbOvlMonitor.Items.Clear()
        $default = New-Object Windows.Controls.ComboBoxItem
        $default.Content = (T 'Primary display'); $default.Tag = ''
        [void]$ui.CmbOvlMonitor.Items.Add($default)
        $selected = 0; $i = 0
        foreach ($screen in [Windows.Forms.Screen]::AllScreens) {
            $i++
            $item = New-Object Windows.Controls.ComboBoxItem
            $item.Tag = $screen.DeviceName
            $item.Content = ((T 'Display {0}') -f $i) + ' (' + $screen.Bounds.Width + ' × ' + $screen.Bounds.Height + ')'
            [void]$ui.CmbOvlMonitor.Items.Add($item)
            if ($screen.DeviceName -eq [string]$script:Cfg.overlay.monitor) { $selected = $i }
        }
        $ui.CmbOvlMonitor.SelectedIndex = $selected
    } finally { $script:Loading = $wasLoading }
}
function Position-Overlay {
    $wa = Get-OverlayWorkArea
    $m = 12
    $pos = [int]$script:Cfg.overlay.pos
    if ($pos -ge 4 -and $pos -le 6) {
        $ovl.Left = $wa.Left + ($wa.Width - $ovl.ActualWidth) / 2
        if ($pos -eq 5) { $ovl.Top = $wa.Top + $m }
        elseif ($pos -eq 6) { $ovl.Top = $wa.Bottom - $ovl.ActualHeight - $m }
        else { $ovl.Top = $wa.Top + ($wa.Height - $ovl.ActualHeight) / 2 }
        return
    }
    if ($pos -eq 0 -or $pos -eq 2) { $ovl.Left = $wa.Left + $m } else { $ovl.Left = $wa.Right - $ovl.ActualWidth - $m }
    if ($pos -lt 2) { $ovl.Top = $wa.Top + $m } else { $ovl.Top = $wa.Bottom - $ovl.ActualHeight - $m }
}
$ovl.Add_SizeChanged({ Position-Overlay })
function Apply-OverlayStyle {
    $o = $script:Cfg.overlay
    $ovlText.FontSize = [double]$o.font
    $a = [byte][Math]::Round(255 * [double]$o.opacity / 100)
    $ovlBorder.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb($a, 0, 0, 0))
    if ($o.enabled) { if (-not $ovl.IsVisible) { $ovl.Show() }; Position-Overlay } else { if ($ovl.IsVisible) { $ovl.Hide() } }
}
$script:OvlTick = 0
function Update-Overlay {
    $o = $script:Cfg.overlay
    if (-not $o.enabled) { return }
    $hw = $script:Hw
    $l = @()
    if ($o.cpu) { $l += ('CPU  {0,3}°C {1,4}% {2,4}W' -f (Fmt $hw.CpuTemp '0'), (Fmt $hw.CpuLoad '0'), (Fmt $hw.CpuPower '0')) }
    if ($o.gpu) { $l += ('GPU  {0,3}°C {1,4}% {2,4}W' -f (Fmt $hw.GpuTemp '0'), (Fmt $hw.GpuLoad '0'), (Fmt $hw.GpuPower '0')) }
    if ($o.clk) { $l += ('CLK  {0} / {1} MHz' -f (Fmt $hw.GpuClock '0'), (Fmt $hw.MemClock '0')) }
    if ($o.fan -and $hw.Ec) {
        $fs = @(); foreach ($f in $hw.Fans) { if ($f.Present) { $fs += ('{0} {1}%' -f $f.Name, (Fmt $f.DutyPct '0')) } }
        $l += 'FAN  ' + ($fs -join '  ')
    }
    if ($o.mem) { $l += ('MEM  RAM {0}/{1}  VRAM {2}/{3} GB' -f (Fmt $hw.RamUsed '0.0'), (Fmt $hw.RamTotal '0'), (Fmt $hw.VramUsed '0.0'), (Fmt $hw.VramTotal '0')) }
    $ovlText.Text = ($l -join "`n")
    Position-Overlay
    $script:OvlTick++
    if ($script:OvlTick % 5 -eq 0) { $ovl.Topmost = $false; $ovl.Topmost = $true }
}
function Save-OverlayUi {
    if ($script:Loading) { return }
    $o = $script:Cfg.overlay
    $o.enabled = [bool]$ui.ChkOverlay.IsChecked
    $o.pos = [Math]::Max(0, $ui.CmbOvlPos.SelectedIndex)
    # Only an explicit monitor selection replaces a missing/disconnected saved display.
    if ($script:MonitorSelectionChanged -and $ui.CmbOvlMonitor.SelectedItem) { $o.monitor = [string]$ui.CmbOvlMonitor.SelectedItem.Tag }
    $o.font = [int]$ui.SlOvlFont.Value; $o.opacity = [int]$ui.SlOvlOp.Value
    $o.cpu = [bool]$ui.OvlCpu.IsChecked; $o.gpu = [bool]$ui.OvlGpu.IsChecked; $o.clk = [bool]$ui.OvlClk.IsChecked
    $o.fan = [bool]$ui.OvlFan.IsChecked; $o.mem = [bool]$ui.OvlMem.IsChecked
    $script:Dirty = $true
    Apply-OverlayStyle
    Update-Overlay
}
foreach ($n in 'ChkOverlay', 'OvlCpu', 'OvlGpu', 'OvlClk', 'OvlFan', 'OvlMem') { $ui[$n].Add_Click({ Save-OverlayUi }) }
$ui.CmbOvlPos.Add_SelectionChanged({ Save-OverlayUi })
$ui.CmbOvlMonitor.Add_DropDownOpened({ Refresh-OverlayMonitors })
$ui.CmbOvlMonitor.Add_SelectionChanged({
    $script:MonitorSelectionChanged = $true
    try { Save-OverlayUi } finally { $script:MonitorSelectionChanged = $false }
})
$ui.SlOvlFont.Add_ValueChanged({ $ui.ValOvlFont.Text = ('{0:0}' -f $ui.SlOvlFont.Value); Save-OverlayUi })
$ui.SlOvlOp.Add_ValueChanged({ $ui.ValOvlOp.Text = ('{0:0} %' -f $ui.SlOvlOp.Value); Save-OverlayUi })

# ---------------------------------------------------------------- settings tab
$ui.BtnPawnSite.Add_Click({ Start-Process 'https://pawnio.eu' })
$ui.BtnLangFolder.Add_Click({
    $d = $script:LangDir; if (-not $d) { $d = Get-LangDir }
    Start-Process explorer.exe -ArgumentList "`"$d`""
})
$ui.BtnModFolder.Add_Click({
    if (-not (Test-Path -LiteralPath $ModDir)) { New-Item -ItemType Directory -Path $ModDir -Force | Out-Null }
    Start-Process explorer.exe -ArgumentList "`"$ModDir`""
})
function Reinit-Hw {
    try {
        $script:Timer.Stop()
        try { $script:Hw.Dispose() } catch { }
        $script:Hw = New-HwInstance
        $script:Hw.Tick(1.0)
        Invalidate-TuningReadback
        Update-Header
        Init-Tuning
        Build-FanList
        Log (T 'Sensors reinitialised')
        Set-Status (T 'Sensors reinitialised') $Green
    } catch { Log ((T 'Reinitialisation error: {0}') -f $_.Exception.Message) }
    finally { $script:Timer.Start() }
}
$ui.BtnReinit.Add_Click({ Reinit-Hw })
function Update-MVoltUi {
    if ($script:MVolt) {
        $v = Get-LocalMVoltVersion $script:MVolt
        $ui.TxtMVolt.Text = ((T 'mVolt+ {0} — {1}') -f $(if ($v) { $v } else { '?' }), $script:MVolt); $ui.TxtMVolt.Foreground = $Green
    }
    else { $ui.TxtMVolt.Text = (T 'mVolt+ not found. It is used for power limits and voltage offsets that the NVIDIA driver blocks on this GPU.'); $ui.TxtMVolt.Foreground = $Yellow }
}
$ui.BtnMVoltSite.Add_Click({ Start-Process 'https://github.com/b00nz/mVolt' })
$ui.BtnMVoltUpdate.Add_Click({ Invoke-UiOperation {
    $win.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        Set-Status (T 'Checking mVolt+ updates…') $Yellow
        Pump-Ui
        Update-MVolt $true
        if ($script:Exiting) { return }
        $script:MVolt = Find-MVolt
        Save-Config
        Update-MVoltUi
        Init-Tuning
        Set-Status $ui.TxtMVolt.Text $Green
    } finally { $win.Cursor = $null }
} })
$ui.BtnModules.Add_Click({ Invoke-UiOperation {
    $win.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        Set-Status (T 'Reinstalling PawnIO driver and modules…') $Yellow
        Pump-Ui
        $script:Timer.Stop()
        try { $script:Hw.ReleaseAll(); $script:Hw.Dispose() } catch { }
        Ensure-Dependencies $true
        if ($script:Exiting) { return }
        Reinit-Hw
        if ($script:RebootNeeded) { Set-Status (T 'Installed — restart Windows to activate the driver') $Yellow }
    } catch {
        Log ((T 'Reinstall failed: {0}') -f $_.Exception.Message)
        Set-Status (T 'Reinstall failed — see log') $Red
    } finally { $win.Cursor = $null; if (-not $script:Exiting) { $script:Timer.Start() } }
} })
$ui.ChkCloseTray.Add_Click({ $script:Cfg.closeToTray = [bool]$ui.ChkCloseTray.IsChecked; $script:Dirty = $true })
$ui.CmbInterval.Add_SelectionChanged({
    if ($script:Loading) { return }
    $ms = @(500, 1000, 2000)[[Math]::Max(0, $ui.CmbInterval.SelectedIndex)]
    $script:Cfg.interval = $ms; $script:Timer.Interval = [TimeSpan]::FromMilliseconds($ms); $script:Dirty = $true
})

function Refresh-Language {
    Apply-LangTargets
    Refresh-OverlayMonitors
    # closed ComboBoxes cache the selected text: reselect so it shows the new language
    $script:Loading = $true
    foreach ($n in 'CmbFanMode', 'CmbFanSource', 'CmbPreset', 'CmbOvlPos', 'CmbInterval') {
        $cb = $ui[$n]; $i = $cb.SelectedIndex
        if ($i -ge 0) { $cb.SelectedIndex = -1; $cb.SelectedIndex = $i }
    }
    $ui.CmbLang.Items[0].Content = (T 'Automatic (system)')
    $i = $ui.CmbLang.SelectedIndex; $ui.CmbLang.SelectedIndex = -1; $ui.CmbLang.SelectedIndex = $i
    $script:Loading = $false
    foreach ($c in $script:Cards.Values) { $c.Title.Text = (T $c.TitleKey) }
    if ($ui.LogPanel.Visibility -eq 'Visible') { $ui.BtnLog.Content = (T 'Log ▾') } else { $ui.BtnLog.Content = (T 'Log ▴') }
    Update-Header
    Update-TuneTexts
    Update-Readback
    Update-MVoltUi
    Fill-Profiles
    Build-FanList
    Update-GridLock
    Update-AxisUi
    Draw-Curve
}
$ui.CmbLang.Add_SelectionChanged({
    if ($script:Loading -or $ui.CmbLang.SelectedIndex -lt 0) { return }
    $i = $ui.CmbLang.SelectedIndex
    if ($i -eq 0) { $script:Cfg.lang = 'auto' } else { $script:Cfg.lang = $script:Langs[$i - 1].Code }
    Set-Lang (Resolve-Lang ([string]$script:Cfg.lang))
    Save-Config
    Refresh-Language
    Log ((T 'Language changed: {0}') -f (Find-Lang $script:Lang).Name)
})

# ---------------------------------------------------------------- log toggle
$ui.BtnLog.Add_Click({
    if ($ui.LogPanel.Visibility -eq 'Visible') { $ui.LogPanel.Visibility = 'Collapsed'; $ui.BtnLog.Content = (T 'Log ▴') }
    else { $ui.LogPanel.Visibility = 'Visible'; $ui.BtnLog.Content = (T 'Log ▾'); $ui.TxtLog.ScrollToEnd() }
})

# ---------------------------------------------------------------- tray
$script:Tray = New-Object System.Windows.Forms.NotifyIcon
$script:Tray.Icon = $AppIcon
$script:Tray.Text = 'ClevoTune'
$script:Tray.Visible = $true
$script:TrayHinted = $false

function Show-Main {
    $win.Show()
    if ($win.WindowState -eq 'Minimized') { $win.WindowState = 'Normal' }
    [void]$win.Activate()
    $win.Topmost = $true; $win.Topmost = $false
}
function Build-TrayMenu {
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $i = $menu.Items.Add((T 'Open ClevoTune')); $i.Font = New-Object System.Drawing.Font($i.Font, [System.Drawing.FontStyle]::Bold)
    $i.Add_Click({ Show-Main })
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    foreach ($p in $script:Cfg.profiles) {
        $it = $menu.Items.Add(((T 'Apply profile: {0}') -f $p.name))
        $it.Tag = [string]$p.name
        $it.Add_Click({ param($sender, $e)
            $pp = Get-Profile ([string]$sender.Tag)
            if ($pp -and -not $script:OperationBusy) { Load-ProfileToSliders $pp; Apply-Tuning ([int]$pp.power) ([int]$pp.core) ([int]$pp.mem) ([int]$pp.lock) ((T "Profile '{0}':") -f $pp.name) ([int]$pp.volt) }
        })
    }
    foreach ($fi in @(@(1, 'Load CPU curve from profile'), @(2, 'Load GPU curve from profile'))) {
        $sub = New-Object System.Windows.Forms.ToolStripMenuItem((T $fi[1]))
        foreach ($p in $script:Cfg.profiles) {
            if (-not ($p.PSObject.Properties.Name -contains 'fans') -or @($p.fans).Count -eq 0) { continue }
            $si = $sub.DropDownItems.Add([string]$p.name)
            $si.Tag = "$($fi[0])|$($p.name)"
            $si.Add_Click({ param($sender, $e)
                $parts = ([string]$sender.Tag).Split('|', 2)
                $pp = Get-Profile $parts[1]
                if ($pp -and (Load-ProfileFans $pp ([int]$parts[0]))) { Set-Status ((T "Fan curve loaded from profile '{0}'") -f $pp.name) $Green }
            })
        }
        if ($sub.DropDownItems.Count -eq 0) { $sub.Enabled = $false }
        [void]$menu.Items.Add($sub)
    }
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $a = $menu.Items.Add((T 'Fans → automatic (EC)')); $a.Add_Click({ Set-AllAuto })
    $sw = New-Object System.Windows.Forms.ToolStripMenuItem((T 'Start with Windows'))
    $sw.Checked = [bool]$script:Cfg.autoApply
    $sw.Add_Click({ Set-StartWithWindows (-not [bool]$script:Cfg.autoApply) })
    [void]$menu.Items.Add($sw)
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $q = $menu.Items.Add((T 'Exit (returns fans to the EC)')); $q.Add_Click({ Exit-App })
    $old = $script:Tray.ContextMenuStrip
    $script:Tray.ContextMenuStrip = $menu
    if ($old) { $old.Dispose() }
}
$script:Tray.Add_MouseDoubleClick({ Show-Main })
$script:Tray.Add_MouseClick({ param($sender, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-Main } })

# ---------------------------------------------------------------- window chrome
$ui.BtnMin.Add_Click({ $win.WindowState = 'Minimized' })
$ui.BtnMax.Add_Click({ if ($win.WindowState -eq 'Maximized') { $win.WindowState = 'Normal' } else { $win.WindowState = 'Maximized' } })
$win.Add_StateChanged({
    if ($win.WindowState -eq 'Maximized') { $win.Content.Margin = Thick 7 7 7 7 } else { $win.Content.Margin = Thick 0 0 0 0 }
})
$ui.BtnClose.Add_Click({ $win.Close() })
$script:Exiting = $false
$win.Add_Closing({ param($sender, $e)
    if ($script:Exiting) { return }
    $e.Cancel = $true
    if ($script:Cfg.closeToTray) {
        $win.Hide()
        if (-not $script:TrayHinted) {
            $script:TrayHinted = $true
            $script:Tray.ShowBalloonTip(3000, 'ClevoTune', (T 'Still running in the tray controlling the fans. Right-click → Exit to close.'), [System.Windows.Forms.ToolTipIcon]::Info)
        }
    } else { Exit-App }
})

function Exit-App {
    if ($script:Exiting) { return }
    $script:Exiting = $true
    try { $script:Timer.Stop() } catch { }
    try { $script:Hw.ReleaseAll(); Log (T 'Fans returned to the EC') } catch { }
    Save-Config
    try { $script:Tray.Visible = $false; $script:Tray.Dispose() } catch { }
    try { $ovl.Close() } catch { }
    try { $win.Close() } catch { }
    try { $script:Hw.Dispose() } catch { }
    $app.Shutdown()
}

$app.Add_SessionEnding({ $script:Exiting = $true; $script:Timer.Stop(); try { $script:Hw.ReleaseAll() } catch { }; Save-Config })
$app.Add_DispatcherUnhandledException({ param($sender, $e) Log ((T 'Unexpected error: {0}') -f $e.Exception.Message); $e.Handled = $true })

# ---------------------------------------------------------------- timer loop
$script:SeenReinits = 0
$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds([int]$script:Cfg.interval)
$script:Watch = [System.Diagnostics.Stopwatch]::StartNew()
$script:Timer.Add_Tick({
    try {
        $dt = $script:Watch.Elapsed.TotalSeconds; $script:Watch.Restart()
        if ($dt -gt 10) { $dt = 1 }
        $script:Hw.Tick($dt)
        foreach ($m in $script:Hw.TakeMessages()) { Log $m }
        if ($script:Hw.NvmlReinits -ne $script:SeenReinits) { $script:SeenReinits = $script:Hw.NvmlReinits; Invalidate-TuningReadback; if ($script:Hw.NvmlOk) { Update-Header; Init-Tuning } }
        Update-Cards
        if ($win.IsVisible) {
            Update-FanUi
            if ($ui.Tabs.SelectedIndex -eq 0 -and -not $ui.SlPower.IsEnabled) { Update-TuneTexts }
        }
        Update-Overlay
        $tip = 'ClevoTune · CPU ' + (Fmt $script:Hw.CpuTemp '0') + '°C · GPU ' + (Fmt $script:Hw.GpuTemp '0') + '°C'
        if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 63) }
        $script:Tray.Text = $tip
        if ($script:ShowEvent.WaitOne(0)) { Show-Main }
        if ($script:Dirty -and ((Get-Date) - $script:LastSave).TotalSeconds -ge 2) { Save-Config }
    } catch { Log "Tick: $($_.Exception.Message)" }
})

# ---------------------------------------------------------------- startup
$ErrorActionPreference = 'Continue'
try { $script:Hw.Tick(1.0) } catch { }
Update-Header
Init-Tuning
Fill-Profiles

$script:Loading = $true
$ui.SlHyst.Value = [double]$script:Cfg.hyst; $ui.ValHyst.Text = ('{0:0}' -f $ui.SlHyst.Value)
$ui.SlDown.Value = [double]$script:Cfg.down; $ui.ValDown.Text = ('{0:0} %/s' -f $ui.SlDown.Value)
$ui.SlLoadSm.Value = [double]$script:Cfg.loadSmooth; $ui.ValLoadSm.Text = ('{0:0} s' -f $ui.SlLoadSm.Value)
$ui.SlFail.Value = [double]$script:Cfg.failsafe; $ui.ValFail.Text = ('{0:0} °C' -f $ui.SlFail.Value)
$ui.ChkCfcGrid.IsChecked = [bool]$script:Cfg.cfcGrid
$ui.CmbLang.Items.Clear()
[void]$ui.CmbLang.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = (T 'Automatic (system)') }))
foreach ($l in $script:Langs) { [void]$ui.CmbLang.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $l.Name })) }
$li = 0
if ([string]$script:Cfg.lang -and [string]$script:Cfg.lang -ne 'auto') {
    $fl = Find-Lang ([string]$script:Cfg.lang)
    if ($fl) { $li = $script:Langs.IndexOf($fl) + 1 }
}
$ui.CmbLang.SelectedIndex = [Math]::Max(0, $li)
$ui.BtnLog.Content = (T 'Log ▴')
$ui.ChkCloseTray.IsChecked = [bool]$script:Cfg.closeToTray
$ui.CmbInterval.SelectedIndex = [Math]::Max(0, [array]::IndexOf([int[]]@(500, 1000, 2000), [int]$script:Cfg.interval))
$o = $script:Cfg.overlay
$ui.ChkOverlay.IsChecked = [bool]$o.enabled; $ui.CmbOvlPos.SelectedIndex = [int]$o.pos
Refresh-OverlayMonitors
$ui.SlOvlFont.Value = [double]$o.font; $ui.ValOvlFont.Text = ('{0:0}' -f $ui.SlOvlFont.Value)
$ui.SlOvlOp.Value = [double]$o.opacity; $ui.ValOvlOp.Text = ('{0:0} %' -f $ui.SlOvlOp.Value)
$ui.OvlCpu.IsChecked = [bool]$o.cpu; $ui.OvlGpu.IsChecked = [bool]$o.gpu; $ui.OvlClk.IsChecked = [bool]$o.clk; $ui.OvlFan.IsChecked = [bool]$o.fan; $ui.OvlMem.IsChecked = [bool]$o.mem
$script:Loading = $false

# Refresh the action to this version's path whenever startup is enabled.
if ($script:Cfg.autoApply) {
    try { Set-AutoStart $true } catch { Log ((T 'Scheduled task failed: {0}') -f $_.Exception.Message) }
}
$script:Cfg.autoApply = Test-AutoStart
Save-Config
$ui.ChkAutoApply.IsChecked = [bool]$script:Cfg.autoApply
$ui.ChkStartup.IsChecked = [bool]$script:Cfg.autoApply
Build-TrayMenu
$ui.ChkApplyOnOpen.IsChecked = [bool]$script:Cfg.applyOnOpen
Update-AutoChip
if ($script:FirstRun -and $script:Hw.Ec) {
    foreach ($cand in (Join-Path $SelfDir 'userfancurve.cfg'), (Join-Path $DataDir 'userfancurve.cfg')) {
        if (Test-Path -LiteralPath $cand) {
            try { Import-Cfc $cand $true; $ui.ChkCfcGrid.IsChecked = $true; Save-Config } catch { Log ((T 'userfancurve.cfg ignored: {0}') -f $_.Exception.Message) }
            break
        }
    }
}
Build-FanList
Apply-OverlayStyle

Log "ClevoTune $AppVersion · $Model · $CpuName · $($script:Hw.GpuName) · driver $($script:Hw.Driver)"
Update-MVoltUi
if ($script:MVolt) { Log ((T 'mVolt+ found: {0}') -f $script:MVolt) }
if (-not $IsAdmin) { Log (T 'Warning: no administrator rights — PawnIO and GPU changes will fail.') }
if ($script:RebootNeeded -and -not $script:Hw.Ec) { Set-Status (T 'PawnIO installed — restart Windows to enable the fans and CPU sensors') $Yellow }
if (-not $script:Hw.Ec) { Log ((T 'Fans: {0}') -f (T $script:Hw.EcError)) }
if (-not $script:Hw.Msr) { Log ("CPU (MSR): " + (T $script:Hw.MsrError)) }
if (-not [ClevoTune.NvApi]::Ready) { Log "NVAPI: $([ClevoTune.NvApi]::LastError)" }
if ($script:Hw.Ec) {
    $names = @(); foreach ($f in $script:Hw.Fans) { if ($f.Present) { $names += "$($f.Index):$($f.Name)" } }
    Log ((T 'Fans detected: {0}') -f ($names -join ', '))
    if (Get-Process -Name 'ControlCenter*', 'CCenter*', 'HotKey*' -ErrorAction SilentlyContinue) { Log (T 'Warning: Clevo Control Center is running and may override the curves.') }
}

$startProfile = $null
if (($TrayStart -and $script:Cfg.autoApply) -or $script:Cfg.applyOnOpen) { $startProfile = Get-LastProfile }
if ($startProfile) {
    $p = $startProfile
    $script:Cfg.selectedProfile = [string]$p.name
    Fill-Profiles
    Load-ProfileToSliders $p
    Apply-Tuning ([int]$p.power) ([int]$p.core) ([int]$p.mem) ([int]$p.lock) ((T "On open: profile '{0}'") -f $p.name) ([int]$p.volt)
} elseif (-not ($script:RebootNeeded -and -not $script:Hw.Ec)) {
    Set-Status (T 'Ready') $Green
}

$script:Timer.Start()
if (-not $TrayStart) { $win.Show() }
[void]$app.Run()
