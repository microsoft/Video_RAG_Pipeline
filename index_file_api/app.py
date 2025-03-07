import uuid
import logging
import asyncio
import mimetypes
import requests

from dependency_injector.wiring import Provide, inject
from dotenv import load_dotenv

from fastapi import FastAPI, HTTPException, Depends, Header

from core import ServiceBusEventMessagingService

from index_file_api.container import Container
from index_file_api.models import Payload
from index_file_api.settings import AppSettings

from core.models import BlobMetadata

# Load environment variables from the .env file
load_dotenv()
settings: AppSettings = AppSettings()

# Configure logging
logging.basicConfig(
    level=settings.logging_level,  # Set desired log level
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# Initialize FastAPI application
app = FastAPI()

# Load application settings from the AppSettings class
container = Container()

async def init_container_resources():
    """
    The main composition root function that initializes the application and starts the main logic.
    """
    container.config.from_pydantic(settings)
    container.wire(modules=[__name__])

    await container.init_resources()


async def stop_container_resources():
    """
    The main composition root function that initializes the application and starts the main logic.
    """
    await container.shutdown_resources()

async def extract_file_type(file_url: str) -> str:
    """
    Extracts the file type from the given URL.

    Args:
        file_url (str): The URL of the file.

    Returns:
        str: The MIME type of the file.
    """
    url_mime_type, _ = mimetypes.guess_type(file_url)
    logger.info("Received content type header: %s", url_mime_type)
    
    if not url_mime_type:
        logger.info("Attempting to fetch content type from URL headers")
        # Use HEAD request to avoid downloading the entire file
        response = requests.head(file_url, timeout=10)
        if response.status_code == 200 and 'content-type' in response.headers:
            url_mime_type = response.headers['content-type'].split(';')[0].strip()
            logger.info("Retrieved content-type from header: %s", url_mime_type)
        else:
            logger.warning("Failed to get content-type from headers: HTTP %s", response.status_code)

    return url_mime_type
    
# Define an endpoint to process payloads
@app.post("/process")
@inject
async def process_payload(
        payload: Payload,
        service_bus_messaging_service: ServiceBusEventMessagingService = Depends(
            Provide[Container.service_bus_messaging_service])
):
    try:
        logger.info("Received payload for processing")
        
        # Generate a unique correlation ID
        correlation_id = payload.id or uuid.uuid4()
        trace_id = uuid.uuid4()

        logger.info("Generated message with correlation ID: %s", correlation_id)
        logger.info("Generated trace ID: %s", trace_id)

        # Validate mime type from the url
        url_mime_type = await extract_file_type(payload.fileUrl)
        logger.info("Received content type header: %s", url_mime_type)
        
        if url_mime_type not in settings.allowed_mime_types:
            logger.error("Invalid content type: %s", url_mime_type)
            raise HTTPException(
                status_code=400, 
                detail="Invalid content type."
            )
    
        # Create blob metadata based on the provided payload
        blob_metadata = BlobMetadata(fileUrl=payload.fileUrl)

        # Serialize the blob metadata to a JSON string
        json_string = blob_metadata.model_dump_json()
        logger.debug("Serialized blob metadata to JSON")

        # Send the message to the Azure Service Bus queue
        await service_bus_messaging_service.send_message(
            correlation_id=correlation_id,
            trace_id=trace_id,
            body=json_string,
            queue_name=settings.index_file_queue,
        )

        logger.info(
            "Message sent to Service Bus queue '%s' with correlation ID: %s",
            settings.index_file_queue,
            correlation_id)

        # Return a success response with the message ID

        logger.info("Payload processed successfully with message ID: %s", correlation_id)

        return {"correlation_id": str(correlation_id)}

    except Exception as e:
        logger.error("An unexpected error occurred: %s", e)
        raise HTTPException(status_code=500, detail=f"Server error.")


def main():
    import uvicorn

    host = settings.host
    port = settings.port

    asyncio.run(init_container_resources())

    app.add_event_handler("shutdown", stop_container_resources)

    uvicorn.run(
        app,
        host=host,
        port=port
    )


if __name__ == "__main__":
    main()
