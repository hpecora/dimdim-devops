$ErrorActionPreference = "Stop"

$resourceGroup = "rm556612-rg"
$location = "brazilsouth"

$acrName = "rm556612acr"
$loginServer = "rm556612acr.azurecr.io"

$storageAccount = "rm556612storage"
$fileShare = "pgdata"

$containerName = "rm556612-db-aci"
$dnsLabel = "rm556612-db-dimdim"

Write-Host "Preparando credenciais..."

# O usuario do banco deve existir apenas na sessao do PowerShell
$dbUser = $env:DIMDIM_DB_USER

if ([string]::IsNullOrWhiteSpace($dbUser)) {
    throw "Defina DIMDIM_DB_USER antes de executar este script."
}

# Gera uma senha forte para o banco apenas nesta sessao
if (-not $env:DIMDIM_DB_PASSWORD) {
    $env:DIMDIM_DB_PASSWORD = ([guid]::NewGuid().ToString("N") + "Aa1!")
    Write-Host "Senha do banco gerada para esta sessao."
}

$dbPassword = $env:DIMDIM_DB_PASSWORD

# Habilita credenciais administrativas do ACR
az acr update `
    --name $acrName `
    --admin-enabled true `
    --output none

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao habilitar acesso ao ACR."
}

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

Write-Host "Obtendo credencial da Conta de Armazenamento..."

$storageKey = az storage account keys list `
    --resource-group $resourceGroup `
    --account-name $storageAccount `
    --query "[0].value" `
    --output tsv

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao obter a credencial da Conta de Armazenamento."
}

Write-Host "Criando ACI do banco..."

az container create `
    --resource-group $resourceGroup `
    --name $containerName `
    --location $location `
    --image "$loginServer/rm556612-db:latest" `
    --registry-login-server $loginServer `
    --registry-username $acrUser `
    --registry-password $acrPassword `
    --os-type Linux `
    --ip-address Public `
    --dns-name-label $dnsLabel `
    --ports 5432 `
    --cpu 1 `
    --memory 1.5 `
    --environment-variables `
        "POSTGRES_USER=$dbUser" `
        "POSTGRES_DB=dimdimdb" `
    --secure-environment-variables `
        "POSTGRES_PASSWORD=$dbPassword" `
    --azure-file-volume-account-name $storageAccount `
    --azure-file-volume-account-key $storageKey `
    --azure-file-volume-share-name $fileShare `
    --azure-file-volume-mount-path "/backup" `
    --restart-policy Always `
    --output table

if ($LASTEXITCODE -ne 0) {
    throw "Falha ao criar o ACI do banco."
}

$fqdn = az container show `
    --resource-group $resourceGroup `
    --name $containerName `
    --query "ipAddress.fqdn" `
    --output tsv

$env:DIMDIM_DB_FQDN = $fqdn

Write-Host ""
Write-Host "ACI do banco criado com sucesso."
Write-Host "FQDN do banco: $fqdn"