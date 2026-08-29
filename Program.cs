using Npgsql;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING");

if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "A variável CONNECTION_STRING não foi configurada."
    );
}

// Página inicial
app.MapGet("/", () => Results.Ok(new
{
    mensagem = "DimDim API funcionando!"
}));

// READ - listar clientes
app.MapGet("/clientes", async () =>
{
    var clientes = new List<Cliente>();

    await using var connection = new NpgsqlConnection(connectionString);
    await connection.OpenAsync();

    await using var command = new NpgsqlCommand(
        "SELECT id, nome, email FROM clientes ORDER BY id",
        connection
    );

    await using var reader = await command.ExecuteReaderAsync();

    while (await reader.ReadAsync())
    {
        clientes.Add(new Cliente(
            reader.GetInt32(0),
            reader.GetString(1),
            reader.GetString(2)
        ));
    }

    return Results.Ok(clientes);
});

// READ - buscar cliente por ID
app.MapGet("/clientes/{id:int}", async (int id) =>
{
    await using var connection = new NpgsqlConnection(connectionString);
    await connection.OpenAsync();

    await using var command = new NpgsqlCommand(
        "SELECT id, nome, email FROM clientes WHERE id = @id",
        connection
    );

    command.Parameters.AddWithValue("id", id);

    await using var reader = await command.ExecuteReaderAsync();

    if (!await reader.ReadAsync())
        return Results.NotFound();

    var cliente = new Cliente(
        reader.GetInt32(0),
        reader.GetString(1),
        reader.GetString(2)
    );

    return Results.Ok(cliente);
});

// CREATE
app.MapPost("/clientes", async (ClienteRequest cliente) =>
{
    await using var connection = new NpgsqlConnection(connectionString);
    await connection.OpenAsync();

    await using var command = new NpgsqlCommand(
        """
        INSERT INTO clientes (nome, email)
        VALUES (@nome, @email)
        RETURNING id
        """,
        connection
    );

    command.Parameters.AddWithValue("nome", cliente.Nome);
    command.Parameters.AddWithValue("email", cliente.Email);

    var id = (int)(await command.ExecuteScalarAsync())!;

    return Results.Created(
        $"/clientes/{id}",
        new Cliente(id, cliente.Nome, cliente.Email)
    );
});

// UPDATE
app.MapPut("/clientes/{id:int}", async (int id, ClienteRequest cliente) =>
{
    await using var connection = new NpgsqlConnection(connectionString);
    await connection.OpenAsync();

    await using var command = new NpgsqlCommand(
        """
        UPDATE clientes
        SET nome = @nome,
            email = @email
        WHERE id = @id
        """,
        connection
    );

    command.Parameters.AddWithValue("id", id);
    command.Parameters.AddWithValue("nome", cliente.Nome);
    command.Parameters.AddWithValue("email", cliente.Email);

    var linhas = await command.ExecuteNonQueryAsync();

    if (linhas == 0)
        return Results.NotFound();

    return Results.Ok(new Cliente(id, cliente.Nome, cliente.Email));
});

// DELETE
app.MapDelete("/clientes/{id:int}", async (int id) =>
{
    await using var connection = new NpgsqlConnection(connectionString);
    await connection.OpenAsync();

    await using var command = new NpgsqlCommand(
        "DELETE FROM clientes WHERE id = @id",
        connection
    );

    command.Parameters.AddWithValue("id", id);

    var linhas = await command.ExecuteNonQueryAsync();

    if (linhas == 0)
        return Results.NotFound();

    return Results.NoContent();
});

app.Run();

record Cliente(int Id, string Nome, string Email);

record ClienteRequest(string Nome, string Email);