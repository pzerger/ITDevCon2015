# This script will create a 3-subnet VNET in Azure V2

# Authenticate to Azure Account

Add-AzureAccount

# Authenticate with Azure AD credentials

$cred = Get-Credential

Add-AzureAccount `
    -Credential $cred

# Switch to Azure Resource Manager mode

Switch-AzureMode `
    -Name AzureResourceManager


# Register the latest ARM Providers

Register-AzureProvider `
    -ProviderNamespace Microsoft.Compute `
    -Force

Register-AzureProvider `
    -ProviderNamespace Microsoft.Storage `
    -Force

Register-AzureProvider `
    -ProviderNamespace Microsoft.Network `
    -Force


# Confirm registered ARM Providers

Get-AzureProvider |
     Select-Object `
        -Property ProviderNamespace `
        -ExpandProperty ResourceTypes 
        
# Confirm registered ARM Providers

Get-AzureProvider |
     Select-Object `
        -Property ProviderNamespace `
        -ExpandProperty ResourceTypes


# Select an Azure subscription

$subscriptionId = 
    (Get-AzureSubscription |
     Out-GridView `
        -Title "Select a Subscription ..." `
        -PassThru).SubscriptionId

Select-AzureSubscription `
    -SubscriptionId $subscriptionId

    # Create Resource Group

    New-AzureResourceGroup `
    -Name 'ITDevCon-RG' `
    -Location "West US"


# Create a virtual network:

$backendSubnet = New-AzureVirtualNetworkSubnetConfig -Name LB-Subnet-BE -AddressPrefix 10.0.2.0/24

# Creates a subnet for the virtual network and assigns to $backendSubnet

New-AzurevirtualNetwork -Name NRPVNet -ResourceGroupName ITDevCon-RG -Location "West US" -AddressPrefix 10.0.0.0/16 -Subnet $backendSubnet

# Create a public IP address to be used by frontend IP pool:

$publicIP = New-AzurePublicIpAddress -Name PublicIp -ResourceGroupName ITDevCon-RG -Location "West US" –AllocationMethod Dynamic -DomainNameLabel itdevcon2015lbip 

####################################################
#
# Create Front end IP pool and backend address pool
#
####################################################

# Using public IP variable ($publicIP), create the front end IP pool.

$frontendIP = New-AzureLoadBalancerFrontendIpConfig -Name LB-Frontend -PublicIpAddress $publicIP 

# Set up a back end address pool used to receive incoming traffic from front end IP pool:

$beaddresspool= New-AzureLoadBalancerBackendAddressPoolConfig -Name "LB-backend"


# After creating the front end IP pool and the backend address pool, you will need to create the rules which will belong to the load balancer resource:

$inboundNATRule1= New-AzureLoadBalancerInboundNatRuleConfig -Name "RDP1" -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3441 -BackendPort 3389

$inboundNATRule2= New-AzureLoadBalancerInboundNatRuleConfig -Name "RDP2" -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3442 -BackendPort 3389

$healthProbe = New-AzureLoadBalancerProbeConfig -Name "HealthProbe" -RequestPath "HealthProbe.aspx" -Protocol http -Port 80 -IntervalInSeconds 15 -ProbeCount 2

$lbrule = New-AzureLoadBalancerRuleConfig -Name "HTTP" -FrontendIpConfiguration $frontendIP -BackendAddressPool $beAddressPool -Probe $healthProbe -Protocol Tcp -FrontendPort 80 -BackendPort 80

# Create the load balancer adding all objects (NAT rules, Load balancer rules, probe configurations) together:

$NRPLB = New-AzureLoadBalancer -ResourceGroupName "ITDevCon-RG" -Name "NRP-LB" -Location "West US" `
-FrontendIpConfiguration $frontendIP -InboundNatRule $inboundNATRule1,$inboundNatRule2 -LoadBalancingRule $lbrule -BackendAddressPool $beAddressPool -Probe $healthProbe 

###########################################################################
#
# Get the resource virtual network and subnet to create network interfaces:
#
###########################################################################

# Get the resource virtual network and subnet to create network interfaces:

$vnet = Get-AzureVirtualNetwork -Name NRPVNet -ResourceGroupName ITDevCon-RG

$backendSubnet = Get-AzureVirtualNetworkSubnetConfig -Name LB-Subnet-BE -VirtualNetwork $vnet 

# In this step, we are creating a network interface which will belong to the load balancer back end pool and associate the first NAT rule for RDP for this network interface:

$backendnic1= New-AzureNetworkInterface -ResourceGroupName "ITDevCon-RG" -Name lb-nic1-be -Location "West US" `
-PrivateIpAddress 10.0.2.6 -Subnet $backendSubnet -LoadBalancerBackendAddressPool $nrplb.BackendAddressPools[0] -LoadBalancerInboundNatRule $nrplb.InboundNatRules[0]

# Create a second network interface called LB-Nic2-BE:

$backendnic2= New-AzureNetworkInterface -ResourceGroupName "ITDevCon-RG" -Name lb-nic2-be -Location "West US" `
-PrivateIpAddress 10.0.2.7 -Subnet $backendSubnet -LoadBalancerBackendAddressPool $nrplb.BackendAddressPools[0] -LoadBalancerInboundNatRule $nrplb.InboundNatRules[1]