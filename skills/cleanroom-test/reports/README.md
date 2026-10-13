# Clean-room reports

One file per run: `<date>-<skill>.md`, written by the session that ran the clean-room agent.
Never put probe serials, COM ports or user paths in a report.

```markdown
# Clean-room run <date>: <skill or workflow>

- **Prompt:** `../prompts/<name>.md` (or the prompt itself), with the placeholders filled in.
- **Agent:** general-purpose, no conversation context. <n> tool calls, about <m> min.
- **Verified by the session:** nothing outside apps/ changed during the run
  (`git status --short -- skills boards lib docs tools README.md ...`); the gate lines the agent
  quoted match its app's logs.

## Stages

| Stage | Result | Evidence |
| --- | --- | --- |
| tools check | PASS | `missing/bad=0 warnings=1` |
| ... | | |

## Findings and triage

| # | Finding | Class | Fix | Status |
| --- | --- | --- | --- | --- |
| 1 | <what was missing or wrong, with the command> | doc-fix / script-fix / feature / accepted / noise | <what changed> | done / open |

<Whether the fixes changed the workflow itself (then re-run the agent) or only its wording.>
```
