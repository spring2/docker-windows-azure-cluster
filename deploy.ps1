$resourcegroup = "docker-swarm"
$vmname = "s2-docker-03"
$password = "1qaz@WSX3edc"
$location = "West US"
$username = "docker"

$deployment = $vmname

$params = @"
{ 
   "adminUsername":{ 
      "value":"$username" 
   }, 
   "adminPassword":{ 
      "value":"$password" 
   }, 
   "dnsNameForPublicIP":{ 
      "value":"$vmname" 
   }, 
   "VMName":{ 
      "value":"$vmname" 
   }, 
   "location":{ 
      "value":"$location" 
   } 
}
"@

#Write-Host $params

# set the S2 account as the active account
az account set --subscription 7dc55fb3-d94a-4503-8da9-acaf2019506d

az group create --name $resourcegroup --location $location

az --verbose group deployment create `
	--name $deployment `
	--resource-group $resourcegroup `
	--template-file azuredeploy.json `
	--parameters '@parameters.json'
	
#	--parameters $params

azure vm show $resourcegroup $deployment | grep "Public IP address" | cut -d : -f 3

azure vm show $resourcegroup $deployment | grep FQDN | cut -d : -f 3 | head -1


write-host "to delete: az group deployment delete --resource-group $resourcegroup --name $deployment"