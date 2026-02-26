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
| `list_tables` | List tables/collections in a connection | Table names |
| `get_table_schema` | Get column metadata for a table | Column info |
| `run_query` | Execute exploratory SELECT queries | Query results |
| `create_chart_block` | Queue chart block creation | Confirmation |
| `create_text_block` | Queue text block creation | Confirmation |

## Agent Loop Flow

```
User sends message
  ↓
AgentChatController.performAgentLoop()
  ↓
for round in 0..<100:
  ↓
  NotebookAgentEngine.performRound(input, previousResponseId)
    ├─ Streams tokens → onToken callback → streamingParts updated live
    ├─ Streams reasoning → onReasoning callback → thinking blocks
    └─ Returns AgentRoundResult (text, toolCalls, responseId)
  ↓
  if toolCalls.isEmpty → END LOOP (assistant done)
  ↓
  for each toolCall:
    ├─ engine.executeToolCall(toolCall, connections)
    ├─ Block creations queued in engine.pendingBlockCreations
    └─ Tool results collected
  ↓
  Feed tool results back as next round input
```

## Write Operation Blocking

The agent can ONLY run read-only queries. Blocked prefixes:
`INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `TRUNCATE`, `CREATE`

Block creation happens through dedicated tools (`create_chart_block`, `create_text_block`), not raw SQL.

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

- Uses OpenAI Responses API via AIProxy (model: GPT-5.1)
- `previousResponseId` chains rounds for conversation continuity
- Maximum 100 rounds per agent loop (safety limit)
- Tool results are plain text strings fed back to the LLM
- `pendingBlockCreations` is drained after each tool call, not at end of loop
- System prompt includes: available connections, chart types, aggregation functions, workflow instructions

## Anti-Patterns

- Do NOT allow write queries through `run_query` — the prefix check is a security boundary
- Do NOT feed XML tags back to the LLM — always strip with `stripSerializedTags()`
- Do NOT create blocks directly — use `pendingBlockCreations` queue for proper lifecycle
- Do NOT skip `previousResponseId` chaining — breaks conversation continuity in Responses API
