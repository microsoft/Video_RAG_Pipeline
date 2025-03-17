import pytest
from summarize_video_content.src import app
from summarize_video_content.src.app import MessageHandler
from core import ServiceBusEventMessagingService

@pytest.fixture
def service_bus(mocker):
    service_bus_client = mocker.MagicMock()
    return ServiceBusEventMessagingService(
        service_bus_client=service_bus_client
    )

@pytest.fixture
def message_handler(mocker):
    return MessageHandler(
        event_messaging_service=mocker.MagicMock(),
        file_upload_service=mocker.MagicMock(),
        video_extraction_service=mocker.MagicMock(),
        llm_video_analysis_service=mocker.MagicMock(),
        finalize_content_queue_name="FAKE content QUEUE",
        video_summary_queue_name="FAKE Summary QUEUE",
    )

@pytest.mark.timeout(1)
async def test_app(mocker, service_bus, message_handler):
    # Use mocker to patch any test dependencies here
    await app.main_logic(
        service_bus_messaging_service=service_bus,
        message_handler=message_handler,
        finalize_content_queue="FAKE QUEUE",
    )