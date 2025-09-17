#!/bin/bash
set -e

echo "🚀 Starting full setup for local-ai-packaged on Debian 12..."

### 1. Install dependencies
echo "🔧 Installing system packages..."
apt update && apt install -y \
  curl \
  wget \
  git \
  python3 \
  python3-pip \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common

### 2. Install Docker (only if not already installed)
if ! command -v docker &> /dev/null; then
  echo "🐳 Installing Docker..."
  curl -fsSL https://get.docker.com | sh
else
  echo "🐳 Docker already installed. Skipping..."
fi

### 3. Install Docker Compose v2 plugin
echo "🔧 Installing Docker Compose plugin..."
mkdir -p /usr/local/lib/docker/cli-plugins
DOCKER_COMPOSE_VERSION="v2.23.3"
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

### 4. Clone the repo if not already present
if [ ! -d /opt/local-ai ]; then
  echo "📁 Cloning local-ai-packaged..."
  git clone https://github.com/coleam00/local-ai-packaged.git /opt/local-ai
fi

cd /opt/local-ai

### 5. Copy env file and patch required values
echo "📄 Preparing .env file..."
cp -n .env.example .env

# Patch required Supabase value if missing
grep -q POOLER_DB_POOL_SIZE .env || echo "POOLER_DB_POOL_SIZE=5" >> .env

### 6. Start the stack — this is the key part!
echo "🚀 Launching LocalAI stack..."
python3 start_services.py --profile cpu --environment private

echo "✅ All done. The stack is running at internal IP 10.0.7.20"