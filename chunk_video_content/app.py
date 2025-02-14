import asyncio
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Callable

import aiofiles
import aiohttp
import tempfile

from azure.identity.aio import DefaultAzureCredential
from azure.servicebus import ServiceBusMessage
from azure.storage.blob import BlobSasPermissions, generate_blob_sas
from azure.storage.blob.aio import BlobServiceClient
from dotenv import load_dotenv
from moviepy import VideoFileClip
from dependency_injector.wiring import inject, Provide

from .settings import AppSettings
from .container import Container
from .message_handler import MessageHandler
from core.models import BlobMetadata, VideoUploadMetadata
from core.services import ContentUnderstandingClient, EventMessagingService, ServiceBusEventMessagingService

# Create an asyncio event to signal when to stop processing
stop_event = asyncio.Event()

@inject
async def main_logic(event_messaging_service: EventMessagingService = Provide[Container.event_messaging_service],
                     message_handler: MessageHandler = Provide[Container.message_handler],
                     index_blob_queue: StopAsyncIteration = Provide[Container.config.index_blob_queue]):
    """
    The main asynchronous function that initializes services and starts listening for messages.
    """

    logger = logging.getLogger(__name__)
    logger.info("Listening for messages. Press Ctrl+C to stop.")  # Inform that the listener is active
    try:

        # Start processing messages from the specified queue
        await event_messaging_service.process_messages(
            queue_name=index_blob_queue,
            stop_event=stop_event,
            message_handler=message_handler.receive_messages,
        )
    except KeyboardInterrupt:
        # Handle graceful shutdown on keyboard interrupt (Ctrl+C)
        logger.info("Stopping message listener...")
        stop_event.set()
    except Exception as e:
        # Log any other exceptions that occur during the main loop
        logger.error(f"Error in main loop: {e}", exc_info=True)
    except Exception as e:
        # Log any exceptions that occur during the initialization of the application
        logger.error(f"Error initializing application: {e}", exc_info=True)

async def main_composition_root():
    """
    The main composition root function that initializes the application and starts the main logic.
    """

    # Load application settings from the AppSettings class
    container = Container()
    container.config.from_pydantic(AppSettings())
    container.wire(modules=[__name__])

    await container.init_resources()
    await main_logic()
    await container.shutdown_resources()

def main():
    load_dotenv()
    asyncio.run(main_composition_root())

if __name__ == "__main__":
    main()
