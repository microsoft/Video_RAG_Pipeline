# Stage 1: Build the application
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS build

ARG PROJECTNAME
ENV PROJECTNAME=${PROJECTNAME}

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /build

# Only copy files for building
COPY . .

# Run the build command to create wheels
RUN uv build --all-packages --wheel

# Stage 2: Create the final image
FROM python:3.12-slim AS app

ARG PROJECTNAME
ENV PROJECTNAME=${PROJECTNAME}
WORKDIR /app

# Copy only the built wheels from the build stage
COPY --from=build /build/dist /app/dist

# Install the wheel and remove the wheel files to reduce image size
RUN uv pip install --no-cache-dir dist/*.whl && rm -rf dist

CMD ${PROJECTNAME}