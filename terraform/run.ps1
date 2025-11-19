param($TimerTrigger, $TriggerMetadata)

Write-Host "PowerShell function triggered at: $(Get-Date)"

try {
    # Connect to Azure using Managed Identity
    Connect-AzAccount -Identity

    # Variables: replace with your actual resource details
    $resourceGroup = $env:RESOURCE_GROUP
    $aksName = $env:AKS_NAME
    $vmName = $env:VM_NAME

    # Stop AKS cluster
    Stop-AzAksCluster -ResourceGroupName $resourceGroup -Name $aksName -Force
    Write-Host "AKS cluster '$aksName' stopped."

    # Stop VM
    Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force
    Write-Host "Virtual machine '$vmName' stopped."

} catch {
    Write-Error "Error: $_"
}
