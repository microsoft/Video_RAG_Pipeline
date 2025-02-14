from pydantic import BaseModel

class Payload(BaseModel):
    id: str
    fileUrl: str
