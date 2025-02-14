# Summarize Video Content

This application analyzes video content by retrieving transcribed segments, generating a comprehensive summary using Azure OpenAI, and sending the results for further processing.

## Settings

The application uses the following settings, which can be configured via environment variables or a `.env` file:

- `service_bus_fully_qualified_namespace`: Fully qualified namespace for Azure Service Bus.
- `finalize_content_queue`: Name of the queue for finalizing content processing.
- `video_summary_queue`: Name of the queue for video summary tasks.
- `cognitive_services_endpoint`: Endpoint URL for Azure Cognitive Services API.
- `azure_openai_endpoint`: Endpoint URL for Azure OpenAI Service.
- `azure_openai_api_version`: API version for Azure OpenAI Service.
- `azure_openai_model_name`: Name of the model used in Azure OpenAI Service.
- `content_understanding_endpoint`: Endpoint URL for the Content Understanding API.
- `content_understanding_api_version`: API version for the Content Understanding API.
- `content_understanding_key`: Subscription key for authenticating with the Content Understanding API.
- `video_analyzer_name`: Name of the video analyzer used for processing videos.
- `storage_account_name`: Name of the Azure Storage account where blobs are stored.
- `storage_container_name`: Name of the container within the Azure Storage account.
- `logging_level`: Optional logging level (e.g., DEBUG, INFO). Defaults to `ERROR`.

## How to Run

To run the Summarize Video Content service:
1. Ensure dependencies are installed and environment variables are set (using a .env file).
2. Run the service with:
   - Development: `uv run summarize_video_content --env-file .env`
   - Docker:
     a. Build with: `docker build -t summarize_video_content . --build-arg PROJECTPATH=summarize_video_content`
     b. Run the resulting container.
