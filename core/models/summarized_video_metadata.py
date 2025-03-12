from pydantic import BaseModel

class SummarizedVideoMetadata(BaseModel):
    videoId: str
    title: str
    description: str
    startTimeMs: int
    endTimeMs: int
