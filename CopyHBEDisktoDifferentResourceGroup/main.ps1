Install-Module -Name Az -Scope CurrentUser
Connect-AzAccount
Select-AzSubscription -SubscriptionName "sub-onprem"

# Before running the script, make sure that:
# 1. The source virtual machine is PoweredOff
# 2. The target virtual machine created and PoweredOff
# 3. The target virtual machine needs to be in the same resource group as the target disk. 

# Set the variables 
$sourceRG = "hbe-rg"
$sourceVM = "TestVM"
$sourceDiskName = "TestVM_OSDisk"
$targetLocate = "eastus"
$targetRG = "exporteddisk-rg"
$targetDiskName = 'exported-' + $sourceDiskName
$targetOS = "Windows"
$targetVMName = "TargetVM"
$targetDiskSku = "StandardSSD_LRS"

# Check if disk encryption is enabled on the VM 
## https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disks-enable-host-based-encryption-powershell#examples
$check = Get-AzVM -ResourceGroupName $sourceRG -Name $sourceVM
$check.SecurityProfile.EncryptionAtHost

# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disks-upload-vhd-to-managed-disk-powershell
$sourceDisk = Get-AzDisk -ResourceGroupName $sourceRG -DiskName $sourceDiskName
$targetDiskconfig = New-AzDiskConfig -SkuName $targetDiskSku -osType $targetOS -UploadSizeInBytes $($sourceDisk.DiskSizeBytes+512) -Location $targetLocate -CreateOption 'Upload'  # Adding the sizeInBytes with the 512 offset, and the -Upload flag
$targetDisk = New-AzDisk -ResourceGroupName $targetRG -DiskName $targetDiskName -Disk $targetDiskconfig
$sourceDiskSas = Grant-AzDiskAccess -ResourceGroupName $sourceRG -DiskName $sourceDiskName -DurationInSecond 86400 -Access 'Read'
$targetDiskSas = Grant-AzDiskAccess -ResourceGroupName $targetRG -DiskName $targetDiskName -DurationInSecond 86400 -Access 'Write'
azcopy copy $sourceDiskSas.AccessSAS $targetDiskSas.AccessSAS --blob-type PageBlob
Revoke-AzDiskAccess -ResourceGroupName $sourceRG -DiskName $sourceDiskName
Revoke-AzDiskAccess -ResourceGroupName $targetRG -DiskName $targetDiskName 

# https://docs.microsoft.com/en-us/azure/virtual-machines/windows/attach-disk-ps#attach-an-existing-data-disk-to-a-vm
$disk = Get-AzDisk -ResourceGroupName $targetRG -DiskName $targetDiskName
$vm = Get-AzVM -Name $targetVMName -ResourceGroupName $targetRG
$vm = Add-AzVMDataDisk -CreateOption Attach -Lun 0 -VM $vm -ManagedDiskId $disk.Id
Update-AzVM -VM $vm -ResourceGroupName $targetRG
Start-AzVM -Name $vm.Name -ResourceGroupName $targetRG
