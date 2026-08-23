# VectorMBE Deploy

VectorMBE is a model-based engineering (MBE) runtime built for AI-assisted development teams. It provides a single governed substrate — an OWL-backed graph with vector retrieval, typed constraints, and Model Context Protocol (MCP) integration so engineers, CI pipelines, and LLM tools all reason over the same versioned structure.

This repository is the Docker-only deployment for [VectorMBE](https://vectorstreamsystems.com/) — no source code required.

---

## Requirements

- **macOS** — [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/) (Apple Silicon or Intel)
- **Windows** — [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) (WSL2 backend recommended) or Windows Subsystem for Linux (WSL2) with Docker Engine
- **Linux** — [Docker Engine](https://docs.docker.com/engine/install/) + [Docker Compose](https://docs.docker.com/compose/install/) (plugin or standalone)
- A valid VectorMBE license key ([request one](mailto:streamline@vectorstreamsystems.com))

> **Note:** `radsilent/vectormbe-deploy` is a **private** repository — access is granted with your
> license. The platform sections below assume you have it. If you do not yet, use the
> self-contained quick start immediately below; it needs nothing but the public Docker image.

---

## Quick start without the deploy package

The license key is read **at startup**. Without it the container exits immediately with
`startup aborted: invalid or missing license`.

```bash
docker run -d \
  --name vectormbe \
  --restart unless-stopped \
  -p 8080:8080 \
  -e VECTORMBE_LICENSE_KEY=your-license-key \
  radsilent/vectormbe:latest
```

Or, for a persistent setup, write these two files into an empty directory and run
`docker compose up -d`:

```yaml
# docker-compose.yml
services:
  vectormbe:
    image: radsilent/vectormbe:latest
    container_name: vectormbe
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - VECTORMBE_LICENSE_KEY=${VECTORMBE_LICENSE_KEY:?Required}
```

```env
# .env
VECTORMBE_LICENSE_KEY=your-license-key
```

Open **http://localhost:8080**, or check it with
`curl -sf http://localhost:8080/openapi.json > /dev/null && echo up`.

Port 8080 is the only port the image exposes — it serves both the UI and the API.

---

## macOS

```bash
# 1. Download the deploy package (private repo — requires your licensed access)
gh repo clone radsilent/vectormbe-deploy vectormbe && cd vectormbe
# or, with a token:
# curl -fL -H "Authorization: Bearer $GITHUB_TOKEN" \
#   https://github.com/radsilent/vectormbe-deploy/archive/main.tar.gz | tar xz
# 2. Configure your license key
cp .env.example .env
# Edit .env and set VECTORMBE_LICENSE_KEY

# 3. Start
docker compose up -d
```

Open **http://localhost:8080** (or the port mapped in your compose file).

---

## Windows

### Option A — Docker Desktop (recommended)

Open **PowerShell** and run:

```powershell
# 1. Download the deploy package (private repo — requires your licensed access)
gh repo clone radsilent/vectormbe-deploy vectormbe
Set-Location vectormbe

# 2. Configure your license key
Copy-Item .env.example .env
# Edit .env and set VECTORMBE_LICENSE_KEY

# 3. Start
docker compose up -d
```

### Option B — WSL2

Inside your WSL2 distro:

```bash
# 1. Download the deploy package (private repo — requires your licensed access)
gh repo clone radsilent/vectormbe-deploy vectormbe && cd vectormbe

# 2. Configure your license key
cp .env.example .env
# Edit .env and set VECTORMBE_LICENSE_KEY

# 3. Start
docker compose up -d
```

Access the UI at **http://localhost:8080** from Windows — Docker Desktop forwards the port automatically.

---

## Linux

```bash
# 1. Download the deploy package (private repo — requires your licensed access)
gh repo clone radsilent/vectormbe-deploy vectormbe && cd vectormbe

# 2. Configure your license key
cp .env.example .env
# Edit .env and set VECTORMBE_LICENSE_KEY

# 3. Start
docker-compose up -d
```

Open **http://localhost:8080**.

> **Note:** If your system has the newer Docker Compose plugin, use `docker compose up -d` (space, no hyphen). Both work the same.

---

## What's included

- `docker-compose.yml` — pulls `radsilent/vectormbe:latest` from Docker Hub
- `Caddyfile` — reverse proxy for API + static UI
- `.env.example` — license key, LLM config, and optional feature flags

---

## Upgrade

```bash
docker-compose pull
docker-compose up -d
```

> **Note:** Use `docker compose` (space) if you have the Docker Compose plugin instead of the standalone binary.

---

## Logs

```bash
docker logs -f vectormbe
docker logs -f vectormbe-caddy
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `VECTORMBE_LICENSE_KEY` | *(required)* | License activation key, read at startup — the container exits if unset |
| `VECTORMBE_LICENSE_PATH` | *(unset)* | Path to a license file, as an alternative to the key |
| `VECTORMBE_PORT` | `8080` | HTTP port |
| `VECTORMBE_HOST` | `0.0.0.0` | Bind address |
| `VECTORMBE_REQUIRE_TORCH_GPU` | `false` | Set `true` for GPU-accelerated hosts |
| `VECTORMBE_STARTUP_GRAPH` | `demo` | Preload `demo` graph on startup (set empty to start blank) |
| `VECTORMBE_ISOLATE_BY_SESSION` | `false` | Multi-tenant isolation — each API key gets its own isolated workspace |
| `VECTORMBE_QDRANT_URL` | *(unset)* | Qdrant endpoint (e.g. `http://qdrant:6333`) for persistent vector storage |
| `VECTORMBE_LLM_PROVIDER` | *(unset)* | `openai`, `anthropic`, or `ollama` for AI synthesis |
| `VECTORMBE_LLM_API_KEY` | *(unset)* | API key for the LLM provider |
| `OPENAI_API_KEY` | *(unset)* | OpenAI key (shorthand when provider is `openai`) |
| `ANTHROPIC_API_KEY` | *(unset)* | Anthropic key (shorthand when provider is `anthropic`) |

---

## Multi-tenant isolation (shared / demo servers)

When running a shared instance where multiple users connect with different API keys, enable workspace isolation:

```env
VECTORMBE_ISOLATE_BY_SESSION=true
VECTORMBE_ADMIN_KEY=your-admin-key
VECTORMBE_EDITOR_KEY=user-a-key
```

Each distinct API key gets a fully isolated graph workspace — entities, relations, and vector searches are scoped per key. Users cannot see each other's uploaded models.

---

## Optional: Qdrant persistent vector store

For large-scale deployments (50k+ entities), add Qdrant for production-grade ANN with hybrid RRF retrieval:

1. Uncomment the `qdrant` service block in `docker-compose.yml`
2. Uncomment `qdrant_data` in the `volumes` section
3. Add to your `.env`:

```env
VECTORMBE_QDRANT_URL=http://qdrant:6333
```

VectorMBE automatically creates per-kind collections (`vectormbe_requirement`, etc.) and a cross-kind `vectormbe_entities_all` collection on first use. Without Qdrant, the in-process HNSW index handles vector search (suitable for most deployments).

---

## Troubleshooting

### `docker: unknown command: docker compose`

Your installation uses the standalone `docker-compose` binary (older style). Replace `docker compose` with `docker-compose` in every command:

```bash
docker-compose up -d
docker-compose pull
docker-compose logs -f
```

To install the modern plugin:

```bash
sudo apt-get install docker-compose-plugin   # Debian/Ubuntu
```

---

## GPU acceleration (optional)

Requires the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

Add to `docker-compose.yml` under the `vectormbe` service:

```yaml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

And set `VECTORMBE_REQUIRE_TORCH_GPU=true` in your `.env`.
