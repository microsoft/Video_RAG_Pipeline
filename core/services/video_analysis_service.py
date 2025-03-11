from typing import Protocol
from core.models import ContentResult

class VideoAnalysisService(Protocol):
    async def analyze_video_at_url(self, content_url: str) -> str:
        """
        Uploads a content URL for analysis.

        Args:
            content_url (str): The URL of the content to analyze.

        Returns:
            str: An ID to query the service for the analysis result.
        """

    async def get_content_status(self, content_id: str) -> ContentResult:
        """
        Retrieves the status of the analyzed content.

        Args:
            content_id (str): The ID of the content to check.

        Returns:
            ContentResult: The result of the content analysis.
        """

