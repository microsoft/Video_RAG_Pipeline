class FatalQueueingException(Exception):
    """Exception raised for errors that must dead letter an event."""

    def __init__(self, message: str) -> None:
        self.message = message
        super().__init__(self.message)

__all__ = [
    "FatalQueueingException"
]