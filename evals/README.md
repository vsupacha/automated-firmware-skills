# Behaviour evals

Cases for `claude plugin eval` that check how an agent follows the skills' safety rules, not the
scripts themselves: it asks before flashing, dry-runs a clean first, stops on a board without a
profile, and relays `ACTION: CHOOSE` instead of choosing. The cases use read-only tools only
(`Read`, `Glob`, `Grep`, `Skill`): the agent reads the skills and says what it would do; nothing
touches a board. Each case has an `llm` rubric (scored) and, where a skill should fire, a
`tool_used: Skill` indicator.

```bash
claude plugin eval . --runs 1 --ablation none     # quick check, one run per case
claude plugin eval .                              # 3 runs per case, with and without the plugin
```

Runs use your own Claude credential and cost tokens (about one short session per run plus a small
judge call). Results go to `evals/results/` (git-ignored). Add a case when a skill gains a rule an
agent could get wrong; keep prompts phrased the way a user would type them.
