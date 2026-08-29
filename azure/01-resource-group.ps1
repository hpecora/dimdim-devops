$ErrorActionPreference = "Stop"

$resourceGroup = "rm556612-rg"
$location = "brazilsouth"

Write-Host "Criando Resource Group $resourceGroup..."

az group create `
    --name $resourceGroup `
    --location $location `
    --output table

Write-Host "Resource Group criado com sucesso."