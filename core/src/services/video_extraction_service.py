from typing import Protocol
from ..models import ContentResult

class VideoExtractionService(Protocol):
    async def extract_video_at_url(self, content_url: str) -> str:
        """
        Extracts and analyzes a video at the given url.

        Args:
            content_url (str): The URL of the content to analyze.

        Returns:
            str: An ID to query the service for the analysis result.
        """
        pass

    async def get_extracted_video_status(self, content_id: str) -> ContentResult:
        """
        Retrieves the status of the extraction and analysis process.

        Args:
            content_id (str): The ID of the content to check.

        Returns:
            ContentResult: The result of the content analysis.
        """
        pass
