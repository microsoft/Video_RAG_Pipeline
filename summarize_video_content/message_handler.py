import logging
import uuid
import json

from pydantic import ValidationError

from azure.servicebus import ServiceBusMessage
from openai import AzureOpenAI

from core import ContentResult, SummarizedVideoMetadata, ServiceBusEventMessagingService
from core.models import VideoUploadMetadata, VideoSubjects, Content
from core.services import ContentUnderstandingClient, AzureBlobFileUploadService
from core.exceptions import FatalQueueingException, RetryQueueingException

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

            # Check if there are any contents in the content understanding result
            if not content_result.result.contents or len(content_result.result.contents) == 0:
                # Raise a fatal exception if there are no contents in the content understanding result
                logger.warning(f"Content Understanding output has no content: {content_result.result.contents}")
                raise FatalQueueingException("Content Understanding has no content")

            # Log that the video processing has completed successfully
            logger.info("Video processing succeeded, on Content Understanding. Creating video description...")

            # Extract the main subjects or topics discussed throughout the video
            video_subjects = await self.find_video_subjects(
                content_result=content_result, video_upload_metadata=video_upload_metadata
            )

            # Splits the content_result.result.contents into several lists of contents
            # by the start and end time of each video_subjects
            contents_list = [
                [
                    content for content in content_result.result.contents
                    if content.startTimeMs >= subject.startTimeMs and content.endTimeMs <= subject.endTimeMs
                ]
                for subject in video_subjects.subjects
            ]

            # Generate the summary for each content list
            for contents in contents_list:
                # Generate the summary for the video segment
                # Raise a retrial exception if the video summary generation fails
                content_summary = await self.create_video_summary(
                    contents=contents, video_upload_metadata=video_upload_metadata
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

    async def find_video_subjects(
            self,
            content_result: ContentResult,
            video_upload_metadata: VideoUploadMetadata
    ) -> VideoSubjects:
        """
        Extracts and summarizes the main subjects or topics discussed throughout a video by analyzing segmented content using Azure OpenAI.

        This method takes the segmented video analysis output and constructs a detailed, structured prompt combining descriptions, actions, sentiment, visual context, and timestamps.
        It then submits this content to Azure OpenAI to identify and return a list of distinct subjects/topics that were presented across the video timeline, including their start and end times.

        Args:
            content_result (ContentResult): The result of the video analysis containing segmented content, including descriptions, key takeaways, and timestamps for each split.
            video_upload_metadata (VideoUploadMetadata): Metadata about the uploaded video, used for logging or retrying purposes in case of failure.

        Returns:
            VideoSubjects: A structured list of distinct subjects discussed in the video, each with a title, start time, and end time in milliseconds.

        Raises:
            RetryQueueingException: If the summarization or parsing process fails, a retryable exception is raised with metadata for downstream handling.
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
                        + f"\n\n## Time frame\n\n**Start time:** {content.startTimeMs}\n**End time:** {content.endTimeMs}"
                )
                for index, content in enumerate(content_result.result.contents)
            ]
            combined_summary = "\n".join(summaries)

            # Create a comprehensive summary by sending a request to Azure OpenAI's chat completion endpoint
            response = self.openai_service.chat.completions.create(
                response_format={
                    "type": "json_schema",
                    "json_schema": {
                        "name": VideoSubjects.__name__,
                        "description": "The subjects of the video content",
                        "schema": VideoSubjects.model_json_schema(),
                        "strict": True
                    }
                },
                model=self.openai_model_name,
                messages=[
                    {
                        "role": "system",
                        "content": """
                            You are an expert assistant specialized in content understanding and topic segmentation from video analysis data.  
                            Your task is to analyze detailed, segmented descriptions of a video and extract a structured list of **distinct subjects or topics**  
                            that are **presented or discussed** throughout the video.  
                            
                            Each subject must be identified based on **actual content coverage**—spoken dialogue, visual context, product demonstrations, feature explanations, or user interface interactions.  
                            
                            Your output must be a **JSON object** containing a list of subjects with their **start time and end time in milliseconds**, accurately reflecting when each subject begins and ends in the video timeline.
                            
                            Be as precise and concise as possible. Avoid repeating similar subjects if they fall under the same topic scope.
                        """

                    },
                    {
                        "role": "user",
                        "content": """  
                            You will now receive a comprehensive, detailed summary composed of individual video segments. Each segment includes a description, sentiment, on-screen text, visual context, tone, key takeaways, actions, spoken keywords, and its time frame in milliseconds.

                            Your goal is to extract the **list of topics or subjects that are discussed or presented across the entire video**.  
                            For each distinct subject, determine its **label (short, meaningful name or title)** and its corresponding **start and end time in milliseconds**, based on where it is first introduced and where it is no longer actively discussed.
                            
                            ### Important Guidelines:
                            - Subjects can represent **features**, **product capabilities**, **benefits**, **challenges**, **use cases**, **sales messaging**, **workflow walkthroughs**, **UI/UX demonstration segments**, etc.
                            - Merge and generalize **closely related segments** into a **single subject**, if they clearly belong to the same topic stream.
                            - Use timestamps from the original segments to **accurately map the duration** of each subject.
                            - Use short but clear **titles or labels** for each subject (e.g., "User Onboarding Flow", "Dashboard Features", "Pricing Overview", "Call to Action").
                            
                            ### Expected Output:
                            Return a **JSON object** with the following format:
                            ```json
                            {
                              "subjects": [
                                {
                                  "title": "Subject title here",
                                  "startTimeMs": 0,
                                  "endTimeMs": 54000
                                },
                                {
                                  "title": "Next subject title here",
                                  "startTimeMs": 54000,
                                  "endTimeMs": 115000
                                }
                                // ...
                              ]
                            }
                            ```

                            Analyze the segments below and extract the list of topics accordingly:\n\n
                        """ + combined_summary
                    }
                ]
            )

            # Extract and return the generated summary from the response
            return self.safely_parse_video_subjects(response.choices[0].message.content)
        except Exception:
            # Raise a retrial exception if the summary generation fails
            logger.warning("Error creating video description")
            raise RetryQueueingException(
                "Error creating video description",
                video_upload_metadata.model_dump_json()
            )

    def safely_parse_video_subjects(self, response_content: str) -> VideoSubjects:
        """
        Parses and validates the JSON response content returned by the OpenAI API to extract the list of video subjects.

        This utility function ensures the response is correctly formatted and maps it to the `VideoSubjects` Pydantic model.
        It handles common response formatting issues such as Markdown code block wrappers or extra text around the JSON.

        Args:
            response_content (str): The raw content string returned by OpenAI's chat completion API,
                                    expected to be a JSON object or wrapped in a Markdown-style code block.

        Returns:
            VideoSubjects: A validated object containing a list of subjects, each with title, start time, and end time in milliseconds.

        Raises:
            json.JSONDecodeError: If the content is not valid JSON or fails to parse.
            ValidationError: If the content fails to conform to the `VideoSubjects` schema.
        """
        try:
            # If wrapped in a Markdown code block, remove it
            if response_content.strip().startswith("```json"):
                response_content = response_content.strip().removeprefix("```json").removesuffix("```").strip()

            # Parse to dict
            data = json.loads(response_content)

            # Validate via Pydantic
            return VideoSubjects.model_validate(data)  # Use `.parse_obj(data)` if you're on Pydantic v1

        except (json.JSONDecodeError, ValidationError) as e:
            logger.error(f"Failed to parse LLM response content: {e}")
            raise e

    async def create_video_summary(
            self,
            contents: list[Content],
            video_upload_metadata: VideoUploadMetadata
    ) -> str:
        """
        Creates a summary of the video content using Azure OpenAI.

        Args:
            contents (list[Content]): The result from content understanding indicating video analysis.
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
                for index, content in enumerate(contents)
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
