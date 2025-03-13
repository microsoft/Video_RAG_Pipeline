from typing import Any

from pydantic import BaseModel

from . import Content

class Subject(BaseModel):
    title: str
    startTimeMs: int
    endTimeMs: int

class SubjectContentSet(BaseModel):
    title: str
    startTimeMs: int
    endTimeMs: int
    content: list[Content]

class VideoSubjects(BaseModel):
    subjects: list[Subject]

    def to_subject_content_sets(self, contents: list[Content]) -> list[SubjectContentSet]:
        return [
            SubjectContentSet(
                title=subject.title,
                startTimeMs=subject.startTimeMs,
                endTimeMs=subject.endTimeMs,
                content=[
                    content for content in contents
                    if content.startTimeMs >= subject.startTimeMs and content.endTimeMs <= subject.endTimeMs
                ]
            )
            for subject in self.subjects
        ]
