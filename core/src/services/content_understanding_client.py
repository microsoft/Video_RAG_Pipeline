import aiohttp
import logging
from typing import Optional

from ..models import ContentResult
from .video_extraction_service import VideoExtractionService
class ContentUnderstandingClient(VideoExtractionService):
    """
    An asynchronous client for interacting with the Content Understanding API using aiohttp.

    Attributes:
        session (aiohttp.ClientSession): The asynchronous HTTP client session instance.
        endpoint (str): The base URL for the Content Understanding API.
        api_version (str): The API version to use.
        logger (logging): Logger instance for logging activities.
    """

    def __init__(
            self,
            session: aiohttp.ClientSession,
            endpoint: str,
            api_version: str,
            analyzer_name: str,
    ):
        """
        Initialize the ContentUnderstandingClient with the endpoint, key, and API version.

        Args:
            session (aiohttp.ClientSession): The asynchronous HTTP client session instance.
            endpoint (str): The base URL for the Content Understanding API.
            api_version (str): The API version to use.
            logger (logging.Logger): Logger instance for logging activities.
        """
        self.endpoint = endpoint.rstrip('/')  # Ensure no trailing slash
        self.api_version = api_version
        self.analyzer_name = analyzer_name
        self.session: Optional[aiohttp.ClientSession] = session

        # Initialize the logger
        self.logger = logging.getLogger(__name__)

    async def get_extracted_video_status(self, content_id: str) -> ContentResult:
        """
        Retrieves the status of the extraction and analysis process.

        Args:
            content_id (str): The ID of the content to check.

        Returns:
            ContentResult: The result of the content analysis.

        Raises:
            aiohttp.ClientResponseError: If the HTTP request returned an unsuccessful status code.
            Exception: For any other exceptions that may occur.
        """
        url = (
            f"{self.endpoint}/contentunderstanding/analyzers/{self.analyzer_name}/"
            f"results/{content_id}?api-version={self.api_version}"
        )
        self.logger.debug(f"GET URL: {url}")

        try:
            async with self.session.get(url) as response:
                response.raise_for_status()
                response_data = await response.json()
                self.logger.debug(f"Response Data: {response_data}")
                parsed_data = ContentResult(**response_data)
                self.logger.info(f"Retrieved content status for ID: {content_id}")
                return parsed_data
        except aiohttp.ClientResponseError as http_err:
            self.logger.error(f"HTTP error occurred: {http_err} - Response: {http_err.message}")
            raise
        except Exception as err:
            self.logger.exception(f"An unexpected error occurred while getting content status: {err}")
            raise

    async def extract_video_at_url(self, content_url: str) -> str:
        """
        Extracts and analyzes a video at the given url.

        Args:
            content_url (str): The URL of the content to analyze.

        Returns:
            str: An ID to query the service for the analysis result.

        Raises:
            aiohttp.ClientResponseError: If the HTTP request returned an unsuccessful status code.
            Exception: For any other exceptions that may occur.
        """
        url = (
            f"{self.endpoint}/contentunderstanding/analyzers/{self.analyzer_name}:analyze"
            f"?api-version={self.api_version}"
        )

        self.logger.debug(f"POST URL: {url}")

        data = {
            "url": content_url
        }

        self.logger.debug(f"POST Payload: {data}")

        try:
            async with self.session.post(url, json=data) as response:
                response.raise_for_status()
                response_data = await response.json()
                result_id = response_data.get('id')
                if not result_id:
                    self.logger.error("Response JSON does not contain 'id'.")
                    raise ValueError("Response JSON does not contain 'id'.")
                self.logger.info(f"Uploaded content URL. Result ID: {result_id}")
                return result_id
        except aiohttp.ClientResponseError as http_err:
            # Extract response text if available
            try:
                # TODO: review this, it doesn't seem to be working
                error_text = await http_err.response.text()
            except Exception:
                error_text = "No response text available."
            self.logger.error(f"HTTP error occurred: {http_err} - Response: {error_text}")
            raise
        except Exception as err:
            self.logger.exception(f"An unexpected error occurred while uploading URL: {err}")
            raise
