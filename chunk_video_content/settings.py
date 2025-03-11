import logging

from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class AppSettings(BaseSettings):
    """  
    Application configuration settings loaded from environment variables or a .env file.  

    Attributes:  
        service_bus_namespace (str): Fully qualified namespace for Azure Service Bus.
        index_file_queue (str): Name of the queue for indexing blobs.  
        finalize_content_queue (str): Name of the queue for finalizing content processing.  
        content_understanding_endpoint (str): URL endpoint for the content understanding service.
        content_understanding_key (str): API key for authenticating with the content understanding service.  
        content_understanding_api_version (str): API version to use for the content understanding service.  
        video_analyzer_name (str): Name identifier for the video analyzer service.
        analysis_service_type (str): Specifies the type of service to use for video analysis (choices are content_understanding, multimodal_llm (not yet implemented))
        storage_account_name (str): Azure Storage account name.  
        storage_container_name (str): Name of the blob container in Azure Storage.
        mp4_output_path (str): Filesystem path where MP4 output files will be stored.  
        logging_level (Optional[int | str]): Optional logging level (e.g., DEBUG, INFO). Defaults to None.  
    """

    # Configuration for the Pydantic settings model  
    model_config = SettingsConfigDict(
        extra="ignore",  # Ignore any extra fields not defined in the model
        arbitrary_types_allowed=True,  # Allow arbitrary types in settings (e.g., custom classes)
        env_ignore_empty=True  # Ignore environment variables that are empty strings
    )

    # Azure Service Bus fully qualified namespace
    service_bus_namespace: str

    # Azure Service Bus api key (optional if using Managed Identity)
    service_bus_api_key: Optional[str] = None

    # Azure Service Bus api key name
    service_bus_api_key_name: Optional[str] = None

    # Message broker type (valid options: "service_bus".  "kafka" coming soon)
    message_broker_type: str = "service_bus"

    # Queue name for handling blob indexing tasks  
    index_file_queue: str

    # Queue name for handling content finalization tasks  
    finalize_content_queue: str

    # Endpoint URL for the content understanding API service  
    content_understanding_endpoint: str

    # API key for authenticating requests to the content understanding service  
    content_understanding_key: str

    # Specifies the API version to use when interacting with the content understanding service  
    content_understanding_api_version: str

    # Identifier name for the video analyzer component or service  
    video_analyzer_name: str

    # Specifies the type of service to use for video analysis (choices are content_understanding, multimodal_llm (not yet implemented))
    analysis_service_type: str = "content_understanding"

    # Name of the Azure Storage account where blobs are stored
    storage_account_name: str

    # Name of the container within the Azure Storage account
    storage_container_name: str

    # Name of the container within the Azure Storage account (optional if using Managed Identity)
    storage_account_api_key: Optional[str] = None

    # Filesystem path where processed MP4 files will be saved  
    mp4_output_path: str

    # Optional setting to define the logging level; accepts either integer or string representations  
    logging_level: Optional[int | str] = logging.ERROR
