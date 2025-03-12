from pydantic import BaseModel

class ProcessingResultEvent(BaseModel):
    title: str
    description: str
    startTimeMs: int
    endTimeMs: int
