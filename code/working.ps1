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


Challenge 5:

Key Vault Integration Steps (https://docs.microsoft.com/en-us/azure/aks/csi-secrets-store-driver):
1. Enable Key Vault Add On: az aks enable-addons --addons azure-keyvault-secrets-provider -n $cluster -g $rg

2. Create Key Vault and add required secrets (SQLUSER, SQLPASSWORD, SQLSERVER, SQLDBNAME) 

3. Create AAD Pod Identity (https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity)
    az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService
    az aks update -g $rg -n $cluster --enable-pod-identity

    $IDENTITY_NAME="app-identity"
    az identity create --resource-group $rg --name $IDENTITY_NAME
    $IDENTITY_CLIENT_ID=$(az identity show -g $rg -n $IDENTITY_NAME --query clientId -otsv)
    $IDENTITY_RESOURCE_ID=$(az identity show -g $rg -n $IDENTITY_NAME --query id -otsv)

    $NODE_GROUP=$(az aks show -g $rg -n $cluster --query nodeResourceGroup -o tsv)
    $NODES_RESOURCE_ID=$(az group show -n $NODE_GROUP -o tsv --query "id")
    az role assignment create --role "Virtual Machine Contributor" --assignee "$IDENTITY_CLIENT_ID" --scope $NODES_RESOURCE_ID


    $POD_IDENTITY_NAME="t1hack-pod-identity"
    $POD_IDENTITY_NAMESPACE="api"
    az aks pod-identity add --resource-group $rg --cluster-name $cluster --namespace $POD_IDENTITY_NAMESPACE --name $POD_IDENTITY_NAME --identity-resource-id $IDENTITY_RESOURCE_ID

4. Create SecretProviderClass - /kubernetes/secretproviderclass.yml
    Need to map KV Secrets to Kubernetes secrets for aliasing (SQLUSER to SQL_USER) since KV Secrets do not allow "_" - K8S Secrets mapping is in the top section, the Azure Key Vault mappings are in the bottom section

5. Update YAML definition for each api service to use the secretproviderclass created in 4 by using a volume mount and referencing the K8S secrets as Env Variables. 
    **Note** aadpodidbinding label should be under template and not directly under the Deployment

6. Reapply YAML defintion to cluster for all api services. 
