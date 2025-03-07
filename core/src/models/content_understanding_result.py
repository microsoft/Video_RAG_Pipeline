from typing import List
from pydantic import BaseModel
from datetime import datetime
from uuid import UUID

class ActionsField(BaseModel):
    type: str
    valueString: str

class SummaryField(BaseModel):
    type: str
    valueString: str

class SentimentField(BaseModel):
    type: str
    valueString: str

class Fields(BaseModel):
    actions: ActionsField
    summary: SummaryField
    sentiment: SentimentField

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
