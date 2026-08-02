[CmdletBinding()]
param([string]$ConfigPath = (Join-Path $PSScriptRoot '..\config\games.example.json'))

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = [Windows.Forms.Form]::new()
$form.Text = 'Adaptive Gaming Power'
$form.Size = [Drawing.Size]::new(420, 255)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$label = [Windows.Forms.Label]::new()
$label.Location = [Drawing.Point]::new(20, 20)
$label.Size = [Drawing.Size]::new(365, 45)
$label.Text = 'Choose a profile. Applying power changes may request administrator approval.'
$form.Controls.Add($label)

$script = Join-Path $PSScriptRoot 'GamingPower.ps1'
$buttons = @(
    @{ text = 'Auto'; mode = 'Auto'; x = 20 },
    @{ text = 'Plugged in'; mode = 'AC'; x = 115 },
    @{ text = 'Battery'; mode = 'Battery'; x = 210 },
    @{ text = 'Status'; mode = 'Status'; x = 305 }
)
foreach ($definition in $buttons) {
    $button = [Windows.Forms.Button]::new()
    $button.Text = $definition.text
    $button.Location = [Drawing.Point]::new($definition.x, 80)
    $button.Size = [Drawing.Size]::new(85, 35)
    $mode = $definition.mode
    $button.Add_Click({
        if ($mode -eq 'Status') {
            Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script, '-Mode', $mode, '-ConfigPath', $ConfigPath)
        } else {
            Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script, '-Mode', $mode, '-ConfigPath', $ConfigPath, '-Apply')
        }
    }.GetNewClosure())
    $form.Controls.Add($button)
}

$inventory = [Windows.Forms.Button]::new()
$inventory.Text = 'Refresh Steam inventory'
$inventory.Location = [Drawing.Point]::new(105, 140)
$inventory.Size = [Drawing.Size]::new(200, 35)
$inventory.Add_Click({ Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'Inventory-Games.ps1')) })
$form.Controls.Add($inventory)
[void]$form.ShowDialog()

