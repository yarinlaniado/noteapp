#!/bin/bash

# Your DockerHub username and image name
DOCKER_USERNAME="yarinlaniado"
IMAGE_NAME="note-app"

# Get the latest Docker image tag from DockerHub
LATEST_TAG=$(curl -s "https://hub.docker.com/v2/repositories/${DOCKER_USERNAME}/${IMAGE_NAME}/tags" | jq -r '.results[].name' | sort -r | head -n 1)

# Extract the major and minor version components
MAJOR_VERSION="${LATEST_TAG%%.*}"
MINOR_VERSION="${LATEST_TAG#*.}"
MINOR_VERSION="${MINOR_VERSION%%.*}"

# Increment the minor version component
((MINOR_VERSION++))

# Build the new tag
NEW_TAG="${MAJOR_VERSION}.${MINOR_VERSION}"

# Output the new tag
echo "New tag: ${NEW_TAG}"

# Set the new tag as an environment variable for the next steps in the pipeline
echo "::set-env name=NEW_DOCKER_TAG::${NEW_TAG}"

