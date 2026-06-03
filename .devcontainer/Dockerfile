FROM python:3.12-slim

RUN apt-get update && apt-get install -y \
    git \
    redis-server \
    redis-tools \
    curl \
    jq \
    openssh-client \
    ca-certificates \
    coreutils \
    findutils \
    bash \
    nano \
 && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip \
 && python -m pip install redis fastapi uvicorn

WORKDIR /workspaces/CYBRA
