import uuid
import logging

from azure.servicebus import ServiceBusMessage

from core import (
    ContentResult,
    VideoUploadMetadata,
    ProcessingResultEvent,
    AzureBlobFileUploadService,
    LLMVideoAnalysisService,
    EventMessagingService,
    VideoExtractionService,
    FatalQueueingException,
    RetryQueueingException,
    get_file_name_from_url,
)

logger = logging.getLogger(__name__)

class MessageHandler:

    def __init__(
        self,
        event_messaging_service: EventMessagingService,
        file_upload_service: AzureBlobFileUploadService,
        video_extraction_service: VideoExtractionService,
        llm_video_analysis_service: LLMVideoAnalysisService,
        finalize_content_queue_name: str,
        video_summary_queue_name: str,
    ):
        """
        Creates an asynchronous message handler function for processing incoming Service Bus messages.

        :param event_messaging_service: The messaging service to send and receive messages.
        :param file_upload_service: The file upload service to manage uploaded content.
        :param video_extraction_service: The service for extracting video content.
        :param llm_video_analysis_service: The service for analyzing video content using Azure OpenAI.
        :param finalize_content_queue_name: The name of the queue for finalizing content processing.
        :param video_summary_queue_name: The name of the queue for sending video summaries.

        :return: A new instance of the MessageHandler class.
        """
        self.event_messaging_service = event_messaging_service
        self.file_upload_service = file_upload_service

        self.video_extraction_service = video_extraction_service

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
        logger.debug("Received message")

        # Access the message body appropriately
        message_content: str = str(message)
        correlation_id: uuid.UUID = message.application_properties.get(b"correlationId")
        trace_id: uuid.UUID = message.application_properties.get(b"traceId")

        logger.debug(f"Analysing received message :: correlation_id={correlation_id}")

        # Deserialize the message content into a VideoUploadMetadata object
        video_upload_metadata = VideoUploadMetadata.model_validate_json(message_content)

        # Retrieve the content understanding status for the given video ID
        # Raise a retrial exception if the endpoint is unreachable for some reason
        content_result = await self.get_video_extraction_status(
            video_upload_metadata=video_upload_metadata
        )

        if content_result.status == "Succeeded":
            # Check if there are any warnings in the content understanding result
            if content_result.result.warnings and len(content_result.result.warnings) > 0 and len(content_result.result.contents) == 0 and len(content_result.result.contents[0].fields) == 0:
                # Raise a fatal exception if there are warnings in the content understanding result
                if len(content_result.result.contents) == 0 or not content_result.result.contents[0].fields:
                    raise FatalQueueingException(f"Content Understanding has fatal warnings :: correlation_id={correlation_id}")

            # Check if there are any contents in the content understanding result
            if not content_result.result.contents or len(content_result.result.contents) == 0:
                # Raise a fatal exception if there are no contents in the content understanding result
                logger.warning(f"Content Understanding output has no content: {content_result.result.contents} :: correlation_id={correlation_id}")
                raise FatalQueueingException(f"Content Understanding has no content :: correlation_id={correlation_id}")

            # Log that the video processing has completed successfully
            logger.info(f"Video processing succeeded on Content Understanding :: starting video analysis and description process :: correlation_id={correlation_id}")

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
            subjects_content_sets = video_subjects.to_subject_content_sets(content_result.result.contents)

            # Generate the summary for each content list
            for subject_content_set in subjects_content_sets:
                # Generate the summary for the video segment
                # Raise a retrial exception if the video summary generation fails
                subject_content = await self.llm_video_analysis_service.create_video_summary(
                    subject=subject_content_set.title,
                    contents=subject_content_set.content,
                    video_upload_metadata=video_upload_metadata
                )

                # Create a ProcessingResultEvent object to send to the final video summary queue
                processing_result = ProcessingResultEvent(
                    title=subject_content_set.title,
                    description=subject_content,
                    startTimeMs=subject_content_set.startTimeMs,
                    endTimeMs=subject_content_set.endTimeMs
                )

            # Send the summarized metadata to the designated queue
            await self.event_messaging_service.send_message(
                queue_name=self.video_summary_queue_name,
                body=processing_result.model_dump_json(),
                correlation_id=correlation_id,
                trace_id=trace_id
            )

            # Log that the summarized message has been sent successfully
            logger.info(f"Processing result event produced successfully :: correlation_id={correlation_id}")

            if video_upload_metadata.isUploaded:
                file_name: str = get_file_name_from_url(video_upload_metadata.fileUrl)
                await self.file_upload_service.delete_blob(file_name)

            # Log that the summarized message has been sent successfully
            logger.info(f"Full video processing result events produced successfully :: correlation_id={correlation_id}")
        else:
            # Raise a retrial exception if the video is still processing
            raise RetryQueueingException(
                f"Video still processing on Content Understanding :: correlation_id={correlation_id}",
                video_upload_metadata.model_dump_json()
            )

    async def get_video_extraction_status(
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
            content_result = await self.video_extraction_service.get_extracted_video_status(
                content_id=video_upload_metadata.videoId
            )

            return content_result
        except Exception as e:
            # Raise
            raise RetryQueueingException(
                "Error getting video description from Video Extraction Service",
                video_upload_metadata.model_dump_json()
            )
