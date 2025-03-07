import logging

from dependency_injector import containers, providers

from core import create_service_bus_client, create_azure_credential
from core.services import ServiceBusEventMessagingService


class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

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

    service_bus_messaging_service = providers.Singleton(
        ServiceBusEventMessagingService,
        service_bus_client=service_bus_client,
    )
