from pydantic import BaseModel

class VideoFileMetadata(BaseModel):
    fileUrl: str
