import uuid
import logging

from azure.servicebus import ServiceBusMessage

from core.utils import get_file_name_from_url
from core.models import ContentResult, VideoUploadMetadata, SummarizedVideoMetadata
from core.services import ContentUnderstandingClient, AzureBlobFileUploadService, LLMVideoAnalysisService, \
    ServiceBusEventMessagingService
from core.exceptions import FatalQueueingException, RetryQueueingException

logger = logging.getLogger(__name__)


class MessageHandler:

    def __init__(
            self,
            service_bus_messaging_service: ServiceBusEventMessagingService,
            file_upload_service: AzureBlobFileUploadService,
            content_understanding_client: ContentUnderstandingClient,
            llm_video_analysis_service: LLMVideoAnalysisService,
            finalize_content_queue_name: str,
            video_summary_queue_name: str,
    ):
        """
        Creates an asynchronous message handler function for processing incoming Service Bus messages.

        :param service_bus_messaging_service: The Service Bus messaging service to send and receive messages.
        :param file_upload_service: The file upload service to manage uploaded content.
        :param content_understanding_client: The client for the content understanding service.
        :param llm_video_analysis_service: The service for analyzing video content using Azure OpenAI.
        :param finalize_content_queue_name: The name of the queue for finalizing content processing.
        :param video_summary_queue_name: The name of the queue for sending video summaries.

        :return: A new instance of the MessageHandler class.
        """
        self.service_bus_messaging_service = service_bus_messaging_service
        self.file_upload_service = file_upload_service

        self.content_understanding_client = content_understanding_client

        self.llm_video_analysis_service = llm_video_analysis_service

        self.finalize_content_queue_name = finalize_content_queue_name
        self.video_summary_queue_name = video_summary_queue_name

    async def receive_messages(self, message: ServiceBusMessage) -> None:
        """
        Processes a single Service Bus message by creating a video summary or requeuing the message.

        Args:
            message (ServiceBusMessage): The message received from the Service Bus.

        Raises:
            FatalQueueingException: If the content understanding has fatal warnings.
            RetryQueueingException: If the video is still processing or an error occurs during processing.
        """

        # Log that a message has been received
        logger.info("Received message")

        # Access the message body appropriately
        message_content: str = str(message)
        correlation_id: uuid.UUID = message.application_properties.get("correlationId", None)
        trace_id: uuid.UUID = message.application_properties.get("traceId", None)

        # Deserialize the message content into a VideoUploadMetadata object
        video_upload_metadata = VideoUploadMetadata.model_validate_json(message_content)

        # Retrieve the content understanding status for the given video ID
        # Raise a retrial exception if the endpoint is unreachable for some reason
        content_result = await self.get_content_understanding_status(
            video_upload_metadata=video_upload_metadata
        )

        if content_result.status == "Succeeded":

            # Check if there are any warnings in the content understanding result
            if content_result.result.warnings and len(content_result.result.warnings) > 0 and (
                    len(content_result.result.contents) == 0 or not content_result.result.contents[0].fields):
                # Raise a fatal exception if there are warnings in the content understanding result
                logger.warning(f"Content Understanding has fatal warnings: {content_result.result.warnings}")
                raise FatalQueueingException("Content Understanding has fatal warnings")

            # Check if there are any contents in the content understanding result
            if not content_result.result.contents or len(content_result.result.contents) == 0:
                # Raise a fatal exception if there are no contents in the content understanding result
                logger.warning(f"Content Understanding output has no content: {content_result.result.contents}")
                raise FatalQueueingException("Content Understanding has no content")

            # Log that the video processing has completed successfully
            logger.info("Video processing succeeded, on Content Understanding. Creating video description...")

            # Extract the main subjects or topics discussed throughout the video
            video_subjects = await self.llm_video_analysis_service.find_video_subjects(
                content_result=content_result, video_upload_metadata=video_upload_metadata
            )

            # Critically assess and potentially improve the initial subject segmentation
            video_subjects = await self.llm_video_analysis_service.critique_or_improve_video_subjects(
                content_result=content_result,
                initial_subjects=video_subjects,
                video_upload_metadata=video_upload_metadata
            )

            # Splits the content_result.result.contents into several lists of contents
            # by the start and end time of each video_subjects
            subjects_content = [
                {
                    "subject": subject.title,
                    "contents": [content for content in content_result.result.contents
                                 if
                                 content.startTimeMs >= subject.startTimeMs and content.endTimeMs <= subject.endTimeMs]
                }
                for subject in video_subjects.subjects
            ]

            # Generate the summary for each content list
            for subject_content in subjects_content:
                # Generate the summary for the video segment
                # Raise a retrial exception if the video summary generation fails
                content_summary = await self.llm_video_analysis_service.create_video_summary(
                    contents=subject_content["contents"], subject=subject_content["subject"],
                    video_upload_metadata=video_upload_metadata
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

                # Log that the summarized message has been sent successfully
                logger.info("Video segment event produced successfully")

            if video_upload_metadata.isUploaded:
                file_name: str = get_file_name_from_url(video_upload_metadata.fileUrl)
                await self.file_upload_service.delete_blob(file_name)

            # Log that the summarized message has been sent successfully
            logger.info("Video description event produced successfully")
        else:
            # Raise a retrial exception if the video is still processing
            raise RetryQueueingException(
                "Video still processing on Content Understanding",
                video_upload_metadata.model_dump_json()
            )

    async def get_content_understanding_status(
            self, video_upload_metadata: VideoUploadMetadata
    ) -> ContentResult:
        """
        Retrieves the content understanding status for a given content ID.

        Args:
            video_upload_metadata: The metadata of the uploaded video.

        Returns:
            ContentResult: The result containing the status and details of content understanding.

        Raises:
            Exception: Propagates any exception encountered while fetching the content status.
        """
        try:
            # Fetch the status of the content analysis
            content_result = await self.content_understanding_client.get_content_status(
                content_id=video_upload_metadata.videoId
            )

            return content_result
        except Exception as e:
            # Raise
            raise RetryQueueingException(
                "Error getting video description from Content Understanding",
                video_upload_metadata.model_dump_json()
            )
