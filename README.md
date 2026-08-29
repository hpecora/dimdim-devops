# DimDim DevOps - Containers em Nuvem

Projeto desenvolvido para o Checkpoint de DevOps Tools & Cloud Computing.

## Tecnologias utilizadas

- .NET 8
- PostgreSQL 16
- Docker
- Azure Container Registry (ACR)
- Azure Container Instances (ACI)
- Azure CLI

## Estrutura do projeto

- `Program.cs` - API REST com CRUD de clientes
- `Dockerfile` - imagem da aplicação .NET
- `database/Dockerfile` - imagem do PostgreSQL
- `database/ddl.sql` - criação da tabela `clientes`
- `tests/` - arquivos JSON utilizados nos testes

## Banco de dados

Tabela utilizada:

```sql
CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE
);