param($Timer)

Write-Host "Listing available Az modules..."
Get-Module -ListAvailable Az* | Select-Object Name, Version | Out-String | Write-Host
Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Compute  -ErrorAction Stop
Import-Module Az.Aks      -ErrorAction Stop
Import-Module Az.Network  -ErrorAction Stop
Write-Host "Modules imported successfully"

Set-AzContext -Subscription $env:SUBSCRIPTION

# Stop AKS
$aks = Get-AzAksCluster -ResourceGroupName $env:RESOURCE_GROUP -Name $env:AKS_NAME -ErrorAction SilentlyContinue
if ($aks.PowerState.Code -eq "Running") {
    Write-Information "AKS $($aks.Name) is running. Stopping" -InformationAction Continue
    $aks | Stop-AzAksCluster -Force
    Write-Information "AKS $($aks.Name) is stopping" -InformationAction Continue
} else {
    Write-Information "AKS $($aks.Name) already stopped (PowerState: $($aks.PowerState.Code))" -InformationAction Continue
}

# Remove Bastion
$bastion = Get-AzBastion -ResourceGroupName $env:RESOURCE_GROUP -Name $env:BASTION_NAME -ErrorAction SilentlyContinue
if ($bastion) {
    Write-Information "Bastion $($bastion.Name) exists. Deleting" -InformationAction Continue
    $bastion | Remove-AzBastion -Force
    Write-Information "Bastion $($bastion.Name) is deleting" -InformationAction Continue
} else {
    Write-Information "Bastion $($env:BASTION_NAME) does not exist" -InformationAction Continue
}

# Stop VMs
$vms = Get-AzVm -ResourceGroupName $env:RESOURCE_GROUP -Status
foreach ($vm in $vms) {
    if ($vm.PowerState -like "*running*") {
        Write-Information "VM $($vm.Name) is running. Stopping" -InformationAction Continue
        $vm | Stop-AzVM -Force -NoWait
        Write-Information "VM $($vm.Name) is stopping" -InformationAction Continue
    } else {
        Write-Information "VM $($vm.Name) already stopped (PowerState: $($vm.PowerState))" -InformationAction Continue
    }
}
