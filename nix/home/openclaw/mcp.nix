# Workaround for mcporter native integration bug (#7158) - uses exec-based calls
{ pkgs }:
pkgs.writeText "mcporter.json" (
  builtins.toJSON {
    mcpServers = {
      websearch = {
        baseUrl = "https://mcp.exa.ai/mcp";
      };
      context7 = {
        baseUrl = "https://mcp.context7.com/mcp";
      };
      grep-app = {
        baseUrl = "https://mcp.grep.app";
      };
    };
  }
)
