$ErrorActionPreference = "Stop"

$resourceGroup = "rm556612-rg"
$acrName = "rm556612acr"

Write-Host "Criando Azure Container Registry $acrName..."

az acr create `
    --resource-group $resourceGroup `
    --name $acrName `
    --sku Basic `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao criar o Azure Container Registry."
}

Write-Host "Azure Container Registry criado com sucesso."