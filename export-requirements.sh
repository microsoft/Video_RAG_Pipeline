#!/bin/bash

uv export --no-emit-workspace --directory chunk_video_content --output-file requirements.txt
uv export --no-emit-workspace --directory index_file_api --output-file requirements.txt
uv export --directory summarize_video_content --output-file requirements.txt