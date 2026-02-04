---
name: mcp-tools
description: Access external MCP servers (web search, documentation lookup, GitHub code search) via mcporter CLI. Use exec commands to call these tools.
metadata:
  openclaw:
    emoji: "🔌"
    requires:
      bins: ["mcporter"]
    install:
      - id: node
        kind: node
        package: mcporter
        bins: ["mcporter"]
        label: "Install mcporter (npm)"
---

# MCP Tools - Web Search, Docs & Code Search

You have access to external MCP servers through mcporter. Due to a known integration issue (#7158), use **exec commands** to call these tools.

## How to Call MCP Tools

```bash
npx mcporter call <server>.<tool> <arg>=<value> [arg2=value2]
```

For arguments with spaces, use quotes:
```bash
npx mcporter call websearch.web_search_exa query="best practices for kubernetes"
```

---

## Available MCP Servers

### 1. websearch (Exa) - Web Search

Real-time web search for fresh sources, citations, and content extraction.

| Tool | Description | Example |
|------|-------------|---------|
| `web_search_exa` | Search the web | `npx mcporter call websearch.web_search_exa query="latest AI news 2026"` |

**Parameters:**
- `query` (required): Search query - natural language works best
- `numResults` (optional): Number of results (default: 10)
- `type` (optional): `auto`, `fast`, or `deep`

**Examples:**
```bash
# Basic search
npx mcporter call websearch.web_search_exa query="MCP protocol documentation"

# Fast search with fewer results
npx mcporter call websearch.web_search_exa query="rust async patterns" numResults=5 type=fast
```

---

### 2. context7 - Documentation Lookup

Intelligent documentation search for any library with LLM-powered ranking.

| Tool | Description | Example |
|------|-------------|---------|
| `resolve-library-id` | Find library ID | `npx mcporter call context7.resolve-library-id libraryName=nextjs` |
| `get-library-docs` | Get docs | `npx mcporter call context7.get-library-docs context7CompatibleLibraryID=/vercel/next.js` |

**Workflow:**
```bash
# Step 1: Find the library ID
npx mcporter call context7.resolve-library-id libraryName="react" query="hooks"

# Step 2: Get documentation
npx mcporter call context7.get-library-docs context7CompatibleLibraryID=/facebook/react topic="useEffect"
```

---

### 3. grep-app - GitHub Code Search

Search real code across millions of GitHub repositories.

| Tool | Description | Example |
|------|-------------|---------|
| `search` | Search GitHub code | `npx mcporter call grep-app.search query="useEffect.*cleanup" lang=typescript` |

**Examples:**
```bash
# Search for a pattern
npx mcporter call grep-app.search query="useState.*loading"

# Filter by language
npx mcporter call grep-app.search query="async function.*fetch" lang=typescript
```

---

## Notes

- Always use **exec** to call these tools (native skill integration has a known bug #7158)
- All servers are free tier - no API keys needed
