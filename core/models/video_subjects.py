from typing import Any

from pydantic import BaseModel

from . import Content


class Subject(BaseModel):
    title: str
    startTimeMs: int
    endTimeMs: int


class VideoSubjects(BaseModel):
    subjects: list[Subject]

    def to_subject_content_sets(self, contents: list[Content]) -> list[dict[str, Any]]:
        return [
            {
                "subject": subject.title,
                "contents": [
                    content for content in contents
                    if content.startTimeMs >= subject.startTimeMs and content.endTimeMs <= subject.endTimeMs
                ]
            }
            for subject in self.subjects
        ]
