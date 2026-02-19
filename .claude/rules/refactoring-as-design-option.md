# Refactoring Rules

## Reactive refactoring — propose, don't act

When you spot existing code that needs improvement while working on a task — propose the refactoring to the user but wait for approval before making changes. Do NOT silently refactor surrounding code.

## Refactoring as a design option — don't dismiss it

When designing an approach for new functionality, if refactoring existing code would provide a better foundation — do NOT automatically dismiss it in favor of the path of least resistance.

Instead, present it as one of the considered approaches with clear trade-offs:

| Factor | Describe |
|--------|----------|
| **Cost** | What needs to change, how many files, risk of regressions |
| **Benefit** | Simpler integration, reduced duplication, better extensibility |
| **Alternative** | What the non-refactoring approach looks like and its downsides |

Use `AskUserQuestion` to discuss the trade-offs and let the user decide.

### When this applies

- During brainstorming phase — refactoring should be one of the 2-3 proposed approaches when relevant
- During plan execution — if you discover that refactoring would significantly simplify the current or upcoming tasks
- When adding a new resource/handler/command that is structurally similar to existing ones with code duplication

### When this does NOT apply

- Cosmetic improvements (renaming, reformatting) unrelated to the current task
- Refactoring that only benefits hypothetical future features (violates YAGNI)
- Changes where the refactoring cost clearly outweighs the benefit — use judgment

### Relationship to YAGNI/KISS

Refactoring to simplify integration of a **current** feature is NOT over-engineering — it's applying KISS. The test: "Does this refactoring make the feature I'm building right now simpler?" If yes, it's a valid option worth discussing.
