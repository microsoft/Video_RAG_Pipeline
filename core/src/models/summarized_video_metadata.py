from pydantic import BaseModel

class SummarizedVideoMetadata(BaseModel):
    summary: str
    videoId: str
