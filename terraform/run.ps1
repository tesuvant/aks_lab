param($TimerTrigger, $TriggerMetadata)

Write-Host "PowerShell function triggered at: $(Get-Date)"

try {
    # Connect to Azure using Managed Identity
    Connect-AzAccount -Identity

    # Variables: replace with your actual resource details
    $resourceGroup = $env:RESOURCE_GROUP
    $aksName = $env:AKS_NAME
    $vmName = $env:VM_NAME

    # AKS exists check
    $aks = $null
    try {
        $aks = Get-AzAksCluster -ResourceGroupName $resourceGroup -Name $aksName -ErrorAction Stop
    } catch {
        Write-Host "AKS cluster '$aksName' not found in resource group '$resourceGroup'. Skipping stop."
    }

    # AKS stop
    if ($aks) {
        Stop-AzAksCluster -ResourceGroupName $resourceGroup -Name $aksName -Force
        Write-Host "AKS cluster '$aksName' stopped."
    }

    # VM exsists check
    $vm = $null
    try {
        $vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName -ErrorAction Stop
    } catch {
        Write-Host "Virtual machine '$vmName' not found in resource group '$resourceGroup'. Skipping stop."
    }
    # VM stop
    if ($vm) {
        Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force
        Write-Host "Virtual machine '$vmName' stopped."
    }

} catch {
    Write-Error "Error: $_"
}
