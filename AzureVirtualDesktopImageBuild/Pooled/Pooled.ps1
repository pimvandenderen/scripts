function Expand-ZIPFile($file, $destination){
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($file)
    foreach($item in $zip.items()){
    $shell.Namespace($destination).copyhere($item)
    }
}

while ((Get-Service RdAgent).Status -ne 'Running') { 
    Start-Sleep -s 5  
}
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Create Directories
$LabFilesDirectory = "C:\LabFiles"

if(!(Test-path -Path "$LabFilesDirectory")){
New-Item -Path $LabFilesDirectory -ItemType Directory |Out-Null
}
if(!(Test-path -Path "$LabFilesDirectory\FSLogix")){
New-Item -Path "$LabFilesDirectory\FSLogix" -ItemType Directory |Out-Null
}

#Download FSLogix Installation bundle
if(!(Test-path -Path "$LabFilesDirectory\FSLogix_Apps_Installation.zip")){
    Invoke-WebRequest -Uri "https://experienceazure.blob.core.windows.net/templates/wvd/FSLogix_Apps_Installation.zip" -OutFile     "$LabFilesDirectory\FSLogix_Apps_Installation.zip"
}

#Extract the downloaded FSLogix bundle
Expand-ZIPFile -File "$LabFilesDirectory\FSLogix_Apps_Installation.zip" -Destination "$LabFilesDirectory\FSLogix"

#Install FSLogix
Start-Process 'C:\LabFiles\FSLogix\x64\Release\FSLogixAppsSetup.exe' -Wait -ArgumentList '/install /quiet'

#Create registry key 'Profiles' under 'HKLM:\SOFTWARE\FSLogix'
$registryPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
if(!(Test-path $registryPath)){
    New-Item -Path $registryPath -Force | Out-Null
}

#Add registry values to enable FSLogix profiles, add VHD Locations, Delete local profile and FlipFlop Directory name
New-ItemProperty -Path $registryPath -Name "VHDLocations" -Value "\\avdterraformdemo.file.core.windows.net\userprofile" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "FlipFlopProfileDirectoryName" -Value 1 -PropertyType DWord -Force | Out-Null

#Display script completion in console
Write-Host "Script Executed successfully"

#Run sysprep
& $Env:SystemRoot\System32\Sysprep\Sysprep.exe /oobe /generalize /quiet /quit

while($true) {
    $imageState = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State).ImageState
    Write-Output $imageState 
    if ($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
        break 
    } 
    Start-Sleep -s 5
}
    
Write-Output ">>> Sysprep complete ..."