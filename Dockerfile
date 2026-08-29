FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY DimDim.Api.csproj .
RUN dotnet restore DimDim.Api.csproj

COPY . .
RUN dotnet publish DimDim.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

USER app

ENTRYPOINT ["dotnet", "DimDim.Api.dll"]