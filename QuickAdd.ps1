# QuickAdd.ps1 - System-wide quick-add popup for MyJo
# Launch via the desktop shortcut (Ctrl+Alt+A) from any context on the machine.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Read config
$configFile = "$env:USERPROFILE\.myjo\config.txt"
$notebooks = [System.Collections.Generic.List[string]]::new()
$activeNotebook = "default"

if (Test-Path $configFile) {
    foreach ($line in (Get-Content $configFile)) {
        if ($line -match '^notebook:([^=]+)=') {
            $notebooks.Add($Matches[1].Trim())
        }
        if ($line -match '^active=(.+)$') {
            $activeNotebook = $Matches[1].Trim()
        }
    }
}

$notebooks = $notebooks | Sort-Object

if ($notebooks.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "No MyJo notebooks configured. Run 'myjo -setup' first.",
        "MyJo", "OK", "Error")
    exit 1
}

# Build form
$form = New-Object System.Windows.Forms.Form
$form.Text = "MyJo Quick Add"
$form.Size = New-Object System.Drawing.Size(430, 280)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Notebook label
$notebookLabel = New-Object System.Windows.Forms.Label
$notebookLabel.Text = "Notebook:"
$notebookLabel.Location = New-Object System.Drawing.Point(12, 15)
$notebookLabel.Size = New-Object System.Drawing.Size(68, 22)
$notebookLabel.TextAlign = "MiddleLeft"

# Notebook dropdown
$notebookCombo = New-Object System.Windows.Forms.ComboBox
$notebookCombo.Location = New-Object System.Drawing.Point(83, 12)
$notebookCombo.Size = New-Object System.Drawing.Size(320, 22)
$notebookCombo.DropDownStyle = "DropDownList"
foreach ($nb in $notebooks) {
    $notebookCombo.Items.Add($nb) | Out-Null
}
if ($notebookCombo.Items.Contains($activeNotebook)) {
    $notebookCombo.SelectedItem = $activeNotebook
} else {
    $notebookCombo.SelectedIndex = 0
}

# Entry text box (multiline)
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(12, 45)
$textBox.Size = New-Object System.Drawing.Size(393, 150)
$textBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.AcceptsReturn = $true

# Hint label
$hintLabel = New-Object System.Windows.Forms.Label
$hintLabel.Text = "Ctrl+Enter to submit"
$hintLabel.Location = New-Object System.Drawing.Point(12, 203)
$hintLabel.Size = New-Object System.Drawing.Size(150, 18)
$hintLabel.ForeColor = [System.Drawing.Color]::Gray
$hintLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)

# Add button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "Add"
$okButton.Location = New-Object System.Drawing.Point(245, 198)
$okButton.Size = New-Object System.Drawing.Size(75, 28)
$okButton.DialogResult = "OK"

# Cancel button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Location = New-Object System.Drawing.Point(330, 198)
$cancelButton.Size = New-Object System.Drawing.Size(75, 28)
$cancelButton.DialogResult = "Cancel"
$form.CancelButton = $cancelButton

# Ctrl+Enter submits
$textBox.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq "Return") {
        $form.DialogResult = "OK"
        $form.Close()
    }
})

$form.Controls.AddRange(@($notebookLabel, $notebookCombo, $textBox, $hintLabel, $okButton, $cancelButton))
$form.Add_Shown({ $textBox.Focus() })

$dialogResult = $form.ShowDialog()

if ($dialogResult -eq "OK" -and $textBox.Text.Trim() -ne "") {
    $selectedNotebook = $notebookCombo.SelectedItem
    $entryText = $textBox.Text.Trim()
    $myjoScript = Join-Path $PSScriptRoot "Journal.ps1"

    try {
        if ($selectedNotebook -ne $activeNotebook) {
            & powershell -ExecutionPolicy Bypass -NoProfile -File $myjoScript -Notebook $selectedNotebook | Out-Null
        }
        & powershell -ExecutionPolicy Bypass -NoProfile -File $myjoScript $entryText | Out-Null
        if ($selectedNotebook -ne $activeNotebook) {
            & powershell -ExecutionPolicy Bypass -NoProfile -File $myjoScript -Notebook $activeNotebook | Out-Null
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error adding entry:`n$_",
            "MyJo Error", "OK", "Error")
    }
}
