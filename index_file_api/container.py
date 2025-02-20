import structlog
import aiohttp

from dependency_injector import containers, providers

from azure.core.credentials import AzureNamedKeyCredential
from azure.servicebus.aio import ServiceBusClient

from core.services import ServiceBusEventMessagingService, ContentUnderstandingClient, AnimatedGifConverter, \
    AzureBlobFileUploadService

from chunk_video_content.message_handler import MessageHandler

logger = structlog.get_logger("video_summarizer_api_container")


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


class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

    service_bus_client = providers.Resource(
        create_service_bus_client,
        endpoint=config.service_bus_namespace,
        api_key_name=config.service_bus_api_key_name,
        api_key=config.service_bus_api_key
    )

    service_bus_messaging_service = providers.Singleton(
        ServiceBusEventMessagingService,
        service_bus_client=service_bus_client,
    )
