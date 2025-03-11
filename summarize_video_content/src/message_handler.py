import logging
import uuid

from azure.servicebus import ServiceBusMessage
from openai import AzureOpenAI

from core import (
    ContentResult,
    SummarizedVideoMetadata,
    ServiceBusEventMessagingService,
    VideoUploadMetadata,
    ContentUnderstandingClient,
    AzureBlobFileUploadService,
    FatalQueueingException,
    RetryQueueingException
)

from core import get_file_name_from_url

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
            if content_result.result.warnings and len(content_result.result.warnings) > 0:
                # Raise a fatal exception if there are warnings in the content understanding result
                logger.warning(f"Content Understanding has fatal warnings: {content_result.result.warnings}")
                raise FatalQueueingException("Content Understanding has fatal warnings")

            # Log that the video processing has completed successfully
            logger.info("Video processing succeeded, on Content Understanding. Creating video description...")

            # Generate the summary for the video content
            # Raise a retrial exception if the video summary generation fails
            content_summary = await self.create_video_summary(
                content_result=content_result, video_upload_metadata=video_upload_metadata
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
            logger.info("Video description event produced successfully")
        else:
            # Raise a retrial exception if the video is still processing
            raise RetryQueueingException(
                "Video still processing on Content Understanding",
                video_upload_metadata.model_dump_json()
            )

    async def create_video_summary(
            self,
            content_result: ContentResult,
            video_upload_metadata: VideoUploadMetadata
    ) -> str:
        """
        Creates a summary of the video content using Azure OpenAI.

        Args:
            content_result (ContentResult): The result from content understanding indicating video analysis.
            video_upload_metadata (VideoUploadMetadata): The metadata of the uploaded video.

        Returns:
            str: The generated summary of the video content.

        Raises:
            Exception: Propagates any exception encountered during the summary creation process.
        """
        try:
            # Initialize a list to efficiently build the content string
            summaries = [
                (
                        f"#{index}\n\n## Description\n\n{content.fields.description}"
                        + f"\n\n## Sentiment\n\n{content.fields.sentiment}"
                        + f"\n\n## Actions\n\n{content.fields.actions}"
                        + f"\n\n## On screen text\n\n{content.fields.onScreenText}"
                        + f"\n\n## Key takeaways\n\n{content.fields.keyTakeaways}"
                        + f"\n\n## Spoken keywords\n\n{content.fields.spokenKeywords}"
                        + f"\n\n## Visual context\n\n{content.fields.visualContext}"
                        + f"\n\n## Tone analysis\n\n{content.fields.toneAnalysis}"
                )
                for index, content in enumerate(content_result.result.contents)
            ]
            combined_summary = "\n".join(summaries)

            # Create a comprehensive summary by sending a request to Azure OpenAI's chat completion endpoint
            response = self.openai_service.chat.completions.create(
                model=self.openai_model_name,
                messages=[
                    {
                        "role": "system",
                        "content": """
                            You are an expert in video analysis that specializes in synthesizing highly detailed, structured, 
                            and contextually rich descriptions of video content. Your goal is to merge multiple video segment analyses 
                            into a single, seamless, and highly descriptive transcription that captures all spoken words, on-screen text, 
                            visual context, actions, sentiment, tone, and any other relevant elements. 
                            Ensure your final output is well-organized, logically structured, and as comprehensive as possible, 
                            giving the reader a full understanding of what happens in the video without needing to watch it.
                        """

                    },
                    {
                        "role": "user",
                        "content": f"""  
                            Synthesize the provided segmented video descriptions into a **fully comprehensive, fluid, and detailed**  
                            textual representation of the entire video. Ensure the output **accurately preserves** and **integrates** all key elements  
                            while enhancing clarity, readability, and coherence.  
                    
                            **Key Instructions:**  
                            - **Merge all segments seamlessly**, ensuring natural and logical **transitions** between them.  
                            - **Preserve the chronological order** and structure the content in a **cohesive and flowing manner**.  
                            - Ensure that **spoken dialogue**, **on-screen text**, **visual elements**, **actions**, and **non-verbal cues**  
                              are all accurately represented.  
                            - Resolve any **overlaps, inconsistencies, or redundancies**, ensuring a **single, high-quality** transcription.  
                            - Capture the **tone and sentiment shifts** accurately, ensuring that any changes in speaker tone, emotion,  
                              or intent are conveyed effectively.  
                            - Highlight **any interactions with UI elements**, software features, product demonstrations, or relevant graphics.  
                            - Preserve **key takeaways and insights**, ensuring the final description retains all **critical** and **valuable**  
                              information from the original content.  
                            - **Enrich the transcription with contextual cues** that help clarify the video’s narrative, such as  
                              body language, gestures, audience reactions, or changes in speaker emphasis.  
                    
                            **Expected Output:**  
                            A **well-structured, fully detailed, and highly readable** description that reads as if it were a **meticulously crafted summary**  
                            of the video. It should **not** feel like a stitched-together transcript but rather a **coherent, engaging, and insightful**  
                            interpretation of the full video.  
                    
                            Generate the full comprehensive transcription based on the **following segmented content**:  
                    
                            {combined_summary}  
                        """
                    }
                ]
            )

            # Extract and return the generated summary from the response
            return response.choices[0].message.content
        except Exception:
            # Raise a retrial exception if the summary generation fails
            logger.warning("Error creating video description")
            raise RetryQueueingException(
                "Error creating video description",
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
