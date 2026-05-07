# Global Copilot Instructions

## Memory Files
Before answering code questions about a repository, always read the relevant memory file from `~/.copilot/memory/<repo-name>/` first. Use prior findings to inform your answers and avoid repeating corrected mistakes.

Current memory files:
- `~/.copilot/memory/copilot-api/findings.md` — Authentication, model policies, rate limiting, caching, telemetry, model registry.

When investigating a new repo, create a corresponding memory file at `~/.copilot/memory/<repo-name>/findings.md` to store confirmed findings and corrections.

## Investigation & Answering

- **Important:** For investigative tasks, read the relevant code first before answering.
- **Important:** Do not make assumptions unless you can back them up with proof and facts.
- **Important:** Do not hallucinate.
- **Important:** If you cannot find the answer or do not know, say so clearly. Do not make something up.
- **Important:** Keep responses succinct. Do not give paragraphs for questions that require a one-word answer.
- **Important:** For complicated tasks that require more reasoning, intentionally trigger cross-model verification: delegate to a subagent using a different model provider (e.g., if you are a Claude model, use a GPT model, and vice versa), then reconcile any differences before answering the user.
