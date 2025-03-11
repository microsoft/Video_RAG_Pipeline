import pytest
from summarize_video_content import app, MessageHandler
from core import ServiceBusEventMessagingService

def test_app(service_bus, message_handler):
    # Import the app module here to avoid circular imports
    app.main_logic(
        service_bus_messaging_service=service_bus,
        message_handler=message_handler,
        finalize_content_queue="FAKE QUEUE",
    )
    pass