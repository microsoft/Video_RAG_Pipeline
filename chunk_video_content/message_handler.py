import logging
import aiohttp
import uuid
import os  # Added import for file operations

from azure.servicebus import ServiceBusMessage
from core.models import BlobMetadata, VideoUploadMetadata
from core.services import EventMessagingService, ContentUnderstandingClient, AnimatedGifConverter, AzureBlobFileUploadService

from core.utils import get_file_name_from_url, is_file_type

class MessageHandler():

    def __init__(
        self,
        event_messaging_service: EventMessagingService,
        gif_converter: AnimatedGifConverter,
        content_understanding_client: ContentUnderstandingClient,
        blob_upload_service: AzureBlobFileUploadService,
        finalize_content_queue_name: str,

    ):
        """
        Creates an asynchronous message handler function for processing incoming Service Bus messages.

        :param event_messaging_service: Service for interacting with the event messaging system
        :param content_understanding_client: Client for content analysis and understanding
        :param settings: Application settings containing configuration parameters
        :return: Asynchronous function to handle messages
        """
        self.event_messaging_service = event_messaging_service
        self.gif_converter = gif_converter
        self.content_understanding_client = content_understanding_client
        self.blob_upload_service = blob_upload_service
        self.finalize_content_queue_name = finalize_content_queue_name
        self.logger = logging.getLogger(__name__)

    async def receive_messages(self, message: ServiceBusMessage):
        """
        Asynchronous function to handle incoming Service Bus messages.

        Example:
        {
            "fileUrl": "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4"
        }

        Custom properties:
        - correlationId: "e51e9d55-e60d-40eb-9a9f-12dc24ed5b48"

        :param message: The incoming Service Bus message
        """
        try:
            # Log that a message has been received
            self.logger.info("Received message")

            # Convert the message content to a string and parse it into BlobMetadata
            message_content = str(message)

            # Extract the correlation ID from the message properties
            correlation_id: uuid.UUID = message.application_properties.get(b"correlationId", None)

            blob_metadata = BlobMetadata.model_validate_json(message_content)
            file_name = get_file_name_from_url(blob_metadata.fileUrl)  # Extract the file name from the URL
            is_uploaded: bool = False
            
            # Variables to track local files for later cleanup
            gif_path = None
            mp4_path = None

            # Check if the file is a GIF
            if is_file_type(file_name, ".gif"):
                gif_path = os.path.join(self.gif_converter.download_dir, file_name)
                mp4_path = await self.gif_converter.download_and_convert_gif(blob_metadata.fileUrl, file_name)
                file_name = file_name.replace(".gif", ".mp4")
                is_uploaded = True  # Sets the bool to uploaded

                # Upload the converted MP4 to Azure Blob Storage and update the file URL
                blob_metadata.fileUrl = await self.blob_upload_service.upload_to_azure_blob(
                    file_path=mp4_path,
                    blob_name=file_name
                )
                
                # Delete the GIF and mp4 files after conversion and upload
                if os.path.exists(gif_path):
                    os.remove(gif_path)
                    self.logger.info(f"Deleted temporary GIF file: {gif_path}")
                    
                if os.path.exists(mp4_path):
                    os.remove(mp4_path)
                    self.logger.info(f"Deleted temporary MP4 file: {mp4_path}")

            # Upload the content URL to the Content Understanding service and get the video ID
            self.logger.info(blob_metadata.fileUrl)
            
            video_id = await self.content_understanding_client.upload_url(
                content_url=blob_metadata.fileUrl
            )
            logging.info(f'Video ID: {video_id}')

            # Create metadata for the video upload and send it to the finalize content queue
            video_upload_metadata = VideoUploadMetadata(
                videoId=video_id,
                fileName=file_name,
                fileUrl=blob_metadata.fileUrl,
                isUploaded=is_uploaded
            )

            json_string = video_upload_metadata.model_dump_json()

            await self.event_messaging_service.send_message(
                queue_name=self.finalize_content_queue_name,
                body=json_string,
                correlation_id=correlation_id
            )

            # Log that the message has been successfully sent
            logging.info("Message sent")
        except aiohttp.ClientError as aio_err:
            logging.error(f"Async HTTP error: {aio_err}", exc_info=True)
        except Exception as e:
            logging.error(f"Unexpected error processing message: {e}", exc_info=True)
            