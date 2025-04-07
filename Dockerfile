# Stage 1: Build the Go application
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy Go modules and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /mcp-proxy main.go

# Stage 2: Create the final image based on Debian
FROM debian:bookworm-slim

# Install prerequisites for NodeSource script and other dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    python3 \
    python3-pip \
    git \
    libatomic1 && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x using NodeSource script and enable corepack
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    corepack enable && \
    rm -rf /var/lib/apt/lists/*

# Install uv using pip
RUN pip3 install uv --break-system-packages --no-cache-dir

# Verify installations (will fail build if commands not found)
RUN echo "Verifying installations:" && \
    which node && node -v && \
    which npm && npm -v && \
    which npx && npx --version && \
    which corepack && corepack -v && \
    which uv && uv --version && \
    echo "Verifying PATH:" && echo $PATH

# Install Playwright browsers and dependencies
RUN npx playwright install --with-deps


# Set working directory (optional, but good practice)
WORKDIR /app

# Copy the built Go binary from the builder stage
COPY --from=builder /mcp-proxy /usr/local/bin/mcp-proxy

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/mcp-proxy"]

# Default command (can be overridden) - expects config path
CMD ["--config", "/config/config.json"]