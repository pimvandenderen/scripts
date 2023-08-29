while ((Get-Service RdAgent).Status -ne 'Running') { 
    Start-Sleep -s 4 
}
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install notepadplusplus -y --force --force-dependencies
choco install 7zip -y --force --force-dependencies
choco install firefox -y --force --force-dependencies

& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit

while($true) { 
    $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; 
    if ($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { 
        Write-Output $imageState.ImageState; 
        Start-Sleep -s 10  
    } else { 
        break
     } 
}
