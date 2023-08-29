# Import the required Azure module
Import-Module Az.Compute

# Connect to your Azure account
Connect-AzAccount

# Specify your resource group and host pool details
$resourceGroupName = "WVD-EUS2-RG"
$hostPoolName = "WVD-EUS2-Pooled"

# Specify your data disks requirements
$dataDiskSizeGB = 100  # Size of the data disk in GB
$dataDiskSkuName = "StandardSSD_LRS" # Options:  Standard_LRS, Premium_LRS, StandardSSD_LRS, and UltraSSD_LRS, Premium_ZRS and Standard SSD_ZRS. 
$dataDiskName = "-datadisk" # Takes the name of the virtual machine and adds -datadisk at the end. 
$dataDiskCaching = "None"

# Get a list of session hosts in the host pool
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $resourceGroupName -HostPoolName $hostPoolName

# Extracting domain from the host pool
$domainPattern = ($sessionHosts.Name[0] -split '/')[1] -replace '^[^\.]+\.', '\.'

# Extract the names of the virtual machines from the session hosts
$VMNames = $sessionHosts.Name | ForEach-Object {
    $namePart = ($_ -split '/')[1]
    $namePart -replace $domainPattern + '$'
    
}
# Loop through each session host and attach the data disk
foreach ($vmname in $VMNames) {

    $vm = Get-AzVM -Name $vmName

    # If a data disk already exists under the same name, we assume that script ran previously against this VM.
    $diskStatus = Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName (($vm.Name)+($dataDiskName)) -ErrorAction SilentlyContinue

    if (!$diskStatus) {

        # Create the data disk config
        $dataDiskConfig = New-AzDiskConfig -Location $vm.Location -CreateOption Empty -SkuName $dataDiskSkuName -DiskSizeGB $dataDiskSizeGB

        # Create the new data disk
        $dataDisk = New-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName (($vm.Name)+($dataDiskName)) -Disk $dataDiskConfig

        # Get the next available LUN ID
        $lunid = ($vm.StorageProfile.DataDisks.Lun | Measure -Maximum).Maximum + 1

        # Add the data disk to the VM configuration
        $vm = Add-AzVMDataDisk -VM $vm -Name (($vm.Name)+($dataDiskName)) -CreateOption attach -Lun $lunid -ManagedDiskId $dataDisk.ID -Caching $dataDiskCaching

        # Update the VM with the new configuration
        Update-AzVM -VM $vm -ResourceGroupName $vm.ResourceGroupName
    }

}

# Disconnect from your Azure account
Disconnect-AzAccount