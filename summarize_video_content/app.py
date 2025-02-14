import asyncio
import logging
import uuid
from datetime import datetime, timezone, timedelta
from typing import Callable

from dotenv import load_dotenv
from azure.servicebus import ServiceBusMessage
from azure.identity.aio import DefaultAzureCredential, get_bearer_token_provider
from azure.storage.blob.aio import BlobServiceClient
from openai import AzureOpenAI

from .settings import AppSettings
from core.models import VideoUploadMetadata, SummarizedVideoMetadata, ContentResult
from core.services import ContentUnderstandingClient, EventMessagingService
from core.utils import get_file_name_from_url

# Initialize an asyncio event to signal when to stop processing messages
stop_event = asyncio.Event()

async def delete_gif_from_storage(
    blob_name: str,
    storage_account_name: str,
    storage_container_name: str
):
    """
    Uploads a local file to Azure Blob Storage and returns its SAS URL.

    :param blob_name: Name to assign to the blob in storage
    :param storage_account_name: Name of the Azure storage account
    :param storage_container_name: Name of the container within the storage account
    """
    account_url: str = f"https://{storage_account_name}.blob.core.windows.net"  # Base URL for the storage account

    async with DefaultAzureCredential() as credential:
        # Initialize the BlobServiceClient with the account URL and credentials
        async with BlobServiceClient(account_url=account_url, credential=credential) as blob_service_client:
            # Get the BlobClient for the specific blob
            async with blob_service_client.get_container_client(container=storage_container_name) as container_client:
                await container_client.delete_blob(blob=blob_name) # Delete the blob from storage


async def create_video_summary(
    content_result: ContentResult,
    settings: AppSettings
) -> str:
    """
    Creates a summary of the video content using Azure OpenAI.

    Args:
        content_result (ContentResult): The result from content understanding indicating video analysis.
        settings (AppSettings): Application settings containing configuration parameters.

    Returns:
        str: The generated summary of the video content.

    Raises:
        Exception: Propagates any exception encountered during the summary creation process.
    """
    try:
        # Initialize a list to efficiently build the content string
        summaries = [
            f"#{index}\n{content.fields.summary}"
            for index, content in enumerate(content_result.result.contents)
        ]
        combined_summary = "\n".join(summaries)

        # Authenticate using Azure Default Credential
        async with DefaultAzureCredential() as credential:
            # Obtain a bearer token provider for the cognitive services endpoint
            token_provider = get_bearer_token_provider(
                credential,
                settings.cognitive_services_endpoint
            )
            # Retrieve the bearer token asynchronously
            token = await token_provider()

            # Initialize the Azure OpenAI client with the necessary configurations
            client = AzureOpenAI(
                api_version=settings.azure_openai_api_version,
                azure_endpoint=settings.azure_openai_endpoint,
                azure_ad_token=token,
            )

            # Create a comprehensive summary by sending a request to Azure OpenAI's chat completion endpoint
            response = client.chat.completions.create(
                model=settings.azure_openai_model_name,
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are an AI assistant tasked with analyzing and combining visual and audio content "
                            "from a video to create a comprehensive and detailed textual description."
                        )
                    },
                    {
                        "role": "user",
                        "content": f"""  
                            Combine the individual segment transcriptions into a cohesive, seamless, and comprehensive full  
                            transcription of the entire video. Ensure the transitions between segments are smooth and logical,  
                            maintaining the chronological flow and context of the video. Resolve any inconsistencies,  
                            redundancies, or overlapping information, and verify that all elements—spoken dialogue,  
                            visual context, on-screen text, and non-verbal cues—are accurately preserved and integrated  
                            into a unified transcription. Prioritize clarity, readability, and fidelity to the original  
                            video content  
                            {combined_summary}  
                        """
                    }
                ]
            )

            # Extract and return the generated summary from the response
            return response.choices[0].message.content
    except Exception as e:
        # Log the error with stack trace and re-raise the exception
        logging.error("Error creating video summary", exc_info=True)
        raise

async def get_content_understanding_status(
    content_id: str,
    settings: AppSettings
) -> ContentResult:
    """
    Retrieves the content understanding status for a given content ID.

    Args:
        content_id (str): The unique identifier for the content.
        settings (AppSettings): Application settings containing configuration parameters.

    Returns:
        ContentResult: The result containing the status and details of content understanding.

    Raises:
        Exception: Propagates any exception encountered while fetching the content status.
    """
    try:
        # Initialize the client for content understanding with necessary configurations
        async with ContentUnderstandingClient(
            endpoint=settings.content_understanding_endpoint,
            key=settings.content_understanding_key,
            api_version=settings.content_understanding_api_version,
            logger=logging.getLogger(ContentUnderstandingClient.__name__)
        ) as client:

            # Fetch the status of the content analysis
            content_result = await client.get_content_status(
                content_id=content_id,
                analyzer_name=settings.video_analyzer_name
            )

        return content_result
    except Exception as e:
        # Log the error with stack trace and re-raise the exception
        logging.error("Error fetching content understanding status", exc_info=True)
        raise

def message_handler(
    event_messaging_service: EventMessagingService,
    settings: AppSettings
) -> Callable:
    """
    Creates a message handler function for processing incoming Service Bus messages.

    Args:
        event_messaging_service (EventMessagingService): The service responsible for event messaging.
        settings (AppSettings): Application settings containing configuration parameters.

    Returns:
        Callable: An asynchronous function that handles incoming messages.
    """

    async def receive_messages(message: ServiceBusMessage):
        """
        Processes a single Service Bus message by creating a video summary or requeuing the message.

        Args:
            message (ServiceBusMessage): The message received from the Service Bus.

        Raises:
            Exception: Propagates any exception encountered during message processing.
        """
        try:
            # Log that a message has been received
            logging.info("Received message")

            # Access the message body appropriately
            message_content: str = str(message)
            correlation_id: uuid.UUID = message.application_properties.get("correlationId", None)

            # Deserialize the message content into a VideoUploadMetadata object
            video_upload_metadata = VideoUploadMetadata.model_validate_json(message_content)

            # Retrieve the content understanding status for the given video ID
            content_result = await get_content_understanding_status(
                content_id=video_upload_metadata.videoId,
                settings=settings
            )

            if content_result.status == "Succeeded":
                # Log that the video processing has completed successfully
                logging.info("Video processing succeeded. Creating summary.")

                # Generate the summary for the video content
                content_summary = await create_video_summary(
                    content_result=content_result,
                    settings=settings
                )

                # Create a summarized metadata object with the generated summary
                summarized_video_metadata = SummarizedVideoMetadata(
                    summary=content_summary,
                    videoId=video_upload_metadata.videoId
                )
                # Serialize the summarized metadata to JSON
                json_string = summarized_video_metadata.model_dump_json()
                # Send the summarized metadata to the designated queue
                await event_messaging_service.send_message(
                    queue_name=settings.video_summary_queue,
                    body=json_string,
                    correlation_id=correlation_id
                )

                if video_upload_metadata.isUploaded:
                    file_name: str = get_file_name_from_url(video_upload_metadata.fileUrl)
                    await delete_gif_from_storage(
                        blob_name=file_name,
                        storage_account_name=settings.storage_account_name,
                        storage_container_name=settings.storage_container_name
                    )
                # Log that the summarized message has been sent successfully
                logging.info("Summarized message sent successfully.")
            else:
                # Log that the video processing is still ongoing and needs to be requeued
                logging.info("Video still processing. Requeueing message.")
                # Serialize the original video upload metadata to JSON
                json_string = video_upload_metadata.model_dump_json()
                # Schedule the message to be retried after a 30-second delay
                scheduled_time = datetime.now(timezone.utc) + timedelta(seconds=30)
                await event_messaging_service.schedule_message(
                    queue_name=settings.finalize_content_queue,
                    body=json_string,
                    schedule_time_utc=scheduled_time,
                    correlation_id=correlation_id
                )
                # Log that the message has been requeued
                logging.info("Message requeued successfully.")
        except Exception as e:
            # Log any errors that occur during message processing with stack trace
            logging.error("Error processing message", exc_info=True)
            raise

    return receive_messages

async def main_logic(settings: AppSettings):
    """
    The main entry point for the asynchronous application.
    Initializes settings, sets up event messaging, and starts processing messages.
    """
    try:
        # Authenticate using Azure Default Credential within an asynchronous context
        async with DefaultAzureCredential() as credential:
            # Initialize the event messaging service with the service bus namespace and credential
            async with EventMessagingService(
                settings.service_bus_fully_qualified_namespace,
                credential,
                logger=logging.getLogger(EventMessagingService.__name__)
            ) as event_messaging_service:
                try:
                    # Log that the message processing service is starting
                    logging.info("Starting message processing service.")

                    # Create the message handler function with the messaging service and settings
                    messaging_handler = message_handler(
                        event_messaging_service=event_messaging_service,
                        settings=settings
                    )

                    # Begin processing messages from the specified queue
                    await event_messaging_service.process_messages(
                        queue_name=settings.finalize_content_queue,
                        stop_event=stop_event,
                        message_handler=messaging_handler
                    )
                except KeyboardInterrupt:
                    # Handle graceful shutdown when a keyboard interrupt is received
                    logging.info("Received keyboard interrupt. Stopping message listener...")
                    stop_event.set()
                except Exception as e:
                    # Log any unexpected exceptions in the main processing loop with stack trace
                    logging.error("Error in main processing loop", exc_info=True)
                    raise
    except Exception as e:
        # Log any initialization errors with stack trace
        logging.error("Error initializing application", exc_info=True)
        raise

def main():
    # Load environment variables from a .env file
    load_dotenv()
    settings = AppSettings()

    # Configure the logging module to capture info-level logs and above
    logging.basicConfig(level=settings.logging_level)
    # Run the main asynchronous function using asyncio's event loop
    asyncio.run(main_logic(settings=settings))

if __name__ == "__main__":
    main()