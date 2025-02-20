# Index File API

This API service receives file payloads, processes them by creating corresponding blob metadata, and forwards the requests to an Azure Service Bus queue for further processing.

## Settings

The application uses the following settings, which can be configured via environment variables or a `.env` file:

- `service_bus_namespace`: Fully qualified namespace for Azure Service Bus.
- `index_file_queue`: Name of the queue for index files.
- `logging_level`: Optional logging level (e.g., DEBUG, INFO). Defaults to `ERROR`.
- `host`: Host address for the API server. Defaults to `0.0.0.0`.
- `port`: Port number for the API server. Defaults to `8000`.

## How to Run

To run the Summarize Video Content service:
1. Ensure dependencies are installed and environment variables are set (using a .env file).
2. Run the service with:
   - Development: `uv run index_file_api --env-file .env`
   - Docker:
     a. Build with: `docker build -t index_file_api . --build-arg PROJECTPATH=index_file_api`
     b. Run the resulting container.
