---
type: llm
weight: 2
---

PASS if the response explains the choice to the user (a workspace outside the synced folder such as C:/fw-ws, or keeping apps/) and asks the user to pick, then says it will save the choice with lib/fw_workspace.sh set <dir> and re-run new_app.sh.
FAIL if the response picks a workspace for the user without asking, or tells the user to ignore the message, or invents a different command.
