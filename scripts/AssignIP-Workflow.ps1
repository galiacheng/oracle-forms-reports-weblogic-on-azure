workflow AssignIP-Workflow {
    param (
        [parameter(Mandatory = $false)]
        [Object]$RecoveryPlanContext
    )

    # Client id of user assigned managed identity, make sure the identity has enough permission to update resoruces.
    $identityClientId = "18ada7c8-9bf0-4ff4-bbf0-f1ad8c20d436"
    # Network inteface name of adminVM
    $nicName = "adminvmzone1951_z1"
    # IP config name for secondary IP
    $ipConfig2Name = "ipconfig2"
    # Virtual network name
    $vnetName = "wlsd_VNET"
    # Reource group name of who has virtual network deployed
    $vnetResourceGroup = "haiche-dynamic-cluster-forms-reports"
    # Subnet name which has IP address for adminVM
    $subNetName = "Subnet"
    # Secondary IP address
    $secondaryPrivateIPAddress = "10.0.0.16"
    # Source reource group name
    $sourceResourceGroup="haiche-dynamic-cluster-forms-reports"
    # Target resource group name
    $targetResourceGroup="haiche-dynamic-cluster-forms-reports-asr"

    $direction = $RecoveryPlanContext.FailoverDirection
    if ( $direction -ne "PrimaryToSecondary") {
        $temp=$sourceResourceGroup
        $sourceResourceGroup=$targetResourceGroup
        $targetResourceGroup=$temp
    }

    InlineScript {
		# Ensures you do not inherit an AzContext in your runbook
		Disable-AzContextAutosave -Scope Process

		$AzureContext = (Connect-AzAccount -Identity -AccountId ${identityClientId}).context

		# set and store context
		$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

        #$nic = Get-AzNetworkInterface -Name $Using:nicName -ResourceGroupName $Using:resourceGroup
        $nic = Get-AzNetworkInterface | Where-Object { ($_.ResourceGroupName -eq $Using:sourceResourceGroup) -and ($_.Name -eq $Using:nicName) }
        Remove-AzNetworkInterfaceIpConfig -Name $Using:ipConfig2Name -NetworkInterface $nic
        Set-AzNetworkInterface -NetworkInterface $nic
        Write-Output("Complete removing IP from source network interface")

        $nic2 = Get-AzNetworkInterface | Where-Object { ($_.ResourceGroupName -eq $Using:targetResourceGroup) -and ($_.Name -eq $Using:nicName) }
        Write-Output("Complete querying target network interface")
        $vnet = Get-AzVirtualNetwork | Where-Object { ($_.ResourceGroupName -eq $Using:vnetResourceGroup) -and ($_.Name -eq $Using:vnetName) }
        Write-Output("Complete querying vnet")
        $subNet = Get-AzVirtualNetworkSubnetConfig -Name $Using:subNetName -VirtualNetwork $vnet
        Write-Output("Complete querying sub net")
        $ipconf2 = New-AzNetworkInterfaceIpConfig -Name $Using:ipConfig2Name -Subnet $subNet -PrivateIpAddress $Using:secondaryPrivateIPAddress
        Write-Output("Complete creating new nic ip config")
        # $nic2.IpConfigurations | Format-Table Name, PrivateIPAddress
        # Write-Output("Update ip")
        $nic2.IpConfigurations.Add($ipconf2)
        Write-Output("Complete assigning secondary ip to target nic")
        $nic2.IpConfigurations | Format-Table Name, PrivateIPAddress
        Set-AzNetworkInterface -NetworkInterface $nic2
        Write-Output("Done")
    }	
}