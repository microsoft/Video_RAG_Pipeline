from datetime import datetime, timedelta, timezone

import asyncio
import aiohttp
from azure.core.credentials import AzureNamedKeyCredential
from azure.storage.blob.aio import BlobServiceClient
from azure.storage.blob import BlobSasPermissions, generate_blob_sas

class AzureBlobFileUploadService():

    def __init__(
        self,
        storage_account_name: str,
        storage_container_name: str, 
        credential: any,
    ):
        self.storage_account_name = storage_account_name
        self.storage_container_name = storage_container_name
        self.credential = credential

    async def upload_to_azure_blob(
        self,
        file_path: str,
        blob_name: str,
    ) -> str:
        """
        Uploads a local file to Azure Blob Storage and returns its SAS URL.

        :param file_path: Path to the local file to upload
        :param storage_account_name: Name of the Azure storage account
        :param storage_container_name: Name of the container within the storage account
        :param blob_name: Name to assign to the blob in storage
        :return: SAS URL of the uploaded blob
        """
        account_url = f"https://{self.storage_account_name}.blob.core.windows.net"  # Base URL for the storage account

        # Initialize the BlobServiceClient with the account URL and credentials
        async with BlobServiceClient(account_url=account_url, credential=self.credential) as blob_service_client:
            # Get the BlobClient for the specific blob
            async with blob_service_client.get_blob_client(
                container=self.storage_container_name,
                blob=blob_name) as blob_client:
                with open(file_path, "rb") as data:
                    await blob_client.upload_blob(data, overwrite=True)  # Upload the file, overwriting if it exists

        # Generate and return the SAS URL for the uploaded blob
        blob_url = await self.generate_blob_url(
            blob_name=blob_name,
        )

        return blob_url
    
    async def upload_from_url_to_azure_blob(
        self,
        source_url: str,
        blob_name: str,
        max_polling_attempts: int = 60,
        polling_interval: int = 5,
        timeout: int = 300
    ) -> str:
        """
        Downloads content from a URL and uploads it to Azure Blob Storage, then returns its SAS URL.

        :param source_url: URL of the content to download and upload
        :param blob_name: Name to assign to the blob in storage
        :return: SAS URL of the uploaded blob
        """
        
        account_url = f"https://{self.storage_account_name}.blob.core.windows.net"
    
        # Initialize the BlobServiceClient with the account URL and credentials
        async with BlobServiceClient(account_url=account_url, credential=self.credential, connection_timeout=timeout) as blob_service_client:
            # Get the BlobClient for the specific blob
            async with blob_service_client.get_blob_client(container=self.storage_container_name, blob=blob_name) as blob_client:
                # Start the copy operation
                await blob_client.upload_blob_from_url(source_url, overwrite=True)
        
        # Generate and return the SAS URL for the uploaded blob
        sas_url = await self.generate_blob_url(blob_name=blob_name)
        await asyncio.sleep(5) # Prevent a race condition between SAS creation and activation
        return sas_url

    async def generate_blob_url(
        self,
        blob_name: str,
    ) -> str:
        """
        Generates a SAS (Shared Access Signature) URL for a blob in Azure Blob Storage.

        :param blob_name: Name of the blob (file) for which to generate the URL
        :return: SAS URL for accessing the blob
        """
        delegation_key_start_time = datetime.now(timezone.utc)  # Current UTC time
        delegation_key_expiry_time = delegation_key_start_time + timedelta(days=1)  # Key valid for 1 day
        permissions = BlobSasPermissions(read=True)  # Permission to read the blob
        expiry_time = datetime.now(timezone.utc) + timedelta(hours=1)  # SAS token valid for 1 hour
        account_url = f"https://{self.storage_account_name}.blob.core.windows.net"  # Base URL for the storage account

        # Initialize the BlobServiceClient with the account URL and credentials
        async with BlobServiceClient(account_url=account_url, credential=self.credential) as blob_service_client:
            # Retrieve a user delegation key for generating the SAS token
            user_delegation_key = await blob_service_client.get_user_delegation_key(
                key_start_time=delegation_key_start_time,
                key_expiry_time=delegation_key_expiry_time,
            )

            # Generate the SAS token with the specified permissions and expiry
            sas_token = generate_blob_sas(
                account_name=self.storage_account_name,
                container_name=self.storage_container_name,
                blob_name=blob_name,
                user_delegation_key=user_delegation_key,
                permission=permissions,
                expiry=expiry_time,
            )

                # Construct the full blob URL with the SAS token
        blob_url_with_sas = f'{account_url}/{self.storage_container_name}/{blob_name}?{sas_token}'

        return blob_url_with_sas

    async def delete_blob(
        self,
        blob_name: str,
    ) -> None:
        """
        Deletes a blob from Azure Blob Storage.

        :param blob_name: Name of the blob to delete
        """
        account_url = f"https://{self.storage_account_name}.blob.core.windows.net"

        # Initialize the BlobServiceClient with the account URL and credentials
        async with BlobServiceClient(account_url=account_url, credential=self.credential) as blob_service_client:
            # Get the BlobClient for the specific blob
            async with blob_service_client.get_container_client(container=self.storage_container_name) as container_client:
                await container_client.delete_blob(blob=blob_name)  # Delete the blob from storage

