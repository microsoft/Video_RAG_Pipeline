from pydantic import BaseModel

class BlobMetadata(BaseModel):
    fileUrl: str
