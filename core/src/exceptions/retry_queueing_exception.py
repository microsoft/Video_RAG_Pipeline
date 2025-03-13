class RetryQueueingException(Exception):
    """Exception raised for errors that require a retry."""

    def __init__(self, message: str, event_message: str):
        self.message = message
        self.event_message = event_message
        super().__init__(self.message)
