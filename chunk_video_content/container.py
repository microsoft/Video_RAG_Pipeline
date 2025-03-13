import logging

from dependency_injector import containers, providers

from core import create_azure_credential, create_service_bus_client, create_content_understanding_http_client_session
from core.services import ServiceBusEventMessagingService, ContentUnderstandingClient, AnimatedGifConverter, \
    AzureBlobFileUploadService, VideoExtractionService, MultiModalLLMExtractionService

from chunk_video_content.message_handler import MessageHandler


class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

    http_client_session = providers.Resource(
        create_content_understanding_http_client_session,
        key=config.content_understanding_key,
        logger=logging.getLogger(__name__)
    )

    service_bus_client = providers.Resource(
        create_service_bus_client,
        endpoint=config.service_bus_namespace,
        credential=providers.Resource(
            create_azure_credential,
            config.service_bus_api_key_name,
            config.service_bus_api_key
        ),
        logger=logging.getLogger(__name__)
    )

    content_understanding_client = providers.Singleton(
        ContentUnderstandingClient,
        session=http_client_session,
        endpoint=config.content_understanding_endpoint,
        analyzer_name=config.video_analyzer_name,
        api_version=config.content_understanding_api_version,
    )

    multi_modal_llm_extraction_service = providers.Singleton(
        MultiModalLLMExtractionService
    )

    video_extraction_service = providers.Selector(
        config.extraction_service_type,
        content_understanding=content_understanding_client,
        multimodal_llm=multi_modal_llm_extraction_service
    )

    gif_converter = providers.Singleton(
        AnimatedGifConverter,
        download_dir=config.mp4_output_path,
        client_session=http_client_session
    )

    file_upload_service = providers.Singleton(
        AzureBlobFileUploadService,
        storage_account_name=config.storage_account_name,
        storage_container_name=config.storage_container_name,
        credential=providers.Resource(
            create_azure_credential,
            config.storage_account_name,
            config.storage_account_api_key
        )
    )

    service_bus_messaging_service = providers.Singleton(
        ServiceBusEventMessagingService,
        service_bus_client=service_bus_client,
    )

    event_messaging_service = providers.Selector(
        config.message_broker_type,
        service_bus=service_bus_messaging_service
    )

    message_handler = providers.Singleton(
        MessageHandler,
        event_messaging_service=event_messaging_service,
        gif_converter=gif_converter,
        video_extraction_service=video_extraction_service,
        blob_upload_service=file_upload_service,
        finalize_content_queue_name=config.finalize_content_queue,
    )
