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
    Write-Information "AKS $($aks.Name) is running. Stopping..." -InformationAction Continue

    ### Possible ProvisioningState values:
    # Succeeded
    #   The cluster operation completed successfully and the cluster is in a stable state.
    # Starting
    #   The cluster control plane and nodes are in the process of starting up.
    # Stopping
    #   The cluster is being shut down.
    # Updating
    #   Cluster is undergoing an update or configuration change.
    # Failed
    #   The last operation failed; the cluster is in an error state.
    # Canceled
    #   A long-running operation was aborted.
    # Unknown
    #   The system cannot determine the current state.
    if ($aks.ProvisioningState -ne "Succeeded") {
        Write-Warning "AKS in $($aks.ProvisioningState). Aborting ongoing operation..."
        Invoke-AzAksAbortManagedClusterLatestOperation -ResourceGroupName $env:RESOURCE_GROUP -ResourceName $env:AKS_NAME
        Start-Sleep -Seconds 120
    }
    $aks | Stop-AzAksCluster
    Write-Information "AKS $($aks.Name) is stopped" -InformationAction Continue
} else {
    Write-Information "AKS $($aks.Name) already stopped (PowerState: $($aks.PowerState.Code))" -InformationAction Continue
}

# Remove Bastion
$bastion = Get-AzBastion -ResourceGroupName $env:RESOURCE_GROUP -Name $env:BASTION_NAME -ErrorAction SilentlyContinue
if ($bastion) {
    Write-Information "Bastion $($bastion.Name) exists. Deleting..." -InformationAction Continue
    $bastion | Remove-AzBastion -Force
    Write-Information "Bastion $($bastion.Name) is deleted" -InformationAction Continue
} else {
    Write-Information "Bastion $($env:BASTION_NAME) does not exist" -InformationAction Continue
}

# Stop VMs
$vms = Get-AzVm -ResourceGroupName $env:RESOURCE_GROUP -Status
foreach ($vm in $vms) {
    if ($vm.PowerState -like "*running*") {
        Write-Information "VM $($vm.Name) is running. Stopping" -InformationAction Continue
        $vm | Stop-AzVM -Force -NoWait
        Write-Information "VM $($vm.Name) is stopped" -InformationAction Continue
    } else {
        Write-Information "VM $($vm.Name) already stopped (PowerState: $($vm.PowerState))" -InformationAction Continue
    }
}
