from datetime import datetime, timezone, timedelta

import logging
import uuid

from azure.servicebus import ServiceBusMessage
from openai import AzureOpenAI

from core import ContentResult, SummarizedVideoMetadata, ServiceBusEventMessagingService
from core.models import VideoUploadMetadata
from core.services import ContentUnderstandingClient, AzureBlobFileUploadService

from core.utils import get_file_name_from_url

logger = logging.getLogger(__name__)


class MessageHandler:

    def __init__(
            self,
            service_bus_messaging_service: ServiceBusEventMessagingService,
            file_upload_service: AzureBlobFileUploadService,
            content_understanding_client: ContentUnderstandingClient,
            openai_service: AzureOpenAI,
            openai_model_name: str,
            finalize_content_queue_name: str,
            video_summary_queue_name: str,
    ):
        """
        Creates an asynchronous message handler function for processing incoming Service Bus messages.

        :param service_bus_messaging_service: The Service Bus messaging service to send and receive messages.
        :param file_upload_service: The file upload service to manage uploaded content.
        :param content_understanding_client: The client for the content understanding service.
        :param openai_service: The Azure OpenAI service for generating video summaries.
        :param openai_model_name: The name of the OpenAI model to use for generating summaries.
        :param finalize_content_queue_name: The name of the queue for finalizing content processing.
        :param video_summary_queue_name: The name of the queue for sending video summaries.

        :return: A new instance of the MessageHandler class.
        """
        self.service_bus_messaging_service = service_bus_messaging_service
        self.file_upload_service = file_upload_service

        self.content_understanding_client = content_understanding_client

        self.openai_service = openai_service
        self.openai_model_name = openai_model_name

        self.finalize_content_queue_name = finalize_content_queue_name
        self.video_summary_queue_name = video_summary_queue_name

    async def receive_messages(self, message: ServiceBusMessage):
        """
        Processes a single Service Bus message by creating a video summary or requeuing the message.

        Args:
            message (ServiceBusMessage): The message received from the Service Bus.

        Raises:
            Exception: Propagates any exception encountered during message processing.
        """
        try:
            # Log that a message has been received
            logger.info("Received message")

            # Access the message body appropriately
            message_content: str = str(message)
            correlation_id: uuid.UUID = message.application_properties.get("correlationId", None)
            trace_id: uuid.UUID = message.application_properties.get("traceId", None)

            # Deserialize the message content into a VideoUploadMetadata object
            video_upload_metadata = VideoUploadMetadata.model_validate_json(message_content)

            # Retrieve the content understanding status for the given video ID
            content_result = await self.get_content_understanding_status(
                content_id=video_upload_metadata.videoId
            )

            if content_result.status == "Succeeded":
                # Log that the video processing has completed successfully
                logger.info("Video processing succeeded. Creating summary.")

                # Generate the summary for the video content
                content_summary = await self.create_video_summary(
                    content_result=content_result
                )

                # Create a summarized metadata object with the generated summary
                summarized_video_metadata = SummarizedVideoMetadata(
                    summary=content_summary,
                    videoId=video_upload_metadata.videoId
                )

                # Serialize the summarized metadata to JSON
                json_string = summarized_video_metadata.model_dump_json()

                # Send the summarized metadata to the designated queue
                await self.service_bus_messaging_service.send_message(
                    queue_name=self.video_summary_queue_name,
                    body=json_string,
                    correlation_id=correlation_id,
                    trace_id=trace_id
                )

                if video_upload_metadata.isUploaded:
                    file_name: str = get_file_name_from_url(video_upload_metadata.fileUrl)
                    await self.file_upload_service.delete_blob(file_name)

                # Log that the summarized message has been sent successfully
                logger.info("Summarized message sent successfully.")
            else:
                # Log that the video processing is still ongoing and needs to be requeued
                logger.info("Video still processing. Requeueing message.")
                # Serialize the original video upload metadata to JSON
                json_string = video_upload_metadata.model_dump_json()
                # Schedule the message to be retried after a 30-second delay
                scheduled_time = datetime.now(timezone.utc) + timedelta(seconds=30)
                await self.service_bus_messaging_service.schedule_message(
                    queue_name=self.finalize_content_queue_name,
                    body=json_string,
                    schedule_time_utc=scheduled_time,
                    correlation_id=correlation_id,
                    trace_id=trace_id
                )
                # Log that the message has been requeued
                logger.info("Message requeued successfully.")
        except Exception as e:
            # Log any errors that occur during message processing with stack trace
            logger.error("Error processing message", exc_info=True)
            raise

    async def create_video_summary(
            self,
            content_result: ContentResult
    ) -> str:
        """
        Creates a summary of the video content using Azure OpenAI.

        Args:
            content_result (ContentResult): The result from content understanding indicating video analysis.

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

            # Create a comprehensive summary by sending a request to Azure OpenAI's chat completion endpoint
            response = self.openai_service.chat.completions.create(
                model=self.openai_model_name,
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
            logger.error("Error creating video summary", exc_info=True)
            raise

    async def get_content_understanding_status(
            self,
            content_id: str
    ) -> ContentResult:
        """
        Retrieves the content understanding status for a given content ID.

        Args:
            content_id (str): The unique identifier for the content.

        Returns:
            ContentResult: The result containing the status and details of content understanding.

        Raises:
            Exception: Propagates any exception encountered while fetching the content status.
        """
        try:
            # Fetch the status of the content analysis
            content_result = await self.content_understanding_client.get_content_status(
                content_id=content_id
            )

            return content_result
        except Exception as e:
            # Log the error with stack trace and re-raise the exception
            logger.error("Error fetching content understanding status", exc_info=True)
            raise
