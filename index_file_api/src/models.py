import uuid

from pydantic import BaseModel

class Payload(BaseModel):
    id: uuid.UUID
    fileUrl: str
