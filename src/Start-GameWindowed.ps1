[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Name,
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\games.example.json')
)

$config = Get-Content -LiteralPath (Resolve-Path -LiteralPath $ConfigPath) -Raw | ConvertFrom-Json
$game = @($config.games | Where-Object { $_.name -eq $Name }) | Select-Object -First 1
if (-not $game) { throw "Configured game not found: $Name" }
$arguments = @($game.windowedArguments)
if (-not $arguments.Count) { throw 'This game has no reviewed safe-windowed arguments.' }

if ($game.steamAppId) {
    $encoded = [Uri]::EscapeDataString(($arguments -join ' '))
    $uri = "steam://run/$($game.steamAppId)//$encoded"
    if ($PSCmdlet.ShouldProcess($game.name, "Launch through $uri")) { Start-Process $uri }
} else {
    $path = [Environment]::ExpandEnvironmentVariables([string]$game.executable)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Executable missing: $path" }
    if ($PSCmdlet.ShouldProcess($game.name, "Launch $path $($arguments -join ' ')")) {
        Start-Process -FilePath $path -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $path)
    }
}

