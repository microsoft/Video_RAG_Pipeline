from .video_analysis_service import VideoAnalysisService
from core.models import ContentResult

class MultiModalLLMAnalysisService(VideoAnalysisService):
    async def analyze_video_at_url(self, content_url: str) -> str:
        """
        Uploads a content URL for analysis.

        Args:
            content_url (str): The URL of the content to analyze.

        Returns:
            str: An ID to query the service for the analysis result.
        """
        raise NotImplementedError

    async def get_content_status(self, content_id: str) -> ContentResult:
        """
        Retrieves the status of the analyzed content.

        Args:
            content_id (str): The ID of the content to check.

        Returns:
            ContentResult: The result of the content analysis.
        """
        raise NotImplementedError
