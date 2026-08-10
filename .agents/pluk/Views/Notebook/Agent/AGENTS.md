# Views/Notebook/Agent/

## Purpose

AI agent subsystem for notebooks. Implements a multi-round tool-calling loop where an LLM can explore databases, run queries, and create chart/text blocks.

## Key Files

| File | Purpose |
|------|---------|
| `NotebookAgentEngine.swift` | LLM interface: tool definitions, system prompt, streaming, tool execution |
| `AgentChatController.swift` | Agent loop orchestration: round management, message persistence, streaming parts |
| `AgentDriverSession.swift` | Actor-isolated database connection for agent queries |
| `ToolMetadata.swift` | Tool display helpers (grouping, icons, headers) |
| `AgentMessageListController.swift` | AppKit controller rendering message list |
| `Markdown/MarkdownBlockParser.swift` | Parses agent output into renderable blocks |
| `Markdown/MarkdownContentView.swift` | Renders parsed markdown blocks |

## Tools Available to Agent

| Tool | Purpose | Returns |
|------|---------|---------|
| `list_databases` | List databases/deployments on a connection | Database names |
| `list_tables` | List tables/collections in a connection | Table names |
| `get_table_schema` | Get column metadata for a table | Column info |
| `run_query` | Execute exploratory SELECT queries | Query results |
| `list_notebook_blocks` | List current notebook blocks | Block summaries |
| `set_notebook_info` | Queue notebook title/description update | Confirmation |
| `arrange_dashboard` | Queue dashboard layout changes | Confirmation |
| `create_chart_block` / `update_chart_block` | Queue chart block create/update | Confirmation |
| `create_single_value_block` / `update_single_value_block` | Queue KPI block create/update | Confirmation |
| `create_text_block` / `update_text_block` | Queue text block create/update | Confirmation |
| `create_query_block` / `update_query_block` | Queue query block create/update | Confirmation |
| `get_convex_query_guide` | Fetch Convex query authoring guide (only when a Convex connection is selected) | Guide text |

## Agent Loop Flow

```
User sends message
  ↓
AgentChatController.performAgentLoop()
  ↓
for round in 0..<100:
  ↓
  NotebookAgentEngine.performRound(messages, connections, blocks, summary)
    ├─ Streams tokens → onToken callback → streamingParts updated live
    ├─ Streams reasoning → onThinking callback → thinking blocks
    └─ Returns AgentRoundResult (text, toolCalls, responseContent, assistantMessage)
  ↓
  if toolCalls.isEmpty → END LOOP (assistant done)
  ↓
  Append round.assistantMessage to glmMessages
  ↓
  Execute all toolCalls concurrently via engine.executeToolCall(...)
    ├─ Block creations queued in engine.pendingBlockCreations
    ├─ Notebook info update queued in engine.pendingNotebookInfoUpdate
    ├─ Dashboard layout queued in engine.pendingDashboardArrangement
    └─ Tool result strings collected
  ↓
  Drain pending queues into the notebook, then append one `tool`-role
  BedrockGLMChatMessage per result and feed back as next round input
```

## Write Operation Blocking

`NotebookAgentEngine.isReadOnlyStatement(_:)` is the security boundary for every
tool that executes SQL without user approval (`run_query`, `open_query_tab`). It
requires **all** of:

1. First real keyword (after stripping `--` and `/* */` comments) is one of
   `SELECT`, `WITH`, `EXPLAIN`, `SHOW`, `DESCRIBE`, `DESC`
2. A single statement — no semicolons except one trailing terminator
3. No write keyword anywhere in the text, matched as a whole word

Prefix-only checks are **not** sufficient: `-- x\nDROP TABLE t`, a writable CTE
(`WITH d AS (DELETE … RETURNING *) SELECT * FROM d`), and `SELECT 1; DROP TABLE t`
all pass a prefix check. Any new tool that runs SQL must call this helper, never
re-implement a prefix test.

`isRoutineWrite(_:)` gates auto-approve (`AgentWriteApprovalMode.autoApprove`) and
is deliberately narrow: a single `INSERT`, or `UPDATE`/`DELETE` with a `WHERE`,
containing no schema-changing or statement-smuggling keywords. Everything else
shows the approval card.

Block creation happens through dedicated tools (`create_chart_block`, `create_text_block`), not raw SQL.

## Write Approval Contract

`writeApprovalHandler` receives a `WriteApprovalRequest` carrying the query **and
the resolved execution target** (connection, `databaseName`, `schemaName`). The
target is resolved *before* approval and reused verbatim for execution, so the
card can never show a different database than the one written to. Do not
re-resolve `database_name` after approval.

Surfaces hosting the chat must call `TableChatSidebarViewController.prepareForRemoval()`
before teardown (and `declinePendingApproval()` when the card is hidden, e.g. on
mode switch). The approval suspends the agent on a checked continuation; leaking
it hangs the agent task and retains the whole chat stack.

## XML Serialization Format

Assistant messages embed metadata in XML tags for display persistence:

```xml
<thinking duration="3s">
  Agent's reasoning here
</thinking>

<tool_call name="list_tables">
  Listing tables in postgres_db
</tool_call>

Natural text response here...
```

When building context for the next LLM round, these tags are **stripped** (regex removal) so the LLM only sees clean text. The tags are preserved in `AgentMessage.content` for UI rendering.

## Streaming Parts

```swift
enum StreamingPart {
    case text(String)
    case thinking(String)
    case toolCall(id, name, displayText, iconName, isComplete, round)
}
```

`AgentChatController.streamingParts` is an array that accumulates incrementally as tokens arrive. `AgentMessageListController` observes this for live rendering.

## AgentDriverSession

An `actor` that manages database connections for the agent:
- Caches connection state (`connectedKeychainId`, `connectedDatabaseName`)
- Reuses connection if target matches current
- Methods: `connect()`, `listCollections()`, `getSchema()`, `executeRawQuery()`, `disconnect()`

## Invariants

- Uses AWS Bedrock via `BedrockService.shared.notebookChatCompletionStream` with Claude Sonnet 4.6 (`global.anthropic.claude-sonnet-4-6`, see `pluk/Services/Bedrock/BedrockConfig.swift`). The agent loop still uses `BedrockGLMChatMessage` / `BedrockGLMToolDefinition` internally, and `BedrockService` adapts those to Anthropic Messages API types at the service boundary.
- Conversation continuity is maintained by appending to a `[BedrockGLMChatMessage]` array (`glmMessages` in `AgentChatController.performAgentLoop`), not by a session id. Every round: prior messages + new assistant message + tool-role results → next call.
- Tool-role messages must carry `toolCallId` and `name` matching the call so GLM can pair them.
- Streaming exposes two channels: `onToken` for assistant text and `onThinking` for reasoning deltas. Reasoning is re-serialized into `<thinking>` tags by `serializeThinking(from:)` before being persisted to `AgentMessage.content`.
- Maximum 100 rounds per agent loop (safety limit) and the loop also respects `Task.isCancelled`.
- `pendingBlockCreations` / `pendingNotebookInfoUpdate` / `pendingDashboardArrangement` are drained into the notebook after each round's tool executions, then cleared via `engine.clearPendingCreations()`.
- `run_query` blocks writes by prefix check in `NotebookAgentEngine` (`blockedPrefixes = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "TRUNCATE", "CREATE"]`).
- System prompt includes: available connections, pre-fetched Convex deployments, chart types, aggregation functions, current notebook blocks, optional conversation summary, and workflow instructions.

## Gotchas

- `SQLiteDriver.switchDatabase(to:)` disconnects and reopens the *name* as a file path — for SQLite the database name is just the file's display name, so switching tears down security-scoped file access and leaves the driver dead ("Not connected to SQLite database" on the next query). `AgentDriverSession.connect` therefore skips `switchDatabase` entirely for `.sqlite`. The LLM always passes `database_name` (it's in the system prompt's connection list), so any new tool path that forwards `database_name` into a driver switch must exclude SQLite the same way.

## Anti-Patterns

- Do NOT allow write queries through `run_query` — the prefix check in `NotebookAgentEngine` is a security boundary.
- Do NOT feed XML tags (`<thinking>`, `<tool_call>`) back to the LLM — `buildBedrockGLMMessages()` strips them from prior assistant turns before resending.
- Do NOT create blocks, mutate notebook info, or reorder the dashboard directly from tool handlers — enqueue via `pendingBlockCreations` / `pendingNotebookInfoUpdate` / `pendingDashboardArrangement` so `AgentChatController` owns the lifecycle.
- Do NOT introduce a "session id" or "previous response id" chaining scheme — GLM on Bedrock is stateless; the full `glmMessages` array is the source of truth for continuity.
- Do NOT route the notebook agent through `BedrockGLMService`; it uses the Anthropic `BedrockService` notebook adapter so tool calls and tool results stay compatible with Claude Sonnet.
