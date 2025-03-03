import asyncio
import logging

from dependency_injector.wiring import Provide, inject
from dotenv import load_dotenv

from core import ServiceBusEventMessagingService

from summarize_video_content.container import Container
from summarize_video_content.message_handler import MessageHandler
from summarize_video_content.settings import AppSettings

# Load environment variables from a .env file
load_dotenv()
settings = AppSettings()

# Configure logging
logging.basicConfig(
    level=settings.logging_level,  # Set desired log level
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler()
    ]
)

# Initialize an asyncio event to signal when to stop processing messages
stop_event = asyncio.Event()


@inject
async def main_logic(
        service_bus_messaging_service: ServiceBusEventMessagingService = Provide[Container.service_bus_messaging_service],
        message_handler: MessageHandler = Provide[Container.message_handler],
        finalize_content_queue: str = Provide[Container.config.finalize_content_queue]
):
    """
    The main asynchronous function that initializes services and starts listening for messages.
    """

    logging.info("Listening for messages. Press Ctrl+C to stop.")  # Inform that the listener is active

    try:
        # Start processing messages from the specified queue
        await service_bus_messaging_service.process_messages(
            queue_name=finalize_content_queue,
            stop_event=stop_event,
            message_handler=message_handler.receive_messages,
        )
    except KeyboardInterrupt:
        # Handle graceful shutdown on keyboard interrupt (Ctrl+C)
        logging.info("Stopping message listener...")
        stop_event.set()
    except Exception as e:
        # Log any other exceptions that occur during the main loop
        logging.error(f"Error in main loop: {e}", exc_info=True)


async def setup_container():
    """
    The main composition root function that initializes the application and starts the main logic.
    """

    # Load application settings from the AppSettings class
    container = Container()
    container.config.from_pydantic(settings)
    container.wire(modules=[__name__])

    # Determine how we're authenticating to Azure Open AI
    if container.config.get("azure_openai_key"):
        container.config.azure_openai_auth_type.override("key")
    else:
        container.config.azure_openai_auth_type.override("managed_identity")

    await container.init_resources()
    await main_logic()
    await container.shutdown_resources()

def main():
    asyncio.run(setup_container())

    # Configure the logging module to capture info-level logs and above
    logging.basicConfig(level=settings.logging_level)
    # Run the main asynchronous function using asyncio's event loop
    asyncio.run(main_logic(settings=settings))

if __name__ == "__main__":
    main()