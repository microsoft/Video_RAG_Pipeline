from dependency_injector import containers, providers
import logging
import aiohttp
import sys
from azure.identity.aio import DefaultAzureCredential
from azure.servicebus.aio import ServiceBusClient

from core.services import EventMessagingService, ServiceBusEventMessagingService, ContentUnderstandingClient, AnimatedGifConverter, AzureBlobFileUploadService
from .message_handler import MessageHandler

async def create_azure_credential():
    credential = DefaultAzureCredential()
    yield credential
    await credential.close()

async def create_service_bus_client(credential: DefaultAzureCredential, fully_qualified_namespace: str):
    logger = logging.getLogger(__name__)
    try:
        client = ServiceBusClient(fully_qualified_namespace=fully_qualified_namespace, credential=credential)
        logger.info("Service Bus client initialized.")
    except Exception as e:
        logger.exception(f"Failed to initialize Service Bus client: {e}")
        raise
    yield client
    try:
        await client.close()
        logger.info("Service Bus client closed.")
    except Exception as e:
        logger.exception(f"Error closing Service Bus client: {e}")
    finally:
        client = None  # Ensure the client is reset

async def create_http_client_session(key: str):
    logger = logging.getLogger(__name__)
    headers = {
        'Content-Type': 'application/json',
        'Ocp-Apim-Subscription-Key': key
    }
    timeout = aiohttp.ClientTimeout(total=60)  # Adjust timeout as needed
    session = aiohttp.ClientSession(headers=headers, timeout=timeout)
    logger.info("HTTP client session initialized.")
    yield session
    
    await session.close()
    logger.info("HTTP client session closed.")
    session = None

class Container(containers.DeclarativeContainer):

    config = providers.Configuration()

    credential = providers.Resource(create_azure_credential)

    logging = providers.Resource(
        logging.basicConfig,
        format="%(asctime)s - %(levelname)s - %(message)s",
        level=config.logging_level,
        stream=sys.stderr,
    )

    http_client_session = providers.Resource(
        create_http_client_session,
        key=config.content_understanding_key
    )

    service_bus_client = providers.Resource(
        create_service_bus_client,
        credential=credential,
        fully_qualified_namespace=config.message_broker_url,
    )

    content_understanding_client = providers.Singleton(
        ContentUnderstandingClient,
        session=http_client_session,
        endpoint=config.content_understanding_url,
        analyzer_name=config.video_analyzer_name,
        api_version=config.content_understanding_api_version,
    )

    gif_converter = providers.Singleton(
        AnimatedGifConverter,
        download_dir=config.mp4_output_path,
        client_session=http_client_session
    )

    file_upload_service = providers.Singleton(
        AzureBlobFileUploadService,
        credential=credential,
        storage_account_name=config.storage_account_name,
        storage_container_name=config.container_name
    )

    service_bus_messaging_service = providers.Singleton(
        ServiceBusEventMessagingService,
        service_bus_client=service_bus_client,
    )

    event_messaging_service = providers.Selector(
        config.message_broker_type,
        service_bus=service_bus_messaging_service
    )

    message_handler = providers.Singleton(
        MessageHandler,
        event_messaging_service=event_messaging_service,
        gif_converter=gif_converter,
        content_understanding_client=content_understanding_client,
        blob_upload_service=file_upload_service,
        finalize_content_queue_name=config.finalize_content_queue,
    )