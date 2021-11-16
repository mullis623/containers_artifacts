1. Run local SQL server:
docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=Password123!" -p 1433:1433 --name sqlserver -d mcr.microsoft.com/mssql/server:2017-latest

2. Build POI docker container locally
docker build -f ../../dockerfiles/Dockerfile_3 -t "tripinsights/poi:1.0" .

3. connect to local SQL server to create database:
sudo docker exec -it sqlserver "bash"
/opt/mssql-tools/bin/sqlcmd -S localhost -U SA -P "Password123!"

create database mydrivingDB
SELECT Name from sys.Databases
go

4. load sample data into local db:
docker run --network host -e SQLFQDN=localhost -e SQLUSER=sa -e SQLPASS=Password123! -e SQLDB=myDrivingDB registryxyo7426.azurecr.io/dataload:1.0

5. run app locally, connected to local DB 

docker run -d -p 8080:80 --name poi -e SQL_SERVER=172.17.0.2 -e SQL_USER=SA -e SQL_PASSWORD=Password123! -e ASPNETCORE_ENVIRONMENT="Local" tripinsights/poi:1.0

6. connect to local app, test app connection to DB 

curl -i -X GET 'http://localhost:8080/api/poi'
