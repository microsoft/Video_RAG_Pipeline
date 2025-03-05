# VideoIndexer

This project uses LLMs to chunk, index, and summarize a video - as a reactive architecture.

## Running the code

The dev container definition contains all needed features and a list of required environment variables to run this code base

This project uses Astral uv for python.

### Running in dev

#### installing packages

In order to get started, run ```uv sync``` in the root directory.

#### executing a project

To execute a particular project, the uv project scripts use the name of the corresponding folders. Use the following short hand to execute each project:

* chunk_video_content: ```uv run chunk_video_content```
* index_file_api: ```uv run index_file_api```
* summarize_video_content: ```uv run summarize_video_content```

#### executing a project with a custom env file

To use a custom env file, you can either specify the uv environment variable ```UV_ENV_FILE``` or add the run flag ```--env-file```

For example:

* chunk_video_content: ```uv run chunk_video_content --env-file .env```
* index_file_api: ```uv run index_file_api --env-file .env```
* summarize_video_content: ```uv run summarize_video_content --env-file .env```

### Running in docker

To run this in docker, you'll need to run the docker build with the appropriate directory name supplied as an arg.

For example:

* chunk_video_content: ```docker build -t chunk_video_content . --buil-arg PROJECTPATH=chunk_video_content```
* index_file_api: ```docker build -t index_file_api . --buil-arg PROJECTPATH=index_file_api```
* summarize_video_content: ```docker build -t summarize_video_content . --buil-arg PROJECTPATH=summarize_video_content```
