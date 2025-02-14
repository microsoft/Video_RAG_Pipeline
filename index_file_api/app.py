import uuid
import logging

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from azure.identity.aio import DefaultAzureCredential

from .models import Payload
from .settings import AppSettings

from core.services import EventMessagingService
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

# Define an endpoint to process payloads
@app.post("/process")
async def process_payload(payload: Payload):
    try:
        logger.info("Received payload for processing")

        # Generate a unique correlation ID
        correlation_id = uuid.uuid4()
        logger.info("Generated correlation ID: %s", correlation_id)

        # Create blob metadata based on the provided payload  
        blob_metadata = BlobMetadata(fileUrl=payload.fileUrl)

        # Serialize the blob metadata to a JSON string  
        json_string = blob_metadata.model_dump_json()
        logger.debug("Serialized blob metadata to JSON")

        # Create and initialize Azure credentials  
        async with DefaultAzureCredential() as credential:
            logger.info("Acquired Azure credentials successfully")

            async with EventMessagingService(
                fully_qualified_namespace=settings.service_bus_fully_qualified_namespace,
                credential=credential,
                logger=logging.getLogger(EventMessagingService.__name__),
            ) as event_messaging_service:

                # Send the message to the Azure Service Bus queue  
                await event_messaging_service.send_message(
                    correlation_id=correlation_id,
                    body=json_string,
                    queue_name=settings.index_file_queue,
                )
                logger.info(
                    "Message sent to Service Bus queue '%s' with correlation ID: %s",
                    settings.index_file_queue,
                    correlation_id)

                # Return a success response with the message ID
        logger.info("Payload processed successfully with message ID: %s", correlation_id)
        return {"message_id": str(correlation_id)}

    except Exception as e:
        logger.error("An unexpected error occurred: %s", e)
        raise HTTPException(status_code=500, detail=f"Server error.")

def main():
    import uvicorn

    host=settings.host
    port=settings.port
    uvicorn.run(app, host=host, port=port)

if __name__ == "__main__":
    main()
