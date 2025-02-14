# Chunk Video Content

This application downloads GIF files, converts them to MP4 format, uploads the converted files to Azure Blob Storage, and processes video content using integrated services such as content understanding and event messaging.

## Settings

The application uses the following settings, which can be configured via environment variables or a `.env` file:

- `service_bus_fully_qualified_namespace`: Fully qualified namespace for Azure Service Bus.
- `index_blob_queue`: Name of the queue for indexing blobs.
- `finalize_content_queue`: Name of the queue for finalizing content processing.
- `content_understanding_url`: URL endpoint for the content understanding service.
- `content_understanding_key`: API key for authenticating with the content understanding service.
- `content_understanding_api_version`: API version to use for the content understanding service.
- `video_analyzer_name`: Name identifier for the video analyzer service.
- `storage_account_name`: Azure Storage account name.
- `container_name`: Name of the blob container in Azure Storage.
- `mp4_output_path`: Filesystem path where MP4 output files will be stored.
- `logging_level`: Optional logging level (e.g., DEBUG, INFO). Defaults to `ERROR`.

## How to Run

To run the Summarize Video Content service:
1. Ensure dependencies are installed and environment variables are set (using a .env file).
2. Run the service with:
   - Development: `uv run chunk_video_content --env-file .env`
   - Docker:
     a. Build with: `docker build -t chunk_video_content . --build-arg PROJECTPATH=chunk_video_content`
     b. Run the resulting container.
