$ErrorActionPreference = "Stop"

# Constants
$localPath = "<TO-BE-FILLED>"
$cloudPath = "<TO-BE-FILLED>"
$fileName = "Sync_Save.sav"

### !! DON'T EDIT ANYTHING FROM HERE ON !!
### Helpers

Add-Type -AssemblyName System.Windows.Forms

function PrintMenu() {
    Write-Host "Welcome to SaveSyncer!"
    Write-Host "==================================================================="
    for ($i = 0; $i -lt $Script:actions.Count; $i++) {
        $index = $i + 1
        Write-Host $index":" ($Script:actions[$i].GetDisplayText())
    }
    Write-Host ""
    Write-Host "q: quit"
    Write-Host ""
}

function ValidateSetup() {
    $errors = 0
    if ($null -eq $localPath -or -not (Test-Path $localPath)) {
        $errors++
        Write-Host "The configured path for the local save does not exist!"
    }
    if ($null -eq $cloudPath -or -not (Test-Path $cloudPath)) {
        $errors++
        Write-Host "The configured path for the cloud save does not exist!"
    }
    if ($errors -gt 0) {
        Write-Host "Please update the appropriate paths in this script and try again!"
        Pause
        Exit
    }
}

function InitializieActions {
    $Script:actions = [Action[]]::new(3)

    $actions[0] = [CopyToCloudAction]::new()
    $actions[1] = [CopyToLocalAction]::new()
    $actions[2] = [RestoreSpecificAction]::new()
    # $actions[3] = [RestorePreviousLocalAction]::new()
}

function GetBackupPath() {
    return Join-Path -Path $cloudPath -ChildPath "BACKUP"
}

function GetBackupFileName($prefix) {
    return $prefix + '_' + $fileName
}

function GetCloudSaveFilePath() {
    return Join-Path -Path $cloudPath -ChildPath $fileName
}

function GetLocalSaveFilePath() {
    return (Join-Path -Path $localPath -ChildPath $fileName)
}

function BackupOldCloudSave() {
    $currentDate = (Get-Date).ToString("yyyyMMdd_hhmmss")
    $backupPath = GetBackupPath
    if (-not (Test-Path $backupPath)) {
        New-Item $backupPath -ItemType Directory
    }
    $newBackup = Join-Path -Path (GetBackupPath) -ChildPath (GetBackupFileName $currentDate)
    Copy-Item -Path (GetCloudSaveFilePath) -Destination $newBackup
}

function GetLocalBackupSavePath() {
    return Join-Path -Path $localPath -ChildPath (GetBackupFileName "BU")
}

function BackupOldLocalSave() {
    Copy-Item -Path (GetLocalSaveFilePath) -Destination (GetLocalBackupSavePath)
}


### Actions
class Action {
    [string]$DisplayText

    Action([string]$DisplayText) {
        $this.DisplayText = $DisplayText
    }

    [bool]IsEnabled() {
        return $false
    }

    [string]GetDisplayText() {
        if ($this.IsEnabled()) {
            return $this.DisplayText
        }
        else {
            return "(Disabled) " + $this.DisplayText
        }
    }

    [void]RunAction() {
        throw "Not implemented!"
    }
}

class CopyToLocalAction : Action {
    CopyToLocalAction() : base("Copy the cloud save to your local storage") {}
    CopyToLocalAction([string]$DisplayText) : base($DisplayText) {}

    [bool]IsEnabled() {
        return Test-Path (GetCloudSaveFilePath)
    }

    [void]RunAction() {
        if (Test-Path (GetLocalSaveFilePath)) {
            BackupOldLocalSave
        }
        Copy-Item -Path $this.getSourceFile() -Destination (GetLocalSaveFilePath)
        Write-Host "Copied the cloud save to your local save directory."
    }
    
    [string]GetSourceFile() {
        return GetCloudSaveFilePath
    }
}

class CopyToCloudAction : Action {
    CopyToCloudAction() : base("Copy your local save to cloud") {}
    
    [bool]IsEnabled() {
        return Test-Path (GetLocalSaveFilePath)
    }

    [void]RunAction() {
        if (Test-Path (GetCloudSaveFilePath)) {
            BackupOldCloudSave
        }
        Copy-Item -Path (GetLocalSaveFilePath) -Destination (GetCloudSaveFilePath)
        Write-Host "Copied your local save to the cloud save directory."
    }


}

class RestoreSpecificAction : CopyToLocalAction {
    RestoreSpecificAction() : base("Copy a specific old version from the cloud to your local storage") {}

    [bool]IsEnabled() {
        $backupPath = GetBackupPath
        return (Test-Path $backupPath) -and (Test-Path "$backupPath/*")
    }

    [string]GetSourceFile() {
        $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
        $FileBrowser.InitialDirectory = (GetBackupPath)
        $FileBrowser.Title = "Select Save Game"
        $FileBrowser.Filter = "Saves (*.sav)|*.sav"
        $FileBrowser.Multiselect = $false
        $FileBrowser.CheckFileExists = $true
        $result = $FileBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))

        if ($result -eq 'Cancel') {
            Write-Host "Selection cancelled. Closing Sync Saver."
            Exit
            Pause
        }

        return $FileBrowser.FileName
    }
}

# FIXME: This does some weird shit, and I don't know why :/
# class RestorePreviousLocalAction : Action {
#     RestorePreviousLocalAction() : base("Restore your previous local save") {}
    
#     [bool]IsEnabled() {
#         return Test-Path (GetLocalBackupSavePath)
#     }

#     [void]RunAction() {
#         $tmpFile = (GetLocalBackupSavePath) + ".tmp"
#         Rename-Item -Path (GetLocalBackupSavePath) -NewName $tmpFile
#         if (Test-Path (GetLocalSaveFilePath)) {
#             BackupOldLocalSave
#             Remove-Item (GetLocalSaveFilePath)
#         }
#         Rename-Item -Path $tmpFile -NewName (GetLocalSaveFilePath)
#         Write-Host "Restored your previous local save and backed up the current if existing."
#     }

#     [string]GetSourceFile() {
#         return GetLocalSaveFilePath
#     }
# }

########################
### Main ###############
########################

ValidateSetup
InitializieActions
PrintMenu

While ($true) {
    $chosenAction = Read-Host "What do you want to do?"
    if ($chosenAction -eq 'q') {
        Exit
    }
    if (!($chosenAction -gt 0 -and $chosenAction -le $Script:actions.Count)) {
        Write-Host "Please enter a valid character!"
    }
    else {
        $indexedAction = $chosenAction - 1
        if ($Script:actions[$indexedAction].IsEnabled()) {
            $Script:actions[$indexedAction].RunAction()
            break
        }
        else {
            Write-Host "The chosen action is disabled. The required files are not present."
        }
    }
}
Pause

