from pydantic import BaseModel

class Subject(BaseModel):
    title: str
    startTimeMs: int
    endTimeMs: int

class VideoSubjects(BaseModel):
    subjects: list[Subject]