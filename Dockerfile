# ── Stage 1: Build Go binary for linux/amd64 ──────────────────────
FROM golang:1.22-alpine AS go-builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o prophet_bot ./cmd/bot

# ── Stage 2: Final image ───────────────────────────────────────────
FROM oven/bun:1.3-slim
WORKDIR /app

# Install system deps + opencode CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    bun install -g opencode-ai

# Install Node deps first (layer cache)
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

# Copy Go binary
COPY --from=go-builder /build/prophet_bot ./prophet_bot
RUN chmod +x ./prophet_bot

# Copy app source
COPY . .

# Set opencode MCP config to use container paths
RUN echo '{"$schema":"https://opencode.ai/config.json","mcp":{"openprophet":{"type":"local","command":["bun","/app/mcp-server.js"]}}}' > opencode.json

# Persist data and logs
VOLUME ["/app/data", "/app/activity_logs"]

EXPOSE 3737

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:3737 || exit 1

CMD ["bun", "agent/server.js"]
