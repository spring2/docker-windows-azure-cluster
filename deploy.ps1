$resourcegroup = "docker-swarm"
$vmname = "s2-docker-03"
$password = "1qaz@WSX3edc"
$location = "West US"
$username = "docker"
$storage = "dockerswarmstorage"
$container = "certs"
$vmSize = "Standard_F2"

$deployment = $vmname


# set the S2 account as the active account
az account set --subscription 7dc55fb3-d94a-4503-8da9-acaf2019506d

az group create --name $resourcegroup --location $location

az storage account create -n $storage -g $resourcegroup -l $location --sku Standard_LRS --kind BlobStorage --access-tier Cool

az storage container create --name $container --account-name $storage

echo "Uploading the file..."
#az storage blob upload --account-name $storage --container-name $container --file $file_to_upload --name $blob_name

echo "Listing the blobs..."
az storage blob list --account-name $storage --container-name $container --output table

az --verbose group deployment create `
	--name $deployment `
	--resource-group $resourcegroup `
	--template-file azuredeploy.json `
	--parameters '@parameters.json'

azure vm show $resourcegroup $deployment | grep "Public IP address" | cut -d : -f 3

azure vm show $resourcegroup $deployment | grep FQDN | cut -d : -f 3 | head -1

azure vm show $resourcegroup s2-consul-01 | grep "Public IP address" | cut -d : -f 3

azure vm show $resourcegroup s2-consul-01 | grep FQDN | cut -d : -f 3 | head -1

write-host "to delete: az group deployment delete --resource-group $resourcegroup --name $deployment"