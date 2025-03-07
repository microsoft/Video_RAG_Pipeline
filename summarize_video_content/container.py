import logging

from dependency_injector import containers, providers
from openai import AzureOpenAI

from core import (
    create_service_bus_client,
    create_azure_credential,
    create_token_provider, 
    ServiceBusEventMessagingService,
    ContentUnderstandingClient,
    AzureBlobFileUploadService, 
    create_content_understanding_http_client_session
)

from summarize_video_content.message_handler import MessageHandler

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

    token_provider_resource = providers.Resource(
        create_token_provider
    )

    openai_service_key_auth = providers.Singleton(
        AzureOpenAI,
        api_key=config.azure_openai_key,
        api_version=config.azure_openai_api_version,
        azure_endpoint=config.azure_openai_endpoint
    )

    openai_service_managed_identity_auth = providers.Singleton(
        AzureOpenAI,
        azure_ad_token_provider=token_provider_resource,
        api_version=config.azure_openai_api_version,
        azure_endpoint=config.azure_openai_endpoint
    )

    openai_service = providers.Selector(
        config.azure_openai_auth_type,
        key=openai_service_key_auth,
        managed_identity=openai_service_managed_identity_auth
    )

    service_bus_messaging_service = providers.Singleton(
        ServiceBusEventMessagingService,
        service_bus_client=service_bus_client,
    )

    message_handler = providers.Singleton(
        MessageHandler,
        service_bus_messaging_service=service_bus_messaging_service,
        file_upload_service=file_upload_service,
        content_understanding_client=content_understanding_client,
        openai_service=openai_service,
        openai_model_name=config.azure_openai_model_name,
        finalize_content_queue_name=config.finalize_content_queue,
        video_summary_queue_name=config.video_summary_queue
    )
