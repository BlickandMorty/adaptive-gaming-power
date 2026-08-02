[CmdletBinding()]
param([string]$OutputPath = (Join-Path $env:TEMP ("game-inventory-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))))

$ErrorActionPreference = 'Stop'
$steamRoots = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($candidate in @(
    (Join-Path ${env:ProgramFiles(x86)} 'Steam'),
    (Join-Path $env:ProgramFiles 'Steam')
)) { if ($candidate -and (Test-Path -LiteralPath $candidate)) { [void]$steamRoots.Add((Resolve-Path $candidate).Path) } }

foreach ($root in @($steamRoots)) {
    $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
    if (-not (Test-Path -LiteralPath $vdf)) { continue }
    $text = Get-Content -LiteralPath $vdf -Raw
    foreach ($match in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
        $path = $match.Groups[1].Value -replace '\\\\', '\'
        if (Test-Path -LiteralPath $path) { [void]$steamRoots.Add((Resolve-Path $path).Path) }
    }
}

$games = foreach ($root in @($steamRoots)) {
    $steamApps = Join-Path $root 'steamapps'
    Get-ChildItem -LiteralPath $steamApps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue | ForEach-Object {
        $text = Get-Content -LiteralPath $_.FullName -Raw
        $appId = [regex]::Match($text, '"appid"\s+"(\d+)"').Groups[1].Value
        $name = [regex]::Match($text, '"name"\s+"([^"]+)"').Groups[1].Value
        $installDir = [regex]::Match($text, '"installdir"\s+"([^"]+)"').Groups[1].Value
        [pscustomobject]@{
            storefront = 'Steam'
            appId = $appId
            name = $name
            installRoot = Join-Path $steamApps "common\$installDir"
            manifest = $_.FullName
        }
    }
}
$report = [ordered]@{ generatedAt = (Get-Date).ToString('o'); steamRoots = @($steamRoots); games = @($games) }
[IO.File]::WriteAllText($OutputPath, ($report | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Host "Inventory written to $OutputPath"
$report | ConvertTo-Json -Depth 8

