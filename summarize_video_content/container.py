import structlog
import aiohttp

from dependency_injector import containers, providers
from azure.core.credentials import AzureNamedKeyCredential
from azure.servicebus.aio import ServiceBusClient
from openai import AzureOpenAI

from core.services import ServiceBusEventMessagingService, ContentUnderstandingClient, AzureBlobFileUploadService

from summarize_video_content.message_handler import MessageHandler

logger = structlog.get_logger("summarize_video_content_container")


async def create_service_bus_client(endpoint: str, api_key_name: str, api_key: str):
    try:
        credential = AzureNamedKeyCredential(name=api_key_name, key=api_key)
        client = ServiceBusClient(fully_qualified_namespace=endpoint, credential=credential)
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

    http_client_session = providers.Resource(
        create_http_client_session,
        key=config.content_understanding_key
    )

    service_bus_client = providers.Resource(
        create_service_bus_client,
        endpoint=config.service_bus_namespace,
        api_key_name=config.service_bus_api_key_name,
        api_key=config.service_bus_api_key
    )

    content_understanding_client = providers.Singleton(
        ContentUnderstandingClient,
        session=http_client_session,
        endpoint=config.content_understanding_endpoint,
        analyzer_name=config.video_analyzer_name,
        api_version=config.content_understanding_api_version,
    )

    file_upload_service = providers.Singleton(
        AzureBlobFileUploadService,
        storage_account_name=config.storage_account_name,
        storage_container_name=config.storage_container_name,
        storage_account_api_key=config.storage_account_api_key
    )

    openai_service = providers.Singleton(
        AzureOpenAI,
        api_key=config.azure_openai_key,
        api_version=config.azure_openai_api_version,
        azure_endpoint=config.azure_openai_endpoint
    )

    service_bus_messaging_service = providers.Singleton(
        ServiceBusEventMessagingService,
        service_bus_client=service_bus_client,
    )

    message_handler = providers.Singleton(
        MessageHandler,
        service_bus_messaging_service=service_bus_messaging_service,
        file_upload_service=file_upload_service,
        content_understanding_client=content_understanding_client,
        openai_service=openai_service,
        openai_model_name=config.azure_openai_model_name,
        finalize_content_queue_name=config.finalize_content_queue,
        video_summary_queue_name=config.video_summary_queue
    )
