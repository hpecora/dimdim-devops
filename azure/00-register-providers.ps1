$ErrorActionPreference = "Stop"

function Register-AzureProvider {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Namespace
    )

    Write-Host ""
    Write-Host "Verificando $Namespace..."

    $status = az provider show `
        --namespace $Namespace `
        --query "registrationState" `
        --output tsv

    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao consultar o provider $Namespace."
    }

    if ($status -eq "Registered") {
        Write-Host "$Namespace ja esta registrado."
        return
    }

    Write-Host "Registrando $Namespace..."

    az provider register --namespace $Namespace

    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao solicitar o registro de $Namespace."
    }

    Write-Host "Aguardando o registro ser concluido..."

    do {
        $status = az provider show `
            --namespace $Namespace `
            --query "registrationState" `
            --output tsv

        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao consultar o status de $Namespace."
        }

        Write-Host "Status $Namespace : $status"

        if ($status -ne "Registered") {
            Start-Sleep -Seconds 5
        }

    } while ($status -ne "Registered")

    Write-Host "$Namespace registrado com sucesso."
}

Register-AzureProvider -Namespace "Microsoft.ContainerRegistry"
Register-AzureProvider -Namespace "Microsoft.ContainerInstance"
Register-AzureProvider -Namespace "Microsoft.Network"

Write-Host ""
Write-Host "Todos os providers necessarios estao registrados."