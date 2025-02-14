from pydantic import BaseModel

class VideoUploadMetadata(BaseModel):
    videoId: str
    fileName: str
    fileUrl: str
    isUploaded: bool
