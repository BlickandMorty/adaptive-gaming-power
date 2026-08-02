[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Auto', 'AC', 'Battery', 'Install', 'Status')][string]$Mode = 'Status',
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\games.example.json'),
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath (Resolve-Path -LiteralPath $ConfigPath) -Raw | ConvertFrom-Json
if ($config.schemaVersion -ne 1) { throw 'Unsupported configuration schema.' }
$root = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables([string]$config.installationRoot))

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PowerOnline {
    $status = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $status) { return $true }
    return [bool]$status.PowerOnline
}

function Get-ValidGameExecutables {
    @($config.games | ForEach-Object {
        $path = [Environment]::ExpandEnvironmentVariables([string]$_.executable)
        if ($path -and (Test-Path -LiteralPath $path -PathType Leaf) -and [IO.Path]::GetExtension($path) -ieq '.exe') {
            [pscustomobject]@{ name = [string]$_.name; path = (Resolve-Path -LiteralPath $path).Path; steamAppId = $_.steamAppId; windowedArguments = @($_.windowedArguments) }
        }
    })
}

function Save-TargetedBackup {
    $stateRoot = Join-Path $root 'State'
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    $gpuPath = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $gpu = @{}
    if (Test-Path $gpuPath) {
        foreach ($game in Get-ValidGameExecutables) {
            $value = (Get-ItemProperty -Path $gpuPath -Name $game.path -ErrorAction SilentlyContinue).($game.path)
            $gpu[$game.path] = $value
        }
    }
    $backup = [ordered]@{
        createdAt = (Get-Date).ToString('o')
        activeScheme = (& powercfg.exe /GetActiveScheme 2>&1 | Out-String).Trim()
        processorMaximum = (& powercfg.exe /Query SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 2>&1 | Out-String)
        processorBoost = (& powercfg.exe /Query SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2>&1 | Out-String)
        pcieSavings = (& powercfg.exe /Query SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2>&1 | Out-String)
        gpuPreferences = $gpu
    }
    [IO.File]::WriteAllText((Join-Path $stateRoot 'targeted-backup.json'), ($backup | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}

function Set-Profile {
    param([ValidateSet('AC', 'Battery')][string]$Profile)
    if (-not $Apply) { Write-Host "Preview: would apply $Profile profile."; return }
    if (-not (Test-IsAdministrator)) { throw 'Applying power settings requires elevation.' }
    Save-TargetedBackup
    if ($Profile -eq 'AC') {
        & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX ([int]$config.ac.processorMaximumPercent) | Out-Null
    } else {
        & powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX ([int]$config.battery.processorMaximumPercent) | Out-Null
        if ([bool]$config.battery.disableProcessorBoost) { & powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 0 | Out-Null }
        if ([bool]$config.battery.maximumPcieSavings) { & powercfg.exe /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2 | Out-Null }
    }
    & powercfg.exe /setactive SCHEME_CURRENT | Out-Null
    $gpuPath = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    New-Item -Path $gpuPath -Force | Out-Null
    $gpuValue = if ($Profile -eq 'AC') { 'GpuPreference=2;' } else { 'GpuPreference=1;' }
    foreach ($game in Get-ValidGameExecutables) {
        New-ItemProperty -Path $gpuPath -Name $game.path -Value $gpuValue -PropertyType String -Force | Out-Null
    }
    $stateRoot = Join-Path $root 'State'
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    $state = [ordered]@{ appliedAt = (Get-Date).ToString('o'); profile = $Profile; powerOnline = Get-PowerOnline; games = @(Get-ValidGameExecutables) }
    [IO.File]::WriteAllText((Join-Path $stateRoot 'current-state.json'), ($state | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}

function Install-Tasks {
    if (-not $Apply) { Write-Host "Preview: would install under $root"; return }
    if (-not (Test-IsAdministrator)) { throw 'Installation requires elevation.' }
    if (-not $PSCmdlet.ShouldProcess($root, 'Install adaptive gaming power task')) { return }
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $root 'GamingPower.ps1') -Force
    Copy-Item -LiteralPath (Resolve-Path -LiteralPath $ConfigPath).Path -Destination (Join-Path $root 'games.json') -Force
    $script = Join-Path $root 'GamingPower.ps1'
    $installedConfig = Join-Path $root 'games.json'
    $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Mode Auto -ConfigPath "{1}" -Apply' -f $script, $installedConfig
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-ScheduledTaskPrincipal -UserId $identity.User.Value -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -Hidden
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $identity.Name
    $repeat = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(2)) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)
    Register-ScheduledTask -TaskName "$($config.taskPrefix) Logon" -Action $action -Trigger $logon -Principal $principal -Settings $settings -Force | Out-Null
    Register-ScheduledTask -TaskName "$($config.taskPrefix) Adaptive" -Action $action -Trigger $repeat -Principal $principal -Settings $settings -Force | Out-Null
    Set-Profile -Profile $(if (Get-PowerOnline) { 'AC' } else { 'Battery' })
}

switch ($Mode) {
    'Auto' { Set-Profile -Profile $(if (Get-PowerOnline) { 'AC' } else { 'Battery' }) }
    'AC' { Set-Profile -Profile AC }
    'Battery' { Set-Profile -Profile Battery }
    'Install' { Install-Tasks }
    'Status' {
        [ordered]@{
            generatedAt = (Get-Date).ToString('o')
            powerOnline = Get-PowerOnline
            intendedProfile = if (Get-PowerOnline) { 'AC' } else { 'Battery' }
            activeScheme = (& powercfg.exe /GetActiveScheme 2>&1 | Out-String).Trim()
            configuredGames = @($config.games).Count
            existingGameExecutables = @(Get-ValidGameExecutables).Count
            installedTasks = @("$($config.taskPrefix) Logon", "$($config.taskPrefix) Adaptive") | ForEach-Object {
                $task = Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
                [pscustomobject]@{ name = $_; state = if ($task) { [string]$task.State } else { 'Missing' } }
            }
        } | ConvertTo-Json -Depth 8
    }
}

