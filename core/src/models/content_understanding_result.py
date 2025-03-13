from typing import List
from pydantic import BaseModel
from datetime import datetime
from uuid import UUID

class GenericStringField(BaseModel):
    type: str
    valueString: str

class Fields(BaseModel):
    description: GenericStringField
    subject: GenericStringField
    sentiment: GenericStringField
    actions: GenericStringField
    onScreenText: GenericStringField
    keyTakeaways: GenericStringField
    spokenKeywords: GenericStringField
    visualContext: GenericStringField
    toneAnalysis: GenericStringField

class Content(BaseModel):
    markdown: str
    fields: Fields
    kind: str
    startTimeMs: int
    endTimeMs: int
    width: int
    height: int

class Warning(BaseModel):
    code: str
    message: str

class Result(BaseModel):
    analyzerId: str
    apiVersion: str
    createdAt: datetime
    warnings: List[Warning]
    contents: List[Content]

class ContentResult(BaseModel):
    id: UUID
    status: str
    result: Result
