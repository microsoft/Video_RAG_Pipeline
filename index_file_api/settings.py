import logging

from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class AppSettings(BaseSettings):
    """
    Application configuration settings managed through environment variables.

    This class utilizes Pydantic's BaseSettings to automatically load and validate
    configuration settings from environment variables or other sources. It
    defines the expected configuration parameters required by the application,
    such as Azure Service Bus details and logging configurations.

    Attributes:
        service_bus_fully_qualified_namespace (str):
            The fully qualified namespace for the Azure Service Bus. This is typically
            in the format '<namespace>.servicebus.windows.net' and is used to uniquely
            identify the Service Bus instance.

        index_file_queue (str):
            The name of the queue within the Azure Service Bus where index files are to be
            sent or received. This queue is used for processing index-related messages.

        logging_level (Optional[int | str]):
            An optional setting to define the logging level for the application.
            It accepts either integer values corresponding to logging levels (e.g., 10 for DEBUG)
            or string representations (e.g., 'DEBUG'). If not provided, it defaults to `None`,
            allowing the application to use a default logging configuration.
    """

    # Configuration for Pydantic's BaseSettings behavior
    model_config = SettingsConfigDict(
        extra="ignore",  # Ignore any extra environment variables not defined in the model
        arbitrary_types_allowed=True,  # Allow arbitrary types beyond standard Python types
        env_ignore_empty=True , # Ignore environment variables that are empty strings
    )

    # Define required settings fields
    service_bus_fully_qualified_namespace: str  # Azure Service Bus namespace (e.g., 'myservicebus.servicebus.windows.net')
    index_file_queue: str  # Name of the Azure Service Bus queue for index files

    # Optional logging level setting; accepts integer (e.g., 10) or string (e.g., 'DEBUG')
    logging_level: Optional[int | str] = logging.ERROR

    host: str = "0.0.0.0"
    port: int = 8000
