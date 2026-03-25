#!/bin/bash
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════╗"
echo "║     OpenProphet — VPS Deployer           ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Install Docker if missing ──────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo -e "${YELLOW}Installing Docker...${NC}"
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
  echo -e "${GREEN}Docker installed.${NC}"
else
  echo -e "${GREEN}[ok] Docker $(docker --version | cut -d' ' -f3 | tr -d ',')${NC}"
fi

# ── 2. Install Docker Compose plugin if missing ────────────────────
if ! docker compose version &>/dev/null; then
  echo -e "${YELLOW}Installing Docker Compose...${NC}"
  mkdir -p /usr/local/lib/docker/cli-plugins
  LATEST=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
  curl -SL "https://github.com/docker/compose/releases/download/${LATEST}/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  echo -e "${GREEN}Docker Compose installed.${NC}"
else
  echo -e "${GREEN}[ok] $(docker compose version)${NC}"
fi

# ── 3. Create .env if missing ──────────────────────────────────────
if [ ! -f .env ]; then
  echo ""
  echo -e "${YELLOW}Setup — enter your API keys:${NC}"
  echo ""

  read -p "  Alpaca Public Key:  " ALPACA_PUBLIC_KEY
  read -p "  Alpaca Secret Key:  " ALPACA_SECRET_KEY

  echo ""
  echo "  Alpaca Endpoint:"
  echo "    1) Paper trading  (recommended for testing)"
  echo "    2) Live trading"
  read -p "  Choose [1/2, default=1]: " ALPACA_CHOICE
  if [ "$ALPACA_CHOICE" = "2" ]; then
    ALPACA_ENDPOINT="https://api.alpaca.markets"
  else
    ALPACA_ENDPOINT="https://paper-api.alpaca.markets"
  fi

  echo ""
  read -p "  OpenAI API Key (sk-...): " OPENAI_API_KEY
  echo ""
  read -p "  Dashboard Auth Token (leave blank to skip): " AGENT_AUTH_TOKEN
  echo ""
  read -p "  Gemini API Key (optional, press Enter to skip): " GEMINI_API_KEY

  cat > .env <<EOF
ALPACA_PUBLIC_KEY=${ALPACA_PUBLIC_KEY}
ALPACA_SECRET_KEY=${ALPACA_SECRET_KEY}
ALPACA_ENDPOINT=${ALPACA_ENDPOINT}
OPENAI_API_KEY=${OPENAI_API_KEY}
AGENT_AUTH_TOKEN=${AGENT_AUTH_TOKEN}
GEMINI_API_KEY=${GEMINI_API_KEY}
EOF

  echo ""
  echo -e "${GREEN}.env saved.${NC}"
else
  echo -e "${GREEN}[ok] .env found${NC}"
fi

# ── 4. Download docker-compose.yml ────────────────────────────────
if [ ! -f docker-compose.yml ]; then
  echo -e "${YELLOW}Downloading docker-compose.yml...${NC}"
  curl -fsSL https://raw.githubusercontent.com/shekhar282/openprophet/main/docker-compose.yml -o docker-compose.yml
fi

# ── 5. Pull and start ──────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Pulling latest image from Docker Hub...${NC}"
docker pull shekhar282/openprophet:latest

echo ""
echo -e "${YELLOW}Starting...${NC}"
docker compose up -d

# ── 6. Wait for health ─────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Waiting for agent to be ready...${NC}"
for i in $(seq 1 30); do
  if curl -sf http://localhost:3737 &>/dev/null; then
    break
  fi
  sleep 2
done

# ── 7. Done ────────────────────────────────────────────────────────
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║           Deployment Complete!           ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  Dashboard:  ${BLUE}http://${SERVER_IP}:3737${NC}"
echo ""
echo -e "  Commands:"
echo -e "    docker compose logs -f       # live logs"
echo -e "    docker compose pull && docker compose up -d   # update to latest"
echo -e "    docker compose down          # stop"
echo ""
