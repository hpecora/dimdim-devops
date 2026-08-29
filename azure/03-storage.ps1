$ErrorActionPreference = "Stop"

$resourceGroup = "rm556612-rg"
$location = "brazilsouth"
$storageAccount = "rm556612storage"
$fileShare = "pgdata"

Write-Host "Criando Storage Account $storageAccount..."

az storage account create `
    --name $storageAccount `
    --resource-group $resourceGroup `
    --location $location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --https-only true `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao criar a Storage Account."
}

Write-Host "Criando File Share $fileShare..."

az storage share-rm create `
    --resource-group $resourceGroup `
    --storage-account $storageAccount `
    --name $fileShare `
    --quota 5 `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao criar o File Share."
}

Write-Host "Storage Account e File Share criados com sucesso."