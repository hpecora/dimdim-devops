$ErrorActionPreference = "Stop"

$resourceGroup = "rm556612-rg"
$location = "brazilsouth"

$acrName = "rm556612acr"
$loginServer = "rm556612acr.azurecr.io"

$containerName = "rm556612-app-aci"
$dnsLabel = "rm556612-app-dimdim"

$dbHost = "rm556612-db-dimdim.brazilsouth.azurecontainer.io"

if (-not $env:DIMDIM_DB_PASSWORD) {
    throw "A variavel DIMDIM_DB_PASSWORD nao existe nesta sessao."
}

$dbPassword = $env:DIMDIM_DB_PASSWORD

Write-Host "Obtendo credenciais do ACR..."

$acrUser = az acr credential show `
    --name $acrName `
    --query "username" `
    --output tsv

$acrPassword = az acr credential show `
    --name $acrName `
    --query "passwords[0].value" `
    --output tsv

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao obter credenciais do ACR."
}

$connectionString = "Host=$dbHost;Port=5432;Database=dimdimdb;Username=dimdim;Password=$dbPassword"

Write-Host "Criando ACI da aplicacao..."

az container create `
    --resource-group $resourceGroup `
    --name $containerName `
    --location $location `
    --image "$loginServer/rm556612-app:latest" `
    --registry-login-server $loginServer `
    --registry-username $acrUser `
    --registry-password $acrPassword `
    --os-type Linux `
    --ip-address Public `
    --dns-name-label $dnsLabel `
    --ports 8080 `
    --cpu 1 `
    --memory 1.5 `
    --secure-environment-variables `
        "CONNECTION_STRING=$connectionString" `
    --restart-policy Always `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao criar o ACI da aplicacao."
}

$fqdn = az container show `
    --resource-group $resourceGroup `
    --name $containerName `
    --query "ipAddress.fqdn" `
    --output tsv

Write-Host ""
Write-Host "ACI da aplicacao criado com sucesso."
Write-Host "FQDN da aplicacao: $fqdn"
Write-Host "Endpoint: http://${fqdn}:8080/clientes"