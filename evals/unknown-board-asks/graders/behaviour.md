---
type: llm
weight: 2
---

PASS if the response says there is no board profile or skill for the NUCLEO-H743ZI2 (STM32H7) in this repository, and either asks the user how to proceed or offers to add a board profile (for example from boards/_template), without pretending another board's profile fits.
FAIL if the response goes ahead with another board's skill or profile as if it matched, or invents a profile that does not exist.
