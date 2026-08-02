$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$scripts = Get-ChildItem -LiteralPath (Join-Path $root 'src') -Filter '*.ps1' -File
foreach ($script in $scripts) {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "$($script.Name): $($errors -join '; ')" }
}
$config = Get-Content -LiteralPath (Join-Path $root 'config\games.example.json') -Raw | ConvertFrom-Json
if ([int]$config.battery.processorMaximumPercent -lt 25 -or [int]$config.battery.processorMaximumPercent -gt 100) { throw 'Battery CPU cap must be between 25 and 100.' }
if ([int]$config.ac.processorMaximumPercent -ne 100) { throw 'Example AC CPU maximum must remain 100.' }
Write-Host "Static checks passed for $($scripts.Count) scripts."

