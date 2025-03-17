import logging

from openai import AsyncAzureOpenAI

from ..exceptions import RetryQueueingException
from ..models import VideoUploadMetadata, ContentResult, Content, VideoSubjects

logger = logging.getLogger(__name__)

class LLMVideoAnalysisService:

    def __init__(
        self,
        openai_service: AsyncAzureOpenAI,
        openai_model_name: str,
    ) -> None:
        self.openai_service = openai_service
        self.openai_model_name = openai_model_name
        
    async def find_video_subjects(
        self,
        content_result: ContentResult,
        video_upload_metadata: VideoUploadMetadata,
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
            response = await self.openai_service.beta.chat.completions.parse(
                response_format=VideoSubjects,
                model=self.openai_model_name,
                messages=[
                    {
                        "role": "system",
                        "content": """
                            You are an expert assistant specialized in video content understanding and high-level topic segmentation.
                            Your task is to analyze segmented video content and extract a concise list of distinct and meaningful subjects or topics discussed throughout the video.

                            Focus on identifying coherent, high-level content blocks rather than splitting the video into very small or overly specific sections.
                            Each subject should cover a logically complete and cohesive section of the video, typically several minutes in length or encompassing a full concept or feature explanation.

                            Avoid segmenting based on minor or superficial changes. Instead, aim to merge similar or closely related segments under one clear subject if they belong to the same logical theme.

                            When naming subjects, always try to use the **same language, product terms, feature names, expressions, or UI labels that are spoken or shown in the video content**.
                            Do not generalize subject titles if a more specific term or phrase was used in the presentation.

                            Your output must be a structured JSON object with subject titles and their corresponding start and end time in milliseconds.
                        """
                    },
                    {
                        "role": "user",
                        "content": f"""
                            You will now receive a comprehensive summary composed of multiple video segments.
                            Each segment includes content such as descriptions, key takeaways, sentiment, visual context, and time ranges.

                            Your goal is to extract a list of high-level subjects or topics that are clearly presented throughout the video.
                            Group the content into broader and more cohesive subjects that reflect the main themes, demonstrations, or conceptual blocks.

                            ### Key Instructions:
                            - Avoid splitting based on small changes or minor transitions in wording or examples.
                            - Group segments into wider themes such as:
                              - Product overview
                              - Key feature demonstrations
                              - Workflow walkthroughs
                              - Benefits and value propositions
                              - Customer scenarios
                              - Pricing and plans
                              - Call to action
                            - Merge similar segments together when they contribute to the same topic.
                            - Only create a new subject when the video clearly shifts to a different high-level idea or topic.
                            - **When writing subject titles, prioritize using the exact words, product names, feature labels, or phrases that are spoken by presenters or shown on-screen during the video.**
                            - Do not paraphrase or use generic subject titles when more specific terminology is clearly used in the content.

                            Now analyze the segments below and group them into broader subjects accordingly:

                            {combined_summary}
                        """
                    }
                ]
            )

            # Extract and return the generated summary from the response
            return response.choices[0].message.parsed
        except Exception:
            # Raise a retrial exception if the summary generation fails
            logger.warning("Error creating video description")
            raise RetryQueueingException(
                "Error creating video description",
                video_upload_metadata.model_dump_json()
            )

    async def critique_or_improve_video_subjects(
        self,
        content_result: ContentResult,
        initial_subjects: VideoSubjects,
        video_upload_metadata: VideoUploadMetadata,
    ) -> VideoSubjects:
        """
        Critically assesses the initial subject segmentation of a video and improves it if necessary using Azure OpenAI.

        This method acts as a refinement layer after an initial subject extraction step. It analyzes the segmented video content
        alongside the current subject list, and decides whether it is cohesive, high-level, and appropriately structured.
        If the list is too fragmented, inconsistent, or not representative of the content, it will generate an improved version.

        Args:
            content_result (ContentResult): The result of the video analysis containing segmented content.
            initial_subjects (VideoSubjects): The initially generated list of subjects to assess and potentially refine.
            video_upload_metadata (VideoUploadMetadata): Metadata about the uploaded video, used for logging or retrying purposes.

        Returns:
            VideoSubjects: A validated list of subjects — either the original if considered suitable, or an improved version.
        """
        try:
            # Stitch the summary just like in the initial step
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

            # Prepare the initial subject list as JSON for injection
            initial_subjects_json = initial_subjects.model_dump_json(indent=2)

            # Ask OpenAI to assess and optionally improve the subject list
            response = await self.openai_service.beta.chat.completions.parse(
                response_format=VideoSubjects,
                model=self.openai_model_name,
                messages=[
                    {
                        "role": "system",
                        "content": """
                            You are an expert assistant specialized in video content understanding and topic segmentation.

                            Your task is to analyze segmented video content and an existing subject list to determine whether it is structured appropriately.
                            
                            The ideal subject list should:
                            - Reflect **clear, meaningful, high-level content blocks**
                            - Be **cohesive and logically grouped**
                            - **Avoid unnecessary fragmentation** into small or insignificant subjects
                            - **Avoid overly broad generalizations** where distinct parts of the content lose clarity
                            - Use the **same language, terminology, and expressions** as used in the original presentation
                            
                            If some subjects are too fragmented or redundant, **consolidate them**.
                            If some subjects are too vague or too broad, **break them down** into clearer subtopics.
                            
                            Only split or merge subjects when it truly improves clarity, structure, and representation of the content.  
                            Do **not** create subjects that are too short, shallow, or disconnected just to increase granularity.
                            
                            Always return a **well-balanced and faithful segmentation**, aligned with the structure and flow of the content.
                            Your output must be a structured JSON list of subjects, with appropriate titles and start/end times in milliseconds.
                        """
                    },
                    {
                        "role": "user",
                        "content": f"""
                            Please review and improve the previous subject segmentation.

                            Consider whether:
                            - Some subjects are too fragmented or redundant and should be grouped.
                            - Some subjects are too broad or vague and should be broken into clearer, more precise subtopics.
                            - The structure accurately reflects the **natural flow and conceptual blocks** in the content.

                            Avoid unnecessary micro-segmentation. Do not split content unless it truly improves clarity or structure.
                            Aim for a well-balanced list of subjects that accurately represents how the product, features, ideas, etc were presented.

                            Use the **same terminology and tone** as in the content itself.

                            ### Full Content Description:
                            {combined_summary}

                            ### Initial Subjects List:
                            {initial_subjects.model_dump_json(indent=2)}
                        """
                    }
                ]
            )

            return response.choices[0].message.parsed

        except Exception:
            logger.warning("Error during subject list assessment and improvement")
            raise RetryQueueingException(
                "Error assessing/improving subject list",
                video_upload_metadata.model_dump_json()
            )

    async def create_video_summary(
        self,
        subject: str,
        contents: list[Content],
        video_upload_metadata: VideoUploadMetadata,
    ) -> str:
        """
        Generates a structured, product-oriented documentation-like narrative from segmented video content using Azure OpenAI.

        The resulting document should reflect how a product owner, sales person, or internal documentation writer would describe
        the product or feature — using clear structure, terminology, steps, flows, use cases, benefits, and guidance — without
        ever referring to videos, segments, transcripts, or technical analysis.

        Args:
            subject (str): The main subject or topic presented in the video (e.g., a product feature, onboarding flow, use case).
            contents (list[Content]): The analyzed video splits, containing descriptions, UI context, actions, and spoken content.
            video_upload_metadata (VideoUploadMetadata): Metadata of the uploaded video.

        Returns:
            str: A natural, highly structured product-oriented document written in a clear and narrative tone.
        """
        try:
            # Compile all structured content blocks into one large stitched body
            content_blocks = [
                (
                    f"### Content Block {index + 1}\n"
                    f"- **Description:** {c.fields.description}\n"
                    f"- **On-screen Text:** {c.fields.onScreenText}\n"
                    f"- **Actions:** {c.fields.actions}\n"
                    f"- **Visual Context:** {c.fields.visualContext}\n"
                    f"- **Key Takeaways:** {c.fields.keyTakeaways}\n"
                    f"- **Spoken Keywords:** {c.fields.spokenKeywords}"
                )
                for index, c in enumerate(contents)
            ]
            stitched_context = "\n\n".join(content_blocks)

            # Send a new request to OpenAI with a product-documentation-oriented role prompt
            response = await self.openai_service.chat.completions.create(
                model=self.openai_model_name,
                messages=[
                    {
                        "role": "system",
                        "content": """
                            You are a professional documentation writer, product owner, or product marketer.

                            Your task is to transform structured product content into a **clear, cohesive, and professionally written product documentation or internal guide**.

                            The tone should be informative, product-driven, and structured — like an internal product feature spec, onboarding documentation, sales enablement doc, or product walkthrough.

                            The document must sound like it was written directly by a product manager or sales expert who is describing the product and how it works.

                            Do not mention "video", "segments", "content blocks", or anything about how this was generated.
                            Focus on producing a **natural, structured, informative narrative** that provides:
                            - Descriptions of product concepts or flows
                            - Step-by-step walkthroughs if applicable
                            - Key features and benefits
                            - UI details and interactions
                            - Clear headings and natural transitions

                            Use proper structure, subheadings, and smooth transitions. Maintain clarity and readability throughout.
                            Use actual language and terminology presented in the content.
                        """
                    },
                    {
                        "role": "user",
                        "content": f"""
                            Please write a product-oriented documentation piece based on the content provided below.
                        
                            ## Main Subject
                            {subject}
                        
                            ## Context to work from:
                            {stitched_context}
                        
                            ## Instructions
                            - Write clearly and naturally.
                            - Structure the document with headings, subheadings, and paragraph flows.
                            - Describe features, flows, and interactions as if explaining to a colleague or customer.
                            - If the content suggests steps, explain the steps as bullet points or paragraphs.
                            - Use actual phrases or feature names found in the original content.
                            - Do not reference content blocks or the source format.
                            - Ensure it reads like a naturally authored internal documentation piece or sales deck.
                        """
                    }
                ]
            )

            return response.choices[0].message.content

        except Exception:
            logger.warning("Error creating video documentation")
            raise RetryQueueingException(
                "Error creating video documentation",
                video_upload_metadata.model_dump_json()
            )
