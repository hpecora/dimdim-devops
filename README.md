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

As imagens Docker são construídas localmente e publicadas no Azure Container Registry.

Na nuvem, cada imagem é executada em um Azure Container Instance:

- `rm556612-app-aci` - aplicação .NET
- `rm556612-db-aci` - banco PostgreSQL

A persistência dos dados é realizada por meio de backup e restauração automática utilizando Azure Files.

## Estrutura do projeto

- `Program.cs` - API REST com CRUD de clientes
- `Dockerfile` - imagem Docker da aplicação .NET
- `database/Dockerfile` - imagem Docker do PostgreSQL
- `database/ddl.sql` - DDL da tabela `clientes`
- `database/azure-entrypoint.sh` - rotina automática de backup e restauração
- `tests/` - arquivos JSON utilizados nos testes da API
- `azure/` - scripts Azure CLI para criação da infraestrutura

## Scripts Azure

Os recursos de nuvem são criados via Azure CLI pelos seguintes scripts:

- `azure/00-register-providers.ps1`
- `azure/01-resource-group.ps1`
- `azure/02-acr.ps1`
- `azure/03-storage.ps1`
- `azure/04-db-aci.ps1`
- `azure/05-app-aci.ps1`

## Banco de dados

Banco utilizado: **PostgreSQL 16**

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

## 3. Verificar as imagens

```bash
docker images
```

## 4. Criar a rede Docker

```bash
docker network create dimdim-net
```

## 5. Executar o banco

Exemplo:

```bash
docker run --name dimdim-db-test \
  --network dimdim-net \
  -e POSTGRES_USER=<DB_USER> \
  -e POSTGRES_PASSWORD=<SENHA_LOCAL> \
  -e POSTGRES_DB=dimdimdb \
  -p 5433:5432 \
  -d dimdim-db:latest
```

## 6. Executar a aplicação

```bash
docker run --name dimdim-app-test \
  --network dimdim-net \
  -e "CONNECTION_STRING=Host=dimdim-db-test;Port=5432;Database=dimdimdb;Username=<DB_USER>;Password=<SENHA_LOCAL>" \
  -p 8080:8080 \
  -d dimdim-app:latest
```

## 7. Verificar os containers

```bash
docker ps
```

## 8. Verificar o usuário da aplicação

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

A API disponibiliza as quatro operações do CRUD para a tabela `clientes`.

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

## Arquivos JSON de teste

Os arquivos utilizados nos testes estão no diretório `tests/`:

```text
tests/get.json
tests/post.json
tests/put.json
tests/delete.json
```

---

# Validação local no PostgreSQL

Para acessar diretamente o banco local:

```bash
docker exec -it dimdim-db-test psql -U <DB_USER> -d dimdimdb
```

Listar as tabelas:

```sql
\dt
```

Visualizar a estrutura da tabela:

```sql
\d clientes
```

Consultar os dados:

```sql
SELECT * FROM clientes;
```

As operações CREATE, READ, UPDATE e DELETE devem ser confirmadas por SELECT diretamente no PostgreSQL.

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

Registry:

```text
rm556612acr.azurecr.io
```

## 5. Login no ACR

```powershell
az acr login --name rm556612acr
```

## 6. Criar as tags das imagens

Aplicação:

```powershell
docker tag dimdim-app:latest rm556612acr.azurecr.io/rm556612-app:latest
```

Banco:

```powershell
docker tag dimdim-db:latest rm556612acr.azurecr.io/rm556612-db:latest
```

## 7. Push das imagens para o ACR

Aplicação:

```powershell
docker push rm556612acr.azurecr.io/rm556612-app:latest
```

Banco:

```powershell
docker push rm556612acr.azurecr.io/rm556612-db:latest
```

## 8. Conferir as imagens no ACR

```powershell
az acr repository list `
  --name rm556612acr `
  --output table
```

Repositórios esperados:

```text
rm556612-app
rm556612-db
```

## 9. Criar Storage Account e Azure File Share

```powershell
.\azure\03-storage.ps1
```

Recursos:

```text
Storage Account: rm556612storage
File Share: pgdata
```

## 10. Configurar a sessão

Antes de criar os containers, defina o usuário do banco apenas na sessão atual do PowerShell:

```powershell
$env:DIMDIM_DB_USER = "<DB_USER>"
```

O valor não é armazenado diretamente nos scripts.

## 11. Criar o ACI do banco

```powershell
.\azure\04-db-aci.ps1
```

ACI:

```text
rm556612-db-aci
```

Durante a execução, uma senha forte para o PostgreSQL é gerada automaticamente e armazenada apenas na variável de ambiente da sessão:

```text
DIMDIM_DB_PASSWORD
```

O usuário é obtido da variável:

```text
DIMDIM_DB_USER
```

Nenhuma senha ou chave é escrita diretamente no código-fonte.

## 12. Criar o ACI da aplicação

Na mesma sessão do PowerShell:

```powershell
.\azure\05-app-aci.ps1
```

O script utiliza as variáveis da sessão para construir de forma segura a conexão da aplicação com o PostgreSQL.

ACI:

```text
rm556612-app-aci
```

Endpoint:

```text
http://rm556612-app-dimdim.brazilsouth.azurecontainer.io:8080
```

---

# Recursos criados na Azure

Os principais recursos são:

```text
Resource Group:
rm556612-rg

Azure Container Registry:
rm556612acr

Azure Container Instance - App:
rm556612-app-aci

Azure Container Instance - Banco:
rm556612-db-aci

Storage Account:
rm556612storage

Azure File Share:
pgdata
```

---

# Testes na Azure

Todos os testes abaixo utilizam o endpoint em nuvem do Azure Container Instance da aplicação.

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

Substitua `<ID>` pelo ID retornado no POST:

```powershell
Invoke-RestMethod `
  -Uri "http://rm556612-app-dimdim.brazilsouth.azurecontainer.io:8080/clientes/<ID>" `
  -Method Put `
  -ContentType "application/json" `
  -Body (Get-Content .\tests\put.json -Raw)
```

## DELETE

```powershell
Invoke-RestMethod `
  -Uri "http://rm556612-app-dimdim.brazilsouth.azurecontainer.io:8080/clientes/<ID>" `
  -Method Delete
```

---

# Evidências diretamente no banco da Azure

As operações realizadas pela API podem ser comprovadas diretamente no PostgreSQL em execução no ACI.

Antes dos comandos:

```powershell
$dbUser = $env:DIMDIM_DB_USER
```

## Listar tabelas

```powershell
az container exec `
  --resource-group rm556612-rg `
  --name rm556612-db-aci `
  --exec-command "psql -U $dbUser -d dimdimdb -c '\dt'"
```

## Consultar os registros

```powershell
az container exec `
  --resource-group rm556612-rg `
  --name rm556612-db-aci `
  --exec-command "psql -U $dbUser -d dimdimdb -c 'SELECT * FROM clientes;'"
```

A demonstração do CRUD deve apresentar individualmente:

```text
POST   -> SELECT
GET    -> SELECT
PUT    -> SELECT
DELETE -> SELECT
```

Dessa forma, cada operação realizada pela API é comprovada diretamente no banco PostgreSQL.

---

# Persistência

O PostgreSQL utiliza o Azure File Share `pgdata` para armazenar backups automáticos.

Arquivo persistido:

```text
clientes-data.sql
```

O script:

```text
database/azure-entrypoint.sh
```

executa periodicamente `pg_dump` e grava o backup no Azure Files.

Quando um novo container de banco é criado, o backup existente é utilizado para restaurar os dados.

A persistência foi validada pelo seguinte processo:

1. Inclusão de um registro no PostgreSQL.
2. Confirmação do registro por SELECT.
3. Confirmação do registro no arquivo `clientes-data.sql` no Azure Files.
4. Exclusão do Azure Container Instance do banco.
5. Criação de um novo Azure Container Instance.
6. Restauração automática do backup.
7. Novo SELECT confirmando que o registro continuava disponível.

---

# Segurança

Nenhuma senha, token ou chave da Azure é armazenada diretamente no repositório.

O usuário do banco é fornecido em tempo de execução através da variável:

```text
DIMDIM_DB_USER
```

A senha do banco é gerada e armazenada apenas na sessão através da variável:

```text
DIMDIM_DB_PASSWORD
```

Valores sensíveis são enviados ao Azure Container Instance utilizando `--secure-environment-variables`.

O container da aplicação executa com usuário sem privilégios administrativos:

```dockerfile
USER app
```

Assim, a aplicação não executa como root/admin.