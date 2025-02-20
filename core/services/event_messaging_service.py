import logging
import uuid
import asyncio

from typing import Protocol, Callable
from datetime import datetime

from azure.servicebus.aio import ServiceBusClient
from azure.core.credentials import AzureNamedKeyCredential

class EventMessagingService(Protocol):
    def __init__(self, endpoint: str, api_key_name: str, api_key: str, logger: logging.Logger):
        self.endpoint = endpoint
        self.api_key = api_key
        self.api_key_name = api_key_name
        self.logger = logger
        self.credential = AzureNamedKeyCredential(name=api_key_name, key=api_key)
        self.client = ServiceBusClient(
            fully_qualified_namespace=endpoint,
            credential=self.credential
        )

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def send_message(
            self,
            queue_name: str,
            body: str,
            correlation_id: uuid.UUID = None
    ) -> uuid.UUID:
        """
        Sends a message to a specified queue.

        Args:
            queue_name (str): The name of the queue to send the message to.
            body (str): The content of the message.
            correlation_id (uuid.UUID, optional): An optional UUID to correlate messages.
                                                  If not provided, a new UUID is generated.

        Returns:
            uuid.UUID: The correlation ID of the sent message.
        """

    async def schedule_message(
            self,
            queue_name: str,
            body: str,
            schedule_time_utc: datetime,
            correlation_id: uuid.UUID = None
    ) -> uuid.UUID:
        """
        Schedules a message to be sent to a specified queue at a future time.

        Args:
            queue_name (str): The name of the queue to send the message to.
            body (str): The content of the message.
            schedule_time_utc (datetime): The UTC datetime when the message should be enqueued.
            correlation_id (uuid.UUID, optional): An optional UUID to correlate messages.
                                                    If not provided, a new UUID is generated.

        Returns:
            uuid.UUID: The correlation ID of the scheduled message.
        """

    async def process_messages(
            self,
            queue_name: str,
            stop_event: asyncio.Event,
            message_handler: Callable
    ):
        """
        Processes messages from a queue receiver and delegates message processing
        to the provided message_handler function.

        Args:
            queue_name (str): The name of the queue to listen to.
            stop_event (asyncio.Event): An event to signal when to stop processing.
            message_handler (Callable): A coroutine function to handle individual messages.
        """

    async def close(self):
        """
        Asynchronous context manager exit point.
        Cleans up the Messaging Service client.
        """

    