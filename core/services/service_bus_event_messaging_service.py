import uuid
import asyncio
import logging

from typing import Callable
from datetime import datetime, timezone, timedelta

from concurrent.futures import ThreadPoolExecutor

from azure.servicebus import ServiceBusMessage
from azure.servicebus.aio import ServiceBusClient, AutoLockRenewer

from core.exceptions import FatalQueueingException, RetryQueueingException
from .event_messaging_service import EventMessagingService

class ServiceBusEventMessagingService(EventMessagingService):
    """
    A service class for interacting with Azure Service Bus, providing functionality to send,
    schedule, and process messages asynchronously.

    Attributes:
        service_bus_client (ServiceBusClient): The asynchronous Service Bus client instance.
        logger (logging.Logger): Logger instance for logging activities.
    """

    def __init__(self, service_bus_client: ServiceBusClient):
        """
        Initialize the ServiceBusEventMessagingService with the Service Bus client and logger.

        Args:
            service_bus_client: The Azure Service Bus client
            logger (logging.Logger): Logger instance for logging activities.
        """
        self.service_bus_client = service_bus_client
        self.logger = logging.getLogger(__name__)

    async def send_message(
            self,
            queue_name: str,
            body: str,
            correlation_id: uuid.UUID = None,
            trace_id: uuid.UUID = None
    ) -> uuid.UUID:
        """
        Sends a message to a specified Service Bus queue.

        Args:
            queue_name (str): The name of the queue to send the message to.
            body (str): The content of the message.
            correlation_id (uuid.UUID, optional): An optional UUID to correlate messages.
                                                  If not provided, a new UUID is generated.
            trace_id (uuid.UUID, optional): An optional UUID to trace messages.
                                                  If not provided, a new UUID is generated.

        Returns:
            uuid.UUID: The correlation ID of the sent message.
        """
        try:
            # Generate a new correlation ID if not provided
            if correlation_id is None:
                correlation_id = uuid.uuid4()
                self.logger.debug(f"Generated new Correlation ID: {correlation_id}")

            # Generate a new trace_id ID if not provided
            if trace_id is None:
                trace_id = uuid.uuid4()
                self.logger.debug(f"Generated new Trace ID: {trace_id}")


            # Define application-specific properties for the message
            application_properties = {"correlationId": correlation_id, "traceId": trace_id}

            # Asynchronously create a sender for the specified queue
            async with self.service_bus_client.get_queue_sender(queue_name) as sender:
                # Create the ServiceBusMessage with the provided body and properties
                message = ServiceBusMessage(
                    body=body,
                    application_properties=application_properties
                )

                # Send the message asynchronously
                await sender.send_messages(message)
                self.logger.info(f"Message sent to queue '{queue_name}' with Correlation ID: {correlation_id} and Trace ID: {trace_id}")

            return correlation_id
        except Exception as e:
            self.logger.exception(f"Failed to send message to queue '{queue_name}': {e}")
            raise

    async def schedule_message(
            self,
            queue_name: str,
            body: str,
            schedule_time_utc: datetime,
            correlation_id: uuid.UUID = None,
            trace_id: uuid.UUID = None
    ) -> uuid.UUID:
        """
        Schedules a message to be sent to a specified Service Bus queue at a future time.

        Args:
            queue_name (str): The name of the queue to send the message to.
            body (str): The content of the message.
            schedule_time_utc (datetime): The UTC datetime when the message should be enqueued.
            correlation_id (uuid.UUID, optional): An optional UUID to correlate messages.
                                                  If not provided, a new UUID is generated.
            trace_id (uuid.UUID, optional): An optional UUID to trace messages.
                                                  If not provided, a new UUID is generated.

        Returns:
            uuid.UUID: The correlation ID of the scheduled message.
        """
        try:
            # Generate a new correlation ID if not provided
            if correlation_id is None:
                correlation_id = uuid.uuid4()
                self.logger.debug(f"Generated new Correlation ID: {correlation_id}")

            # Generate a new trace_id ID if not provided
            if trace_id is None:
                trace_id = uuid.uuid4()
                self.logger.debug(f"Generated new Trace ID: {trace_id}")

            # Define application-specific properties for the message
            application_properties = {"correlationId": correlation_id, "traceId": trace_id}

            # Asynchronously create a sender for the specified queue
            async with self.service_bus_client.get_queue_sender(queue_name) as sender:
                # Create the ServiceBusMessage with the provided body and properties
                message = ServiceBusMessage(
                    body=body,
                    application_properties=application_properties
                )

                # Schedule the message to be sent at the specified UTC time
                await sender.schedule_messages(message, schedule_time_utc=schedule_time_utc)
                self.logger.info(
                    f"Message scheduled to queue '{queue_name}' at {schedule_time_utc.isoformat()} UTC with Correlation ID: {correlation_id}"
                )

            return correlation_id
        except Exception as e:
            self.logger.exception(f"Failed to schedule message to queue '{queue_name}': {e}")
            raise

    async def lock_renewal_failure_handler(self, renewable, error):
        """
        Handles lock renewal failures for messages.

        Args:
            renewable: The message that failed to renew its lock.
            error: The error that occurred during lock renewal.
        """
        self.logger.warning(f"Failed to renew lock for message: {renewable}. Error: {error}")

    async def process_messages(
            self,
            queue_name: str,
            stop_event: asyncio.Event,
            message_handler: Callable
    ):
        """
        Processes messages from a Service Bus receiver and delegates message processing
        to the provided message_handler function.

        Args:
            queue_name (str): The name of the queue to listen to.
            stop_event (asyncio.Event): An event to signal when to stop processing.
            message_handler (Callable): A coroutine function to handle individual messages.
        """
        try:
            renewer = AutoLockRenewer(max_lock_renewal_duration=1200, on_lock_renew_failure=self.lock_renewal_failure_handler)  # Handles automatic lock renewal for messages

            # Asynchronously create a receiver for the specified queue
            async with self.service_bus_client.get_queue_receiver(queue_name=queue_name) as receiver:
                self.logger.info(f"Started processing messages from queue '{queue_name}'.")
                try:
                    while not stop_event.is_set():
                        # Receive messages with a specified batch size and wait time
                        messages = await receiver.receive_messages(max_message_count=10, max_wait_time=5)

                        if not messages:
                            self.logger.debug("No messages received. Waiting for 5 seconds...")
                            await asyncio.sleep(5)  # Wait before polling again
                            continue

                        self.logger.debug(f"Received {len(messages)} message(s).")

                        for msg in messages:
                            try:
                                # Register the message with the renewer to handle lock renewal
                                renewer.register(receiver, msg, max_lock_renewal_duration=1200)

                                correlation_id = msg.application_properties.get(b"correlationId")
                                trace_id = msg.application_properties.get(b"traceId")

                                self.logger.info(
                                    f"Processing message with Correlation ID: {correlation_id} and Trace ID: {trace_id}"
                                )

                                # Delegate processing to the provided message_handler coroutine
                                self.logger.debug("Delegating message processing to the message handler.")
                                await message_handler(msg)
                                self.logger.debug("Delegated message processing completed.")

                                # Complete the message to remove it from the queue
                                await receiver.complete_message(message=msg)
                                self.logger.info(
                                    f"Message with Correlation ID: {correlation_id} and Trace ID: {trace_id} completed."
                                )

                            except RetryQueueingException as e:
                                # Log that the video processing is still ongoing and needs to be requeued
                                self.logger.warning(f"Requeueing message :: Exception: {e}")

                                # Complete the message to remove it from the queue before rescheduling
                                await receiver.complete_message(message=msg)
                                
                                # Schedule the message to be retried after a 30-second delay
                                scheduled_time = datetime.now(timezone.utc) + timedelta(seconds=30)
                                await self.schedule_message(
                                    queue_name=queue_name,
                                    body=e.event_message,
                                    schedule_time_utc=scheduled_time,
                                    correlation_id=correlation_id
                                )
                                # Log that the message has been requeued
                                self.logger.info("Message requeued successfully.")
                            except (FatalQueueingException, Exception) as e:
                                correlation_id = msg.application_properties.get(b"correlationId")
                                trace_id = msg.application_properties.get(b"traceId")
                                self.logger.exception(
                                    f"Error processing message with Correlation ID: {correlation_id} and Trace ID: {trace_id}: {e}")
                                # Optionally, abandon the message to make it available for reprocessing
                                await receiver.abandon_message(message=msg)
                                self.logger.info(
                                    f"Message with Correlation ID: {correlation_id} and Trace ID: {trace_id} abandoned."
                                )

                finally:
                    # Ensure that the renewer is properly closed to release resources
                    await renewer.close()
                    self.logger.info("AutoLockRenewer closed.")
        except Exception as e:
            self.logger.exception(f"Failed to process messages from queue '{queue_name}': {e}")
            raise
