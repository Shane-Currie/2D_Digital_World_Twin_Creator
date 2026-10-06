Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$creatorDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectFile = Join-Path $creatorDirectory 'project.godot'
$settingsDirectory = Join-Path $env:LOCALAPPDATA '2D Digital World Twin Creator'
$settingsFile = Join-Path $settingsDirectory 'launcher.json'
$launchLog = Join-Path $creatorDirectory 'creator-studio-startup.log'

function Read-SavedGodotExecutable {
    if (-not (Test-Path -LiteralPath $settingsFile -PathType Leaf)) { return $null }
    try {
        $settings = Get-Content -Raw -LiteralPath $settingsFile | ConvertFrom-Json
        if ($settings.godot_executable -and (Test-Path -LiteralPath $settings.godot_executable -PathType Leaf)) {
            return [string]$settings.godot_executable
        }
    } catch {
        # A damaged preference must not prevent the creator from choosing Godot again.
    }
    return $null
}

function Save-GodotExecutable([string]$executablePath) {
    try {
        New-Item -ItemType Directory -Path $settingsDirectory -Force | Out-Null
        @{ godot_executable = $executablePath } | ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
    } catch {
        # Remembering the path is helpful, but not required to launch the program.
    }
}

function Find-GodotExecutable {
    $saved = Read-SavedGodotExecutable
    if ($saved) { return $saved }

    foreach ($commandName in @('godot4.exe', 'godot.exe')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) { return $command.Source }
    }

    $desktopDirectory = [Environment]::GetFolderPath('Desktop')
    $fixedCandidates = @(
        (Join-Path $creatorDirectory 'Godot.exe'),
        (Join-Path $desktopDirectory 'Godot_v4.7.2-stable_win64.exe'),
        (Join-Path $env:ProgramFiles 'Godot\Godot.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Godot\Godot.exe')
    )
    foreach ($candidate in $fixedCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    if ($desktopDirectory -and (Test-Path -LiteralPath $desktopDirectory)) {
        $desktopGodot = Get-ChildItem -LiteralPath $desktopDirectory -Filter 'Godot*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($desktopGodot) { return $desktopGodot.FullName }
    }
    return $null
}

if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Creator Studio could not find project.godot beside the launcher.`n`nKeep the .cmd, .ps1 and project folders together.",
        'Creator Studio files are incomplete', 'OK', 'Error'
    ) | Out-Null
    exit 1
}

$godotExecutable = Find-GodotExecutable
if (-not $godotExecutable) {
    $filePicker = New-Object System.Windows.Forms.OpenFileDialog
    $filePicker.Title = 'Locate Godot 4.7 or newer'
    $filePicker.Filter = 'Godot executable (Godot*.exe)|Godot*.exe|Windows programs (*.exe)|*.exe'
    $filePicker.CheckFileExists = $true
    $filePicker.Multiselect = $false
    $pickerResult = $filePicker.ShowDialog()
    if ($pickerResult -eq [System.Windows.Forms.DialogResult]::OK) {
        $godotExecutable = $filePicker.FileName
    }
}

if (-not $godotExecutable) {
    $message = "Creator Studio needs Godot 4.7 or newer for this development version.`n`nYour project files are safe. Would you like to open the official Godot download page?"
    $choice = [System.Windows.Forms.MessageBox]::Show($message, 'Godot is needed', 'YesNo', 'Information')
    if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process 'https://godotengine.org/download/windows/'
    }
    exit 1
}

try {
    $versionText = (& $godotExecutable --version 2>$null | Select-Object -First 1)
} catch {
    $versionText = ''
}
if (-not $versionText) {
    [System.Windows.Forms.MessageBox]::Show(
        "The selected file did not respond like Godot:`n$godotExecutable`n`nChoose the Godot_v4...exe file next time.",
        'Could not start Godot', 'OK', 'Error'
    ) | Out-Null
    exit 1
}
if ($versionText -notmatch '^4\.(7|8|9|[1-9][0-9])') {
    $message = "Creator Studio found:`n$godotExecutable`n`nVersion reported: $versionText`nVersion 4.7 or newer is recommended. Continue anyway?"
    $choice = [System.Windows.Forms.MessageBox]::Show($message, 'Godot version check', 'YesNo', 'Warning')
    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) { exit 1 }
}

Save-GodotExecutable $godotExecutable
Write-Host 'Starting 2D Digital World Twin Creator. The first launch can take several seconds...'

try {
    $quotedProject = '"{0}"' -f $creatorDirectory
    $quotedLog = '"{0}"' -f $launchLog
    $arguments = "--path $quotedProject --maximized --log-file $quotedLog"
    $creatorProcess = Start-Process -FilePath $godotExecutable -ArgumentList $arguments -PassThru
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Windows could not start Creator Studio.`n`n$($_.Exception.Message)",
        'Creator Studio did not start', 'OK', 'Error'
    ) | Out-Null
    exit 1
}

$deadline = [DateTime]::UtcNow.AddSeconds(20)
$visibleWindowFound = $false
do {
    Start-Sleep -Milliseconds 250
    try {
        $creatorProcess.Refresh()
        if (-not $creatorProcess.HasExited -and $creatorProcess.MainWindowHandle -ne 0) {
            $visibleWindowFound = $true
            break
        }
    } catch {
        break
    }
} while ([DateTime]::UtcNow -lt $deadline -and -not $creatorProcess.HasExited)

if ($visibleWindowFound) {
    Write-Host 'Creator Studio is ready.'
    exit 0
}

$logHint = "`n`nStartup log:`n$launchLog"
if ($creatorProcess.HasExited) {
    [System.Windows.Forms.MessageBox]::Show(
        "Godot closed before Creator Studio displayed a window.$logHint",
        'Creator Studio closed during startup', 'OK', 'Error'
    ) | Out-Null
} else {
    [System.Windows.Forms.MessageBox]::Show(
        "Godot is running, but its window did not appear within 20 seconds. Check the taskbar for 2D Digital World Twin Creator.$logHint",
        'Creator Studio is taking longer than expected', 'OK', 'Warning'
    ) | Out-Null
}
exit 1
