# DimDim DevOps - Containers em Nuvem

Projeto desenvolvido para o Checkpoint de DevOps Tools & Cloud Computing.

RM do representante: **556612**

## Tecnologias utilizadas

- .NET 8
- PostgreSQL 16
- Docker
- Azure CLI
- Azure Container Registry (ACR)
- Azure Container Instances (ACI)
- Azure Storage Account / Azure Files

## Arquitetura

A solução utiliza dois containers:

- **App:** API REST desenvolvida em .NET 8
- **Banco:** PostgreSQL 16

Na Azure, as imagens são armazenadas no Azure Container Registry e executadas em dois Azure Container Instances.

A persistência do banco é realizada por meio de backup e restauração automática utilizando Azure Files.

## Estrutura do projeto

- `Program.cs` - API REST com CRUD de clientes
- `Dockerfile` - imagem Docker da aplicação
- `database/Dockerfile` - imagem Docker do PostgreSQL
- `database/ddl.sql` - DDL da tabela `clientes`
- `database/azure-entrypoint.sh` - rotina de backup e restauração
- `tests/` - arquivos JSON utilizados nos testes
- `azure/` - scripts de criação dos recursos Azure via CLI

## Banco de dados

Tabela utilizada:

```sql
CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE
);
```

---

# Execução local

## 1. Build da imagem do banco

```bash
docker build -t dimdim-db:latest ./database
```

## 2. Build da imagem da aplicação

```bash
docker build -t dimdim-app:latest .
```

## 3. Verificar imagens

```bash
docker images
```

## 4. Criar rede Docker

```bash
docker network create dimdim-net
```

## 5. Executar o banco

Exemplo para ambiente local:

```bash
docker run --name dimdim-db-test \
  --network dimdim-net \
  -e POSTGRES_USER=dimdim \
  -e POSTGRES_PASSWORD=<SENHA_LOCAL> \
  -e POSTGRES_DB=dimdimdb \
  -p 5433:5432 \
  -d dimdim-db:latest
```

## 6. Executar a aplicação

```bash
docker run --name dimdim-app-test \
  --network dimdim-net \
  -e "CONNECTION_STRING=Host=dimdim-db-test;Port=5432;Database=dimdimdb;Username=dimdim;Password=<SENHA_LOCAL>" \
  -p 8080:8080 \
  -d dimdim-app:latest
```

## 7. Verificar containers

```bash
docker ps
```

## 8. Verificar usuário da aplicação

O container da aplicação não executa como root/admin:

```bash
docker exec dimdim-app-test whoami
```

Resultado esperado:

```text
app
```

---

# CRUD

Endpoints disponíveis:

## GET

```http
GET /clientes
```

## GET por ID

```http
GET /clientes/{id}
```

## POST

```http
POST /clientes
```

Exemplo:

```json
{
  "nome": "Joao",
  "email": "joao@email.com"
}
```

## PUT

```http
PUT /clientes/{id}
```

Exemplo:

```json
{
  "nome": "Joao Silva",
  "email": "joao.silva@email.com"
}
```

## DELETE

```http
DELETE /clientes/{id}
```

---

# Validação diretamente no PostgreSQL

Para acessar o banco local:

```bash
docker exec -it dimdim-db-test psql -U dimdim -d dimdimdb
```

Consultar os dados:

```sql
SELECT * FROM clientes;
```

As operações CREATE, READ, UPDATE e DELETE devem ser validadas por SELECT diretamente no banco.

---

# Deploy na Azure

## 1. Login

```powershell
az login
```

## 2. Registrar providers necessários

```powershell
.\azure\00-register-providers.ps1
```

Providers utilizados:

- `Microsoft.ContainerRegistry`
- `Microsoft.ContainerInstance`
- `Microsoft.Network`

## 3. Criar Resource Group

```powershell
.\azure\01-resource-group.ps1
```

Resource Group:

```text
rm556612-rg
```

Região:

```text
brazilsouth
```

## 4. Criar Azure Container Registry

```powershell
.\azure\02-acr.ps1
```

Registry utilizado:

```text
rm556612acr.azurecr.io
```

## 5. Login no ACR

```powershell
az acr login --name rm556612acr
```

## 6. Criar tags das imagens

Aplicação:

```powershell
docker tag dimdim-app:latest rm556612acr.azurecr.io/rm556612-app:latest
```

Banco:

```powershell
docker tag dimdim-db:latest rm556612acr.azurecr.io/rm556612-db:latest
```

## 7. Push das imagens

Aplicação:

```powershell
docker push rm556612acr.azurecr.io/rm556612-app:latest
```

Banco:

```powershell
docker push rm556612acr.azurecr.io/rm556612-db:latest
```

## 8. Conferir imagens no ACR

```powershell
az acr repository list --name rm556612acr --output table
```

Repositórios esperados:

```text
rm556612-app
rm556612-db
```

## 9. Criar Storage Account e File Share

```powershell
.\azure\03-storage.ps1
```

Recursos:

```text
Storage Account: rm556612storage
File Share: pgdata
```

## 10. Criar ACI do banco

```powershell
.\azure\04-db-aci.ps1
```

ACI:

```text
rm556612-db-aci
```

Durante a execução é criada uma senha para o PostgreSQL na variável de ambiente da sessão:

```text
DIMDIM_DB_PASSWORD
```

A senha não é armazenada no código-fonte.

## 11. Criar ACI da aplicação

Execute na mesma sessão do PowerShell usada para criar o banco:

```powershell
.\azure\05-app-aci.ps1
```

ACI:

```text
rm556612-app-aci
```

Endpoint da aplicação:

```text
http://rm556612-app-dimdim.brazilsouth.azurecontainer.io:8080
```

---

# Testes na Azure

## GET

```powershell
Invoke-RestMethod `
  -Uri "http://rm556612-app-dimdim.brazilsouth.azurecontainer.io:8080/clientes" `
  -Method Get
```

## POST

```powershell
Invoke-RestMethod `
  -Uri "http://rm556612-app-dimdim.brazilsouth.azurecontainer.io:8080/clientes" `
  -Method Post `
  -ContentType "application/json" `
  -Body (Get-Content .\tests\post.json -Raw)
```

## PUT

```powershell
Invoke-RestMethod `
  -Uri "http://rm556612-app-dimdim.brazilsouth.azurecontainer.io:8080/clientes/1" `
  -Method Put `
  -ContentType "application/json" `
  -Body (Get-Content .\tests\put.json -Raw)
```

## DELETE

```powershell
Invoke-RestMethod `
  -Uri "http://rm556612-app-dimdim.brazilsouth.azurecontainer.io:8080/clientes/1" `
  -Method Delete
```

---

# Evidência diretamente no banco da Azure

Obter o IP atual do banco:

```powershell
az container show `
  --resource-group rm556612-rg `
  --name rm556612-db-aci `
  --query "ipAddress.ip" `
  --output tsv
```

Executar SELECT diretamente no PostgreSQL:

```powershell
docker run --rm `
  -e "PGPASSWORD=$env:DIMDIM_DB_PASSWORD" `
  postgres:16 `
  psql `
  -h <IP_ATUAL_DO_BANCO> `
  -p 5432 `
  -U dimdim `
  -d dimdimdb `
  -c "SELECT * FROM clientes;"
```

---

# Persistência

O container do PostgreSQL utiliza o Azure File Share `pgdata` para armazenar backups automáticos.

Arquivo utilizado:

```text
clientes-data.sql
```

O script:

```text
database/azure-entrypoint.sh
```

executa periodicamente `pg_dump` e grava o backup no Azure Files.

Ao criar novamente o ACI do banco, o backup existente é usado para restaurar os dados.

A persistência foi validada com o seguinte processo:

1. Inclusão de um registro no banco.
2. Confirmação do registro via SELECT.
3. Confirmação do registro dentro de `clientes-data.sql` no Azure Files.
4. Exclusão completa do ACI do banco.
5. Criação de um novo ACI do banco.
6. Restauração automática do arquivo persistido.
7. Novo SELECT confirmando que o registro continuava disponível.

---

# Segurança

Nenhuma senha, token ou chave da Azure é armazenada diretamente no repositório.

As credenciais são obtidas durante a execução dos scripts e armazenadas apenas em variáveis da sessão.

O container da aplicação também executa como usuário sem privilégios administrativos:

```dockerfile
USER app
```