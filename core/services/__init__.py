from azure.identity.aio import DefaultAzureCredential, get_bearer_token_provider
from azure.core.credentials import AzureNamedKeyCredential

from .content_understanding_client import *
from .video_analysis_service import *
from .multi_modal_llm_analysis_service import *
from .event_messaging_service import *
from .service_bus_event_messaging_service import *
from .animated_gif_converter import *
from .file_upload_service import *
from .llm_video_analysis_service import *

async def create_azure_credential(api_key_name: Optional[str] = None, api_key: Optional[str] = None):
    if api_key_name and api_key:
        credential = AzureNamedKeyCredential(name=api_key_name, key=api_key)
    else:
        credential = DefaultAzureCredential()

    yield credential

    if isinstance(credential, DefaultAzureCredential):
        await credential.close()

async def create_service_bus_client(endpoint: str, credential: any, logger: any):
    logger.debug(f"Creating Service Bus client for endpoint: {endpoint}")
    logger.debug(f"Using credential: {credential}")
    try:
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

# we need to extract a token for the AzureOpenAI client if we're going to connect via Managed Identity
async def create_azure_ad_token():
    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")
    token = await token_provider()
    yield token
    await credential.close()

async def create_content_understanding_http_client_session(key: str, logger: Optional[any]):
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

__all__ = [
    "ServiceBusEventMessagingService",
    "EventMessagingService",
    "VideoAnalysisService",
    "ContentUnderstandingClient",
    "MultiModalLLMAnalysisService",
    "ContentResult",
    "AnimatedGifConverter",
    "AzureBlobFileUploadService",
    "LLMVideoAnalysisService",
    "create_azure_credential",
    "create_azure_ad_token",
    "create_service_bus_client",
    "create_content_understanding_http_client_session"
]
