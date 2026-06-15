
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# 安装基础脏活工具和 Python 环境
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        wget unzip \
        python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir uv --break-system-packages

# 定义 Godot 版本 (修改为你实际使用的版本)
ARG GODOT_VERSION="4.6.3"
ARG GODOT_RELEASE="stable"

# 下载 Godot Linux 无头版/标准版 (Godot 4 开始标准版自带 --headless)
# arm64 — 适配 Apple Silicon Mac 上的 Docker 容器
RUN wget https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.arm64.zip \
    && unzip Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.arm64.zip \
    && mv Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.arm64 /usr/local/bin/godot \
    && rm Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.arm64.zip

# 创建一个非 root 用户的工作目录
WORKDIR /root/workspace