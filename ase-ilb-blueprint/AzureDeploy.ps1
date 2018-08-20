<#
.Synopsis
   Deployment of the App Service Infrastructure
.DESCRIPTION
   One script to rule them all.  This is the script that deploys the AppSrvInfra.  It deploys multiple templates and sets the variables for these templates.
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   Version
   v1.0		2 Aug 2018		Craig Franzen		original script
   
   This script is based on this 
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>

param (
	[Parameter(Mandatory=$false)]
    [string]$AppName,
	[Parameter(Mandatory=$true)]
	[ValidateSet("Dev","Stage","Prod")]
    [string]$Environment,
	[Parameter(Mandatory=$false)]
    [string]$Region = "Central US",
    [Parameter(Mandatory=$true)]
    [string]$vnetAddressPrefix,
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile,
	[Parameter(Mandatory=$false)]
    [string]$TemplateParameterFile,
	[Parameter(Mandatory=$false)]
    [string]$TemplateUri,
	[Parameter(Mandatory=$false)]
    [string]$TemplateParameterUri,
	[Parameter(Mandatory=$false)]
    [ValidateSet("VSTS","Manual")]
	[string]$Deployment = "Manual"
)

$RGName = $AppName + "-" + $Environment + "-rg"		
$DeploymentName = $AppName + "-" +  $Environment + "-Deployment"
$SystemPrefixName = $AppName + "-" + $Environment

$vnetAddressSpace = $vnetAddressPrefix + '/24'
$WAFSubnetAddressSpace = $vnetAddressPrefix.replace('.0','.224') + '/27'
$WebAppSubnetAddressSpace = $vnetAddressPrefix+ '/26'
$BackendSubnetAddressSpace = $vnetAddressPrefix.replace('.0','.128') + '/26'

##Catch to verify AzureRM session is active.  Forces sign-in if no session is found
#region
if ($Deployment -eq "Manual") {
	Write-Host "=> Signing into Azure RM." -ForegroundColor Yellow
    Write-Host "=>" -ForegroundColor Yellow
    do {
        $azureAccess = $true
	    Try {
		    Get-AzureRmSubscription -ErrorAction Stop | Out-Null
    	}
	    Catch {
			Write-Host "=> Wow, you got kicked out...." -ForegroundColor Yellow
			Write-Host "=> I have connections!  Lets get you back in....." -ForegroundColor Yellow
			# Get Users email address from AD for logging into Azure
			$strName = $env:username
			$strFilter = "(&(objectCategory=User)(samAccountName=$strName))"
			$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
			$objSearcher.Filter = $strFilter
			$objPath = $objSearcher.FindOne()
			# this can be a few different variables
			$UserEmail = $objPath.Properties.mail
			$continue = Read-Host "Logging you into Azure using $UserEmail.  Is this correct? (N/y)"
			while("y","n" -notcontains $continue )
			{
				$continue = Read-Host "Please enter your response (N/y)"
			}
			Switch ($continue) 
			{ 
				Y {Continue} 
				N {$UserEmail = Read-Host "Please input the username to log in with"} 
			} 
			$CredfileName = $UserEmail -replace "@","-" -replace "com","txt"
			if (!(Test-Path $env:USERPROFILE\Documents\$CredfileName)) {$password = Read-Host "Unable to find password file.  Please enter your password now: " -AsSecureString } else {$password = cat $env:USERPROFILE\Documents\$CredfileName | convertto-securestring}
			$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $CredfileName, $password

			# Log into Azure
			Write-Host "Logging into Azure with $CredfileName" -ForegroundColor Green
			[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
			Try {Login-AzureRmAccount -Credential $cred -ErrorAction SilentlyContinue | Out-Null}
			Catch {$ErrorMessage = $_;Break}
			if ($Environment -eq "Dev") {$selection = "a3750e25-9701-422d-a956-31d87d93f99e"}
			if ($Environment -eq "Stage") {$selection = "065491a8-6f4d-422e-a4db-429003ca9f6b"}
			if ($Environment -eq "Prod") {$selection = "065491a8-6f4d-422e-a4db-429003ca9f6b"}
			Select-AzureRmSubscription -SubscriptionName $selection | Out-Null
			# change window name
			$host.ui.RawUI.WindowTitle = $DeploymentName + " Script in " + $Environment
		}
		Finally {
			Write-Host "=> OK, you are all logged in and ready to go" -ForegroundColor Yellow
			Write-Host "=>" -ForegroundColor Yellow
		}
    } while (! $azureAccess)
    Write-Host "=> You are now Logged into Azure Resource Manager." -ForegroundColor Yellow
    Write-Host "=>" -ForegroundColor Yellow
}
#endregion

Write-Host "=> Beginning Azure Deployment Sequence for ASE App Service Infrastructure..." -ForegroundColor Yellow
Write-Host "=> Login to ARM if you are not already." -ForegroundColor Yellow

# Checking for network resource group, creating if does not exist
#region
Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Time to make sure the gremlins have not eaten your Resource Group already..." -ForegroundColor Yellow
if (!(Get-AzureRMResourceGroup -Name $RgName -ErrorAction SilentlyContinue))
{
    Write-Host "=>" -ForegroundColor Yellow
    Write-Host "=> Oh No!  They ate it...." -ForegroundColor Yellow
    Write-Host "=> I got this though... Making a new one for you!" -ForegroundColor Yellow
    New-AzureRmResourceGroup -Name $RgName -Location $Region | Out-Null
    Write-Host "=>" -ForegroundColor Yellow
    Write-Host "=> Resource Group $RgName now exists!" -ForegroundColor Yellow
}
else
{
    Write-Host "=>" -ForegroundColor Yellow
    Write-Host "=> Resource Group $RgName already exists." -ForegroundColor Yellow
}
#endregion

##GeneratePassword
Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Generating password for Azure SQL" -ForegroundColor Yellow

Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Deploying the ASE Blueprint..." -ForegroundColor Yellow

if ($Deployment -eq "Manual") {
	New-AzureRMResourceGroupDeployment -Name $DeploymentName `
		-ResourceGroupName $RgName `
		-TemplateFile $TemplateFile `
		-TemplateParameterFile $TemplateParameterFile `
		-SystemPrefixName $SystemPrefixName `
		-vnetAddressSpace $vnetAddressSpace `
		-WAFSubnetAddressSpace $WAFSubnetAddressSpace `
		-WebAppSubnetAddressSpace $WebAppSubnetAddressSpace `
		-BackendSubnetAddressSpace $BackendSubnetAddressSpace `
		-WebAppSubnetPrefix $vnetAddressPrefix `
		-Region $Region `
		-Mode Incremental `
		-Verbose
}

Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Man that was tense... Good thing we know some Kung-Fu or those fraggles might have been the end of the road..." -ForegroundColor Yellow

##Get Outputs from Deployment
Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Retrieving outputs from deployment $DeploymentName." -ForegroundColor Yellow

$VnetName = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $RgName -Name $DeploymentName).Outputs.vnetName.Value
$SqlName = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $RgName -Name $DeploymentName).Outputs.sqlName.Value
$AppGWName = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $RgName -Name $DeploymentName).Outputs.appGWName.Value

Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Creating Network Security Group Rules." -ForegroundColor Yellow
##WAF Rules
#region
  $WAFRule1 = New-AzureRmNetworkSecurityRuleConfig -Name DenyAllInbound -Description "Deny All Inbound" `
 -Access Deny -Protocol * -Direction Inbound -Priority 500 `
 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
 -DestinationPortRange *

  $WAFRule2 = New-AzureRmNetworkSecurityRuleConfig -Name HTTPS-In -Description "Allow Inbound HTTPS" `
 -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
 -SourceAddressPrefix Internet -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 443

  $WAFRule3 = New-AzureRmNetworkSecurityRuleConfig -Name HTTP-In -Description "Allow Inbound HTTP" `
 -Access Allow -Protocol Tcp -Direction Inbound -Priority 120 `
 -SourceAddressPrefix Internet -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 80
 
   $WAFRule4 = New-AzureRmNetworkSecurityRuleConfig -Name DNS-In -Description "Allow Inbound DNS" `
 -Access Allow -Protocol Tcp -Direction Inbound -Priority 130 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 53

  $WAFRule5 = New-AzureRmNetworkSecurityRuleConfig -Name DenyAllOutbound -Description "Deny All Outbound" `
 -Access Deny -Protocol * -Direction Outbound -Priority 500 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange *

  $WAFRule6 = New-AzureRmNetworkSecurityRuleConfig -Name HTTPS-Out -Description "Allow Outbound HTTPS" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 110 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 443

  $WAFRule7 = New-AzureRmNetworkSecurityRuleConfig -Name HTTP-Out -Description "Allow Outbound HTTP" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 120 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 80
 
   $WAFRule8 = New-AzureRmNetworkSecurityRuleConfig -Name DNS-Out -Description "Allow Outbound DNS" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 130 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 53

 #endregion

##ASE Rules
#region
  $ASERule1 = New-AzureRmNetworkSecurityRuleConfig -Name AllAllowInboundASEManagement -Description "Allows All Inbound ASE Management" `
 -Access Allow -Protocol * -Direction Inbound -Priority 100 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix Virtualnetwork -DestinationPortRange 454-455

  $ASERule2 = New-AzureRmNetworkSecurityRuleConfig -Name AllAllowOutboundASEManagement -Description "Allow Outbound ASE Management" `
 -Access Allow -Protocol * -Direction Outbound -Priority 100 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 445
 
  $ASERule3 = New-AzureRmNetworkSecurityRuleConfig -Name AllAllowOutboundDNS -Description "Allow Outbound DNS" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 120 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 53

   $ASERule4 = New-AzureRmNetworkSecurityRuleConfig -Name AllAllowOutboundHTTP -Description "Allow Outbound HTTP" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 130 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 80

   $ASERule5 = New-AzureRmNetworkSecurityRuleConfig -Name AllAllowOutboundHTTPS -Description "Allow Outbound HTTPS" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 140 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 443

  $ASERule6 = New-AzureRmNetworkSecurityRuleConfig -Name AllAllowSQL1 -Description "Allow SQL Connectivity" `
 -Access Allow -Protocol * -Direction Outbound -Priority 150 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 1433

  $ASERule7 = New-AzureRmNetworkSecurityRuleConfig -Name DenyAllOutbound `
 -Access Deny -Protocol * -Direction Outbound -Priority 500 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange *

  $ASERule8 = New-AzureRmNetworkSecurityRuleConfig -Name DenyAllInbound `
 -Access Deny -Protocol * -Direction Inbound -Priority 500 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange *
 
 #endregion

##BE Rules
#region
  $BERule1 = New-AzureRmNetworkSecurityRuleConfig -Name DenyAllInbound -Description "Deny All Inbound" `
 -Access Deny -Protocol * -Direction Inbound -Priority 500 `
 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
 -DestinationPortRange *

  $BERule2 = New-AzureRmNetworkSecurityRuleConfig -Name HTTPS-In -Description "Allow Inbound HTTPS" `
 -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
 -SourceAddressPrefix Internet -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 443

  $BERule3 = New-AzureRmNetworkSecurityRuleConfig -Name HTTP-In -Description "Allow Inbound HTTP" `
 -Access Allow -Protocol Tcp -Direction Inbound -Priority 120 `
 -SourceAddressPrefix Internet -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 80
 
   $BERule4 = New-AzureRmNetworkSecurityRuleConfig -Name DNS-In -Description "Allow Inbound DNS" `
 -Access Allow -Protocol Tcp -Direction Inbound -Priority 130 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 53

  $BERule5 = New-AzureRmNetworkSecurityRuleConfig -Name DenyAllOutbound -Description "Deny All Outbound" `
 -Access Deny -Protocol * -Direction Outbound -Priority 500 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange *

  $BERule6 = New-AzureRmNetworkSecurityRuleConfig -Name HTTPS-Out -Description "Allow Outbound HTTPS" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 110 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 443

  $BERule7 = New-AzureRmNetworkSecurityRuleConfig -Name HTTP-Out -Description "Allow Outbound HTTP" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 120 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 80
 
   $BERule8 = New-AzureRmNetworkSecurityRuleConfig -Name RDP-in -Description "Allow Inbound RDP" `
 -Access Allow -Protocol Tcp -Direction Outbound -Priority 140 `
 -SourceAddressPrefix * -SourcePortRange * `
 -DestinationAddressPrefix * -DestinationPortRange 3389

 #endregion

Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Building Network Security Groups" -ForegroundColor Yellow
##Build NSGs
#region
$WafNsg = New-AzureRmNetworkSecurityGroup -Name "WafNsg" -ResourceGroupName $RgName -Location $Region `
                                          -SecurityRules $WAFRule1,$WAFRule2,$WAFRule3,$WAFRule4,$WAFRule5,$WAFRule6,$WAFRule7,$WAFRule8 `
                                          -Force -WarningAction SilentlyContinue | out-null 
$AseWebNsg = New-AzureRmNetworkSecurityGroup -Name "AseWebNsg" -ResourceGroupName $RgName -Location $Region `
                                             -SecurityRules $ASERule1,$ASERule2,$ASERule3,$ASERule4,$ASERule5,$ASERule6,$ASERule7,$ASERule8 `
                                             -Force -WarningAction SilentlyContinue | Out-Null
$BENsg = New-AzureRmNetworkSecurityGroup -Name "BENsg" -ResourceGroupName $RgName -Location $Region `
                                             -SecurityRules $BERule1,$BERule2,$BERule3,$BERule4,$BERule5,$BERule6,$BERule7,$BERule8 `
                                             -Force -WarningAction SilentlyContinue | Out-Null
#endregion

Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Applying Network Security Groups to vNet, $VnetName " -ForegroundColor Yellow
##Apply NSGs to vNet
#region
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RgName -Name $VnetName
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $vnet.Subnets.name[0] `
                                      -AddressPrefix $vnet.Subnets.AddressPrefix[0]`
                                      -NetworkSecurityGroup $WafNSG  | Out-Null
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet  | Out-Null
 
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RgName -Name $VnetName
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $vnet.Subnets.name[1] `
                                      -AddressPrefix $vnet.Subnets.AddressPrefix[1]`
                                      -NetworkSecurityGroup $AseWebNSG  | Out-Null
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet  | Out-Null
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $RgName -Name $VnetName
Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $vnet.Subnets.name[2] `
                                      -AddressPrefix $vnet.Subnets.AddressPrefix[2]`
                                      -NetworkSecurityGroup $BENsg  | Out-Null
Set-AzureRmVirtualNetwork -VirtualNetwork $vnet  | Out-Null
#endregion

Write-Host "=>" -ForegroundColor Yellow
Write-Host "=>" -ForegroundColor Yellow
Write-Host "=> Deployment Complete!" -ForegroundColor Yellow
