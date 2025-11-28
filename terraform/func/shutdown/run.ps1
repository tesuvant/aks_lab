param($Timer)
Set-AzContext -Subscription $env:SUBSCRIPTION

# Stop AKS
try {
    Stop-AzAksCluster -ResourceGroupName $env:RESOURCE_GROUP -Name $env:AKS_NAME -Force -ErrorAction Stop
    Write-Host "AKS cluster stopped successfully"
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Warning "Failed to stop AKS cluster: $errorMessage"
}

# Remove Bastion
try {
    Remove-AzBastion -ResourceGroupName $env:RESOURCE_GROUP -Name $env:BASTION_NAME -Force -ErrorAction Stop
    Write-Host "Bastion deleted"
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Warning "Failed to delete Bastion: $errorMessage"
}

# Stop VM
try {
    Stop-AzVM -ResourceGroupName $env:RESOURCE_GROUP -Name $env:VM_NAME -Force -ErrorAction Stop
    Write-Host "VM stopped successfully"
}
catch {
    Write-Warning "Failed to stop VM: $($_.Exception.Message)"
}