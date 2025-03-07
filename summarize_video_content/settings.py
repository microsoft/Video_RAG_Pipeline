import logging
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class AppSettings(BaseSettings):
    """
    AppSettings manages the configuration settings for the application.
    It loads environment variables and provides them as strongly-typed attributes.

    Attributes:
        service_bus_namespace (str):
            The fully qualified namespace for Azure Service Bus.

        finalize_content_queue (str):
            The name of the Service Bus queue used to finalize content processing.

        video_summary_queue (str):
            The name of the Service Bus queue used for video summary tasks.

        cognitive_services_endpoint (str):
            The endpoint URL for Azure Cognitive Services API.

        azure_openai_endpoint (str):
            The endpoint URL for Azure OpenAI Service.

        azure_openai_api_version (str):
            The API version for Azure OpenAI Service.

        azure_openai_model_name (str):
            The name of the model used in Azure OpenAI Service.

        content_understanding_endpoint (str):
            The endpoint URL for the Content Understanding API.

        content_understanding_api_version (str):
            The API version for the Content Understanding API.

        content_understanding_key (str):
            The subscription key for authenticating with the Content Understanding API.

        video_analyzer_name (str):
            The name of the video analyzer used for processing videos.

        storage_account_name (str):
            The name of the Azure Storage account where blobs are stored.

        storage_container_name (str):
            The name of the container within the Azure Storage account.

        logging_level (Optional[str]):
            The logging level for the application (e.g., DEBUG, INFO, WARNING, ERROR).
            Defaults to logging.ERROR if not specified.
    """

    # Configuration for how the settings model behaves
    model_config = SettingsConfigDict(
        extra="ignore",  # Ignore any extra environment variables not defined in this model
        arbitrary_types_allowed=True,  # Allow arbitrary types (e.g., logging.ERROR is an integer)
        env_ignore_empty=True  # Ignore environment variables that are empty strings
    )

    # Azure Service Bus fully qualified namespace
    service_bus_namespace: str

    # Azure Service Bus api key (optional if using Managed Identity)
    service_bus_api_key: Optional[str] = None

    # Azure Service Bus api key name
    service_bus_api_key_name: Optional[str] = None

    # Name of the Service Bus queue used to finalize content processing
    finalize_content_queue: str

    # Name of the Service Bus queue used for video summary tasks
    video_summary_queue: str

    # Endpoint URL for Azure OpenAI Service
    azure_openai_endpoint: str

    # API key for Azure OpenAI Service (optional if using Managed Identity)
    azure_openai_key: Optional[str] = None

    # API version for Azure OpenAI Service
    azure_openai_api_version: str

    # Name of the model used in Azure OpenAI Service
    azure_openai_model_name: str

    # Endpoint URL for the Content Understanding API
    content_understanding_endpoint: str

    # API version for the Content Understanding API
    content_understanding_api_version: str

    # Subscription key for authenticating with the Content Understanding API
    content_understanding_key: str

    # Name of the video analyzer used for processing videos
    video_analyzer_name: str

    # Name of the Azure Storage account where blobs are stored
    storage_account_name: str

    # Name of the container within the Azure Storage account
    storage_container_name: str

    # Name of the container within the Azure Storage account (optional if using Managed Identity)
    storage_account_api_key: Optional[str] = None

    # Logging level for the application (e.g., DEBUG, INFO, WARNING, ERROR)
    # Defaults to logging.ERROR if not specified in the environment
    logging_level: Optional[str] = logging.ERROR
