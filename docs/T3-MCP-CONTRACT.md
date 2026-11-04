# T3 Code MCP contract for the Drawspeak iPad client

Status: implementation contract derived from code inspection and read-only live probes. Date: 2026-11-04.
Client: Drawspeak, iPadOS, Swift, bundle id `com.wydrox.drawspeak`.
Server: T3 Code (Nightly) `0.1.7-nightly.20261101.4016`, environment "Rafal's Mac mini", exposed by Tailscale Serve at `https://rafals-mac-mini.tail71fdd0.ts.net` (proxied to `http://127.0.0.1:3773`).

This contract supersedes the technical parts of [T3-INTEGRATION.md](T3-INTEGRATION.md) for the MCP path. It describes one build. Any other build must be checked again (see section 14).

## 0. Evidence conventions and confidence

| Tag | Meaning |
|---|---|
| `B:<line>` | Line in archive member `/apps/server/dist/binCli-Cos3Z5rn.mjs` of `/Applications/T3 Code (Nightly).app/Contents/Resources/app.asar`. To read it, extract with `npx --yes @electron/asar extract <app.asar> <empty dir>`. |
| `CAS` | `/apps/server/dist/client/assets/ConnectAgentSurface-Cg8f620w.js` (the `/connect-agent` approval page; minified, cited by string). |
| `CS` | `/apps/server/dist/client/assets/ConnectionsSettings-BR5M-KFB.js` (Settings → Sharing & access; minified, cited by string). |
| `L<n>` | Live probe against the server on 2026-11-04 (section 13). |
| `T` | Advertised tool JSON schema as served by this server's `tools/list` (read through an existing T3 MCP connection). |

Confidence levels used below: **Verified (code+live)**, **Verified (code)**, **Unverified (device)**: needs a physical-iPad spike.

Nothing was approved, paired, uploaded or sent during this research. The probe registrations were stateless (section 2.3).

## 1. Base URLs and discovery

All URLs derive from the request origin. Behind Tailscale Serve, the origin is `https://rafals-mac-mini.tail71fdd0.ts.net` (B:351764–351773, L1).

| Purpose | Method and path | Auth |
|---|---|---|
| Protected resource metadata | `GET /.well-known/oauth-protected-resource` and `GET /.well-known/oauth-protected-resource/mcp` (identical) | none |
| Authorization server metadata | `GET /.well-known/oauth-authorization-server` | none |
| Environment descriptor | `GET /.well-known/t3/environment` | none |
| Client registration | `POST /oauth/mcp/register` (JSON) | none |
| Authorize (browser entry) | `GET /oauth/mcp/authorize` | none |
| Approval details (read by the approval page) | `POST /oauth/mcp/approval` (JSON) | optional browser cookie |
| Approval decision | `POST /oauth/mcp/decision` (JSON) | none for `pairing-code` |
| Token | `POST /oauth/mcp/token` (**form-urlencoded only**) | none |
| MCP | `POST /mcp`, `DELETE /mcp` | `Authorization: Bearer` |
| Attachment byte upload | `POST /api/attachments/upload/<signed token>` | the signed URL is the capability |

Route table: B:20542–20558. Metadata builders: B:351777–351792.

Live metadata (L1):

```json
{"resource":"https://rafals-mac-mini.tail71fdd0.ts.net/mcp",
 "authorization_servers":["https://rafals-mac-mini.tail71fdd0.ts.net"],
 "scopes_supported":["orchestration:read","orchestration:operate"],
 "bearer_methods_supported":["header"],"resource_name":"T3 Code"}
```

```json
{"issuer":"https://rafals-mac-mini.tail71fdd0.ts.net",
 "authorization_endpoint":"https://rafals-mac-mini.tail71fdd0.ts.net/oauth/mcp/authorize",
 "token_endpoint":"https://rafals-mac-mini.tail71fdd0.ts.net/oauth/mcp/token",
 "registration_endpoint":"https://rafals-mac-mini.tail71fdd0.ts.net/oauth/mcp/register",
 "response_types_supported":["code"],"grant_types_supported":["authorization_code"],
 "code_challenge_methods_supported":["S256"],"token_endpoint_auth_methods_supported":["none"],
 "scopes_supported":["orchestration:read","orchestration:operate"],
 "authorization_response_iss_parameter_supported":true}
```

`GET /.well-known/t3/environment` returns `environmentId` (`6048609f-ad56-4b36-8af2-da85d0883cc4`), `serverVersion`, `orchestrationProtocolVersion: 2` and capability flags, including `fileAttachments.maxUploadBytes: 52428800` (L1). Drawspeak should read it at connect time, store `environmentId` and `serverVersion`, and show a warning when `serverVersion` differs from the version this contract was checked against.

Client rule: discover endpoints from metadata; do not hard-code paths. Check that `grant_types_supported` contains `authorization_code` and `code_challenge_methods_supported` contains `S256`.

## 2. Dynamic client registration

### 2.1 Request

`POST /oauth/mcp/register`, `Content-Type: application/json` (B:4556–4561, B:351895–351918).

```json
{"client_name":"Drawspeak (iPad)","redirect_uris":["http://127.0.0.1/drawspeak/oauth/callback"]}
```

| Field | Rule |
|---|---|
| `client_name` | Optional. Trimmed, cut to 100 characters, default `"MCP client"` (B:351752, B:351755, B:351896–351897). It is self-declared. T3 shows it on the approval page and as the label of the issued session in Settings → Sharing & access (B:352011–352016). |
| `redirect_uris` | Required, 1 to 5 entries (B:351753, B:351899–351902). Each entry must be at most 512 characters, have no `#`, have no userinfo, and be `https:` or `http:` on `localhost`, `127.0.0.1` or `[::1]` (B:351793–351802, B:351903–351906). |
| `software_id` | Do not send. The value `t3code-peer-link` turns the client into a T3 peer link with extra limits (B:4555, B:351907–351911). |
| `token_endpoint_auth_method` | Ignored. The response always gives `none`. |

**Custom URL schemes are rejected.** `drawspeak://oauth/callback` and `com.wydrox.drawspeak:/oauth/callback` both return HTTP 400 (L2):

```json
{"error":"invalid_redirect_uri","error_description":"Redirect URIs must be https, or http on localhost, 127.0.0.1 or [::1]."}
```

Accepted in L2: `https://drawspeak.example/oauth/callback`, `http://127.0.0.1/oauth/callback`, `http://localhost:53682/oauth/callback`. Rejected: `http://<tailnet host>/cb`, any URI with `#`, zero URIs, six URIs.

### 2.2 Redirect matching

For loopback URIs the port is ignored (RFC 8252 section 7.3). Hostname, path and query must match exactly. HTTPS URIs must match exactly (B:351802–351809, L3). Register `http://127.0.0.1/drawspeak/oauth/callback` and present any port, or none.

### 2.3 Response, lifetime, persistence

HTTP 201 (B:4562–4569, B:352126–352133):

```json
{"client_id":"<base64url JSON>.<base64url HMAC>","client_name":"Drawspeak (iPad)",
 "redirect_uris":["http://127.0.0.1/drawspeak/oauth/callback"],
 "grant_types":["authorization_code"],"response_types":["code"],"token_endpoint_auth_method":"none"}
```

- The `client_id` is stateless. It is `base64url({"v":1,"n":<name>,"r":[<redirect uris>]})` plus an HMAC made with the server secret `mcp-oauth-signing-key` (B:351749, B:351853, B:351862–351886, decoded in L3). Nothing is stored on the server, so registration has no side effects.
- The `client_id` has no expiry. It stays valid while the server signing secret is unchanged. If the secret changes, authorize and decision answer "This sign-in link names an unknown app…" (B:351921).
- Client rule: register again at the start of every pairing. It costs one request and removes a cache-invalidation case. Do not treat the `client_id` as a secret, and do not reuse it as an identity.

## 3. Approval: getting an authorization code

Approval always needs one of these (B:351967–351973, B:4599–4609):

1. a **one-time pairing code** created on the Mac, or
2. a T3 **browser session cookie** for this origin that holds `access:write` and `orchestration:read` (one-click approval). An iPad app does not have this cookie, so Drawspeak uses (1).

The approval decision also picks an **access level**. The level sets the token scopes and the runtime-mode ceiling (B:4517–4530, B:135017–135033):

| `access` | Token scopes | Write ceiling |
|---|---|---|
| `read-only` | `orchestration:read` | No writes (B:343639–343642). |
| `approval-required` | `orchestration:read orchestration:operate` | Can only send to threads whose `runtimeMode` is `approval-required`. |
| `auto-accept-edits` | same | Threads at `approval-required` or `auto-accept-edits`. |
| `auto` | same | Threads up to `auto`. |
| `full-access` | adds `settings:write source-control:write` | Every thread. Also allows project create, update and delete and environment-preference tools (B:343707–343714, B:343322). |

Rank: `approval-required` < `auto-accept-edits` < `auto` < `full-access` (B:151238–151243). A send or upload-send to a thread whose `runtimeMode` is above the client ceiling fails with `runtime_mode_escalation_denied` (B:343228–343242, B:343311, B:345810–345812). **New T3 threads default to `full-access`** (B:14625). So with any lower level, Drawspeak cannot send to default threads. Decision for Drawspeak: request `full-access` by default, show the user that this level is broader than Drawspeak needs, and allow a lower level for users whose target threads run lower. The optional header `T3-Mode-Limit: <runtimeMode>/<interactionMode>` can narrow the ceiling per request, but cannot widen it (B:151237, B:348787–348822).

### 3.1 Route A (recommended): native pairing, no browser

This is the same sequence T3 uses to link two T3 environments (`PeerLinks.signIn`, B:137990–138041): register, then decision, then token. The redirect URI is only compared, never loaded, so a loopback URI works without any listener on the iPad. **Verified (code+live)** up to the decision call; one full exchange is still **Unverified (device)**.

User steps (exact):

1. On the Mac, in T3 Code (Nightly): **Settings → Sharing & access → Create pairing link**. Keep the default scopes (standard client scopes, B:4339–4356). Then select **Show code** and copy or read the **Pairing code** (CS strings: "Create pairing link", "Show code", "Pairing code"). Alternative: in Terminal, run `t3 auth pairing create --label "Drawspeak iPad"` (B:137456–137473; CLI availability on this Mac not checked).
   - The code is 12 characters from `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`, case-insensitive (B:130389–130392). It expires after **5 minutes** (B:130386, B:130475) and works **once**.
2. On the iPad, in Drawspeak: open **Connect to T3**. Confirm the host `https://rafals-mac-mini.tail71fdd0.ts.net`, paste the code, select the access level (default `full-access`, see above), then select **Connect**.
3. Optional check on the Mac: **Settings → Sharing & access** lists the authorized client "Drawspeak (iPad)" with a **Revoke** action (CS: "Inspect pairing links and authorized clients.", "Revoke").

App sequence for step 2:

1. Discovery (section 1). Store `issuer` and `resource`.
2. Register (section 2). Store `client_id`.
3. Generate PKCE: `code_verifier` = 32 random bytes as base64url (43 characters, must match `^[A-Za-z0-9\-._~]{43,128}$`); `code_challenge` = base64url(SHA-256(verifier)) without padding (43 characters, must match `^[A-Za-z0-9_-]{43}$`) (B:351759–351760). `state` = 16 or more random bytes as base64url.
4. `POST /oauth/mcp/decision`, `Content-Type: application/json` (B:4610–4614, B:352168–352180):

```json
{"authorization":{
   "response_type":"code",
   "client_id":"<client_id>",
   "redirect_uri":"http://127.0.0.1/drawspeak/oauth/callback",
   "code_challenge":"<43 chars>",
   "code_challenge_method":"S256",
   "state":"<state>",
   "resource":"https://rafals-mac-mini.tail71fdd0.ts.net/mcp"},
 "decision":{"_tag":"pairing-code","access":"full-access","code":"<12-char code>"}}
```

5. Handle the response:
   - HTTP 200 `{"redirectTo":"http://127.0.0.1/drawspeak/oauth/callback?code=<code>&state=<state>&iss=<issuer>"}` (B:351967–351985). Parse it without loading it. Check that `state` equals the sent value and `iss` equals the `issuer` (RFC 9207). If `redirectTo` has `error`/`error_description` instead (for example `invalid_target`, `invalid_request`), stop and show `error_description` (B:351925–351943, B:351843–351853).
   - HTTP 400 `{"_tag":"AuthMcpApprovalError","message":"…"}` (L5). Show `message`. The pairing-code messages are (B:134646–134655):
     - `"That pairing code is unknown, expired, or already used."`
     - `"That pairing code cannot grant this access. It has not been used, so choose an access level it grants, or create a code with the standard scopes."` (the code is **not** used; the user can select a lower level and try again)
     - `"That is not a one-time pairing code."`
   - A valid code is used up at this step, even if the token step fails later.
6. Within **60 seconds** (authorization-code TTL, B:351751; codes are single-use and kept in memory only, B:351948–351966, B:351991–352010), exchange the code (section 4).

### 3.2 Route B (fallback): ASWebAuthenticationSession on `/oauth/mcp/authorize`

**Unverified (device).** Use this only if Route A must be avoided.

- `GET /oauth/mcp/authorize?response_type=code&client_id=…&redirect_uri=…&code_challenge=…&code_challenge_method=S256&state=…&resource=…` validates the request. On success it returns `302 Location: /connect-agent?<same query>` (B:352134–352152, L3). An unknown client or unregistered redirect gives an HTML 400 page and **no** redirect (L3: "This sign-in link sends you to an address the app did not register."). Other errors go back to the redirect URI as `error`, `error_description`, `state` and `iss` (L3: missing PKCE gives `invalid_request`; a wrong `resource` gives `invalid_target`).
- `/connect-agent` is a SPA (L4). It posts the query to `/oauth/mcp/approval`. Without a T3 cookie, the answer is only `{"clientName","redirectHost","environmentHost"}` with no `csrfToken` or `oneClickAccess` (L4, B:352153–352167). The page then shows an access-level radio group and a **Pairing code** field ("Paste a one-time pairing code… Create one in Settings → Sharing & access, or run `t3 auth pairing create` on this machine", CAS). The user still needs the same pairing code as in Route A. **Approve** posts `/oauth/mcp/decision`, then the page calls `window.location.replace(redirectTo)` (CAS).
- One-click approval appears only if the web view has a T3 browser-session cookie for this origin with `access:write` and `orchestration:read` (B:351944–351947). That needs a separate earlier web pairing in Safari. A non-ephemeral `ASWebAuthenticationSession` shares Safari cookies; an ephemeral one does not.
- Callback: custom schemes cannot be registered (section 2.1). The two options are:
  - `https://<domain you control>/…` with `ASWebAuthenticationSession.Callback.https(host:path:)` (iPadOS 17.4+). This needs an associated domain and an `apple-app-site-association` file on that domain. Drawspeak has neither today.
  - `http://127.0.0.1:<port>/drawspeak/oauth/callback` with an in-app `NWListener` on loopback. When the request arrives, call `cancel()` on the session. Whether the auth sheet's top-level navigation from `https:` to loopback `http:` reaches the app's listener on iPadOS is **unverified**.
- Route B adds a web UI and a callback mechanism but removes no step for the user. Recommendation: **Route A**.

### 3.3 What `resource` and `iss` do

- `resource` is optional at authorize, decision and token. If present, it must equal `<origin>/mcp` exactly (a trailing slash is stripped; no fragment) (B:351810–351818, L3). Send it.
- `iss` is always added to the redirect (`authorization_response_iss_parameter_supported: true`) (B:351792, B:351843–351853, B:351981–351985). Check it.
- The issued token is **not** audience-bound at `/mcp`: `/mcp` only checks the session (B:135007–135016). The resource check applies only at the code exchange.

## 4. Token

### 4.1 Request

`POST /oauth/mcp/token`, `Content-Type: application/x-www-form-urlencoded` (B:4615–4622 `asFormUrlEncoded`). A JSON body gets `415 Unsupported content-type: application/json` (L6).

```
grant_type=authorization_code&code=<code>&redirect_uri=http%3A%2F%2F127.0.0.1%2Fdrawspeak%2Foauth%2Fcallback&client_id=<client_id>&code_verifier=<verifier>&resource=https%3A%2F%2Frafals-mac-mini.tail71fdd0.ts.net%2Fmcp
```

`redirect_uri` must be the exact string used in the decision (B:352008). No client secret.

### 4.2 Response

HTTP 200, headers `cache-control: no-store`, `pragma: no-cache` (B:4623–4628, B:352017–352022):

```json
{"access_token":"<base64url claims>.<base64url signature>","token_type":"Bearer","expires_in":2592000,
 "scope":"orchestration:read orchestration:operate settings:write source-control:write"}
```

(`scope` shown for `full-access`; other levels per the table in section 3.)

Errors: HTTP 400 `{"error":"invalid_request"|"invalid_client"|"invalid_grant"|"unsupported_grant_type","error_description":"…"}` (B:4629–4642, B:351991–352010, L6). An expired, used or mismatched code, a wrong verifier or a wrong `resource` all give `invalid_grant` ("The authorization code is invalid or expired."). A server restart between decision and token also loses the code (in-memory map).

### 4.3 Lifetime, refresh, revocation, expiry

- **Lifetime: 30 days, fixed.** The `exp` claim is signed into the token (`MCP_CLIENT_SESSION_TTL = days(30)`, B:134478, B:135017–135033, B:131083–131101). There is no sliding renewal.
- **No refresh.** Metadata lists only `authorization_code`. `grant_type=refresh_token` returns `unsupported_grant_type` (B:351995, L6). No `refresh_token` is ever issued.
- **Revocation:** there is no RFC 7009 endpoint on the MCP surface. The user revokes on the Mac in Settings → Sharing & access (client sessions list, Revoke). Every request checks the session row: a revoked or unknown session fails (B:131306–131367). The MCP token cannot call `/api/auth/clients/revoke`: tokens with subject `mcp-client` are rejected everywhere outside `/mcp` (B:134678, B:134743). So "Disconnect" in Drawspeak can only delete the local token and tell the user to revoke the client on the Mac.
- **On expiry or revocation:** `POST /mcp` returns HTTP 401 `{"error":"invalid_mcp_credential","message":"A valid T3 Code MCP credential is required."}` with `www-authenticate: Bearer resource_metadata="<origin>/.well-known/oauth-protected-resource/mcp", error="invalid_token"` (B:348763–348777, B:348821–348847, L1). Recovery: **pair again** (new pairing code, section 3.1). Store `expiresAt = now + expires_in` and ask the user to re-pair about 3 days before it.
- Storage: Keychain, `kSecClassGenericPassword`, service `com.wydrox.drawspeak.t3`, account `<environmentId>`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Store `access_token`, `scope`, `expiresAt`, `issuer`, `environmentId` and the access level. Never log the token.

## 5. MCP over HTTP

### 5.1 Transport facts

| Item | Value | Evidence |
|---|---|---|
| Endpoint | `POST <origin>/mcp` | B:349329–349335 |
| Protocol versions | `2025-06-18` only | B:349333 |
| Topology | Streamable HTTP, single endpoint, **stateful** sessions | B:341990–342043 |
| Request `Content-Type` | first media type must be `application/json`, else 415 | B:342073 |
| Request `Accept` | must contain both `application/json` and `text/event-stream`, else 406 | B:342074–342075 |
| `Origin` header | Do **not** send. If present it must be in an allow-list, which is empty, so 403 (checked after auth) | B:342072, B:342174–342177 |
| Auth | `Authorization: Bearer <access_token>` on every request, checked before routing | B:348821–348847 |
| Session id | Response header `mcp-session-id` (UUID) on `initialize`, also `mcp-protocol-version` | B:340097–340103 |
| Later requests | must send `Mcp-Session-Id`, else 400 "MCP-Session-Id header is required; send initialize to start a session" | B:340024 |
| `initialize` with a session header | 400 | B:340023 |
| `MCP-Protocol-Version` | optional after init; if sent it must be `2025-06-18` | B:339861–339880 |
| Unknown session id | 404, the request **was not executed** | B:339881–339885 |
| Session storage | in memory, no idle expiry, lost when T3 restarts | B:339714–339738 |
| End session | `DELETE /mcp` with `Mcp-Session-Id` returns 204 | B:342070, B:340034–340043 |
| `GET`/`PUT`/`PATCH`/`OPTIONS /mcp` | 405 when authenticated; 401 when not (L4) | B:342065–342069 |
| JSON-RPC batches | rejected (400) for 2025-06-18 | B:339999–340006 |
| Notifications | 202, empty body | B:342084, B:348778–348781 |

### 5.2 Response body: JSON or SSE

A single response is `application/json`. The server switches to `text/event-stream` when the response is a stream or carries more than one JSON-RPC message, for example progress or log notifications before the result (B:342080–342083). Drawspeak must handle both: parse SSE `data:` lines and take the JSON-RPC message whose `id` matches the request.

### 5.3 Handshake

```
POST /mcp
Authorization: Bearer <token>
Content-Type: application/json
Accept: application/json, text/event-stream

{"jsonrpc":"2.0","id":1,"method":"initialize",
 "params":{"protocolVersion":"2025-06-18","capabilities":{},
           "clientInfo":{"name":"Drawspeak","version":"<app version>"}}}
```

Read `Mcp-Session-Id` from the response headers. Then send `{"jsonrpc":"2.0","method":"notifications/initialized"}` (expect 202) and `tools/list`. All later calls send `Mcp-Session-Id` and `MCP-Protocol-Version: 2025-06-18`.

### 5.4 Status codes and whether the call ran

| Result | Executed? | Client action |
|---|---|---|
| 401 | No (auth runs before the handler) | Pair again. |
| 400 / 403 / 406 / 415 | No (admission) | Fix the client. |
| 404 on a session request | No (admission) | Initialize again, then repeat the same request once. This is safe for every tool. |
| 200/SSE with JSON-RPC `result` | Yes | Read `isError`. |
| Transport error, timeout or reset after the request was sent | **Unknown** | Read tools: retry. Writes: see section 9. |

### 5.5 Timeouts

`t3_thread_wait` can keep a request open for up to 1 hour (B:344282–344283). Do not rely on long-held requests over Tailscale Serve and iPad networking. Use `timeoutMs` of 25 000 or less and loop. Set `URLSessionConfiguration.timeoutIntervalForRequest` to 60 s or more. Use `URLSessionConfiguration.ephemeral` with `httpShouldSetCookies = false` so that no cookie or `Origin` is added.

## 6. Tool result encoding

- Success: `result = {"content":[{"type":"text","text":"<JSON of the result>"}],"structuredContent":<result object>,"isError":false}` (B:342195–342198, B:342270–342276, B:341215–341227). Read `structuredContent`.
- Tool failure (all T3 tools use `failureMode: "return"`): `isError: true`, **no** `structuredContent`, and `content[0].text` is the JSON-encoded failure, expected to be `{"_tag":"OrchestratorMcpFailure","code":"<code>","message":"<text>"}` (B:342273–342274, B:34678–34698). Codes: `capability_denied`, `parent_not_active`, `provider_unavailable`, `model_unavailable`, `runtime_mode_escalation_denied`, `interaction_mode_escalation_denied`, `task_not_found`, `task_not_cancellable`, `thread_not_found`, `run_not_found`, `thread_not_sendable`, `thread_not_interruptible`, `invalid_request`, `orchestration_error`, `thread_credential_required`, `target_required`.
- Input that fails schema validation also comes back as an error. `t3_thread_read` is `Strict`, so unknown properties are rejected (B:347067–347073). Send only the documented fields.

## 7. Tools an OAuth client can use

`tools/list` is the same for every credential: tools are registered once on one shared server (B:349310–349337, B:341990–342043). Only the linked-environment tools (`t3_environment_links/link/unlink`, hidden while Labs → Linked environments is off) and the PR watch tools for subagents are hidden per request (B:151279–151290). Each handler then applies its access wrapper (B:343639–343714):

| Wrapper | OAuth client (Drawspeak) |
|---|---|
| `reads` | allowed |
| `writes`, `writesThreads`, `startsThreads` | allowed unless `read-only`; `writesThreads` also checks the target thread's mode ceiling |
| `writesEnvironment` | `full-access` only |
| `actsAsCaller`, `readsAsCaller` | **refused**: `thread_credential_required` ("…needs an agent running inside T3 Code. This MCP client signed in from outside a thread.", B:151310–151314) |

OAuth clients get capabilities `orchestration`, `worktree` and `pull-requests`, with no thread scope and no `preview` or `device` (B:352034–352057).

Usable and relevant for Drawspeak:

| Tool | Wrapper | Use in Drawspeak |
|---|---|---|
| `t3_project_list`, `t3_project_read` | reads | project picker |
| `t3_thread_list` | reads | thread picker |
| `t3_thread_search` | reads | find a thread or `batchId` text |
| `t3_thread_read` | reads | status, replies, reconciliation |
| `t3_thread_wait` | reads | wait for a run to finish |
| `t3_queue` `list`/`read` | reads | reconciliation of queued sends |
| `t3_attachment_prepare_upload`, `t3_attachment_discard` | writes | uploads |
| `t3_thread_send_attachments` | writesThreads | **the feedback send** |
| `t3_thread_send` | writesThreads | text-only follow-up (idempotent) |
| `t3_thread_interrupt` | writesThreads | optional Stop |
| `t3_thread_launch` | startsThreads | optional "new review thread" (not specified here) |
| `t3_environment_read` | reads | server identity |

Unusable from Drawspeak (thread caller only): `delegate_task`, `task_status`, `task_cancel`, `create_threads`, `request_secret`, `t3_background_wait`, `t3_worktree_handoff`, `t3_worktree_status`, `t3_preview_list`, `t3_preview_close`, all `preview_*`, all `device_*`, `html_render`, `html_preview`.

## 8. Tool contracts used by Drawspeak

Omit `environmentId` on every tool; it targets linked environments (B:34291). Identifiers are opaque strings; threads created over MCP look like `mcp:<uuid>`.

### 8.1 `t3_project_list` / `t3_project_read`

Input: `{"cursor"?: int>=0 (default 0), "limit"?: 1..100 (default 20)}` and `{"projectId": string}` (B:343786–343809, B:346232–346244).
Result: `{"projects":[Project], "nextCursor": int|null}` and `Project`, where `Project = {id, title, workspaceRoot, repositoryIdentity?, faviconPath?, projectIcon?, defaultModelSelection|null, defaultThreadEnvMode?, autoPull?, scripts[], pinnedAt?, archivedAt?, createdAt, updatedAt, deletedAt|null}` (B:14753–14769). The tool notes "Pages can shift."

### 8.2 `t3_thread_list`

Input (B:34292–34304, T):

```json
{"projectId":"<id>", "allProjects":false, "statuses":["idle","running"], "titleContains":"…",
 "settled":false, "snoozed":false, "includeSubagents":false, "cursor":0, "limit":50}
```

- OAuth clients must pass `projectId` or `allProjects: true`, else `target_required` (B:344840, B:345726–345727).
- `includeSubagents` defaults to **true** (B:345730). Pass `false`.
- `limit` defaults to 50, maximum 100 (B:344307). `statuses` has at most 10 entries from `idle` plus the run statuses.

Result (B:34311–34342):

```json
{"projectId":"<id>|null","currentThreadId":null,"nextCursor":50,"total":123,
 "threads":[{"threadId":"…","projectId":"…","title":"…","link":"https://rafals-mac-mini.tail71fdd0.ts.net/<envId>/<threadId>",
   "createdBy":"user|agent|system","creationSource":"web|mobile|mcp|provider|server",
   "status":"idle|preparing|queued|starting|running|waiting|completed|interrupted|failed|cancelled|rolled_back",
   "latestRunId":"…|null","providerInstanceId":"…","model":"…",
   "runtimeMode":"approval-required|auto-accept-edits|auto|full-access","interactionMode":"default|plan",
   "linkedPullRequest":null,"pullRequests":[],"settled":false,"settledAt":null,"snoozed":false,"snoozedUntil":null,
   "parentThreadId":null,"relationshipToParent":null,"itemCount":42,"createdAt":"…","updatedAt":"…"}]}
```

For OAuth clients, `link` is a web URL on the reached origin (B:151270–151276). Use it as "Open in T3". Use `runtimeMode` to tell the user ahead of time when the access level cannot send to a thread (section 3).

### 8.3 `t3_thread_read`

Input (B:34348–34358, T):

```json
{"threadId":"<id>","view":"messages","afterPosition":120,"limit":20,"maxCharsPerItem":50000,"runLimit":5}
```

| Field | Default | Range |
|---|---|---|
| `view` | `messages` (user and assistant messages and plans); `activity` returns every timeline item | |
| `afterPosition` | -1 (from the start, exclusive) | int >= 0 |
| `limit` | 50 | values above 100 are clamped to 100 |
| `maxCharsPerItem` | 20 000 | values above 50 000 are clamped |
| `runLimit` | 10 | values above 50 are clamped |
| `itemId` + `textOffset` | continue one cut-off item | |

Defaults: B:344308–344310. Handler: B:345748–345806.

Result (B:34359–34430):

```json
{"thread":{"threadId":"…","projectId":"…","title":"…","link":"…","createdBy":"…","creationSource":"…",
   "status":"…","latestRunId":"…|null","activeRunId":"…|null","providerInstanceId":"…","model":"…",
   "runtimeMode":"…","interactionMode":"…","linkedPullRequest":null,"titleRegeneration":null,
   "branch":"…|null","worktreePath":"…|null","parentThreadId":null,"relationshipToParent":null,
   "runCount":3,"itemCount":57,"pendingRequestCount":0,"archived":false,"settled":false,"settledAt":null,
   "snoozed":false,"snoozedUntil":null,"createdAt":"…","updatedAt":"…"},
 "recentRuns":[{"runId":"…","ordinal":3,"status":"completed","providerInstanceId":"…","model":"…",
   "requestedAt":"…","startedAt":"…|null","completedAt":"…|null"}],
 "items":[{"position":121,"visibility":"local|inherited|synthetic","sourceThreadId":"…","itemId":"…",
   "runId":"…|null","messageId":"…|null","createdBy":"user|agent|system|null","creationSource":"…|null",
   "type":"user_message|assistant_message|proposed_plan|…","status":"idle|pending|running|waiting|completed|failed|cancelled|interrupted",
   "title":null,"text":"…","textTruncated":false,"nextTextOffset":null,"updatedAt":"…"}],
 "nextPosition":140,"hasMore":true}
```

- Paging: call again with `afterPosition = nextPosition` while `hasMore`. Cache the last position per thread so later reads are incremental.
- A cut-off item (`textTruncated: true`): call `{"threadId","itemId","textOffset": nextTextOffset}`.
- `text` of `user_message` and `assistant_message` is the raw message text (B:344695–344699, B:344738–344764).
- **Items carry no attachment data: no ids, names, sizes or URLs** (schema B:34401–34423). The `activity` view adds tool items as text: `file_change` gives the file name, `+a -d` and diff or new text; `command_execution` gives `$ cmd` and output; `dynamic_tool` gives JSON (B:344700–344736).

### 8.4 `t3_thread_wait`

Input: `{"threadId","runId"?,"timeoutMs"?: number,"untilDelegatedWorkSettled"?: bool}`. Default timeout 600 000 ms, clamped to 1..3 600 000 (B:34457–34463, B:345846–345870).
Result: `{"threadId","runId": string|null,"status": <thread status>,"timedOut": bool,"next"?: string,"resultRun"?: {"runId","status"}}` (B:34464–34474). An idle thread returns at once. Drawspeak: `timeoutMs` of 25 000 or less, in a loop, cancelled when the view goes away.

### 8.5 `t3_queue` (read actions only)

- `{"action":"list","threadId","cursor"?,"limit"?: 1..100 (default 20)}` returns `{"items":[{"queuedRunId","text": <first 1000 chars>,"truncated": bool}],"nextCursor": int|null}`.
- `{"action":"read","threadId","queuedRunId"}` returns `{"queuedRunId","text": <up to 16 000 chars>,"truncated"}`.

Evidence: B:346447–346477, B:346598–346609, B:346765–346782. `threadId` is required for OAuth clients (B:343330–343333). Do not call `edit`, `cancel`, `reorder` or `promote_to_steer`.

### 8.6 `t3_attachment_prepare_upload`

Input (B:35020–35032, B:346308–346312). Always send `type`, although the server default is `image`:

```json
{"upload":{"type":"image","name":"screen-01-annotated.png","mimeType":"image/png","sizeBytes":834211}}
{"upload":{"type":"file","name":"review-manifest.json","mimeType":"application/json","sizeBytes":5120}}
```

| `type` | `mimeType` | `sizeBytes` | `name` |
|---|---|---|---|
| `image` | exactly one of `image/gif`, `image/jpeg`, `image/png`, `image/webp` | 1..10 485 760 (10 MiB) | 1..255 chars |
| `file` | any string, 1..100 chars (`text/html`, `application/json`, `application/zip` and `audio/*` are allowed) | 1..52 428 800 (50 MiB) | 1..255 chars; the extension is taken from the name if it matches `\.[a-z0-9]{1,10}`, else `.bin`; SVG names get `.svg` added |

Evidence: B:1904–1913, B:35020–35031, B:111185–111197, B:312766–312767, B:187887–187890.

Result (B:35033–35037, B:312753–312786):

```json
{"attachmentId":"pending-<uuid>[-<ext>]","relativeUrl":"/api/attachments/upload/<base64url claims>.<base64url HMAC>","expiresAt":1793791666000}
```

`expiresAt` is epoch milliseconds, **issue time + 10 minutes** (B:35019). The URL is a capability: keep it in memory only.

### 8.7 Upload bytes (plain HTTP, not MCP)

```
POST https://rafals-mac-mini.tail71fdd0.ts.net<relativeUrl>
Content-Length: <sizeBytes>          (if sent, it must equal sizeBytes)
Content-Type: <any; not checked>
<exact bytes>
```

- No `Authorization` header is needed (B:313422–313434).
- `204` means stored. The server also runs text extraction for documents (B:312795–312863).
- `404 Not Found`: bad signature, or the URL expired. Expiry is checked when the request starts (B:312786–312794). Prepare a new upload.
- `400 Content-Length must match the upload size.` or `400 Body was N bytes, expected M.` (B:313431, B:312796–312800, B:312834).
- `409 Attachment already uploaded.`: a second upload with different bytes. A second upload with **identical** bytes returns 204, so retrying an upload is safe (B:312836–312861).
- `500 Failed to persist upload.`
- After the upload, the pending file is kept for about 24 h, then swept (B:111178, B:346346). `t3_attachment_discard {"attachmentId"}` deletes a pending upload. Only the same OAuth session can discard it (B:346347, B:346361–346368).

### 8.8 `t3_thread_send_attachments` (the feedback send)

Input (B:346318–346332, B:343773, T):

```json
{"threadId":"<id>",
 "message":"[drawspeak-batch:6f1c…] <brief and numbered comments>",
 "attachments":[
   {"type":"image","id":"pending-<uuid>","name":"screen-01-annotated.png","mimeType":"image/png","sizeBytes":834211},
   {"type":"file","id":"pending-<uuid>-json","name":"review-manifest.json","mimeType":"application/json","sizeBytes":5120}]}
```

- `threadId` is required for OAuth clients (the server cannot infer a caller thread, B:343330–343336).
- `message`: optional, may be empty, at most 120 000 characters (not trimmed).
- `attachments`: 1 to 8 items. Each item repeats the prepared upload: `type`, `id` = `attachmentId`, `name`, `mimeType`, `sizeBytes`. Images take no `source`. Do not send `source` for files either: `{"_tag":"pasted-text"}` forces a path-only reference.
- Server checks before dispatch: no duplicate ids; every id is a pending upload (or already belongs to this thread); the stored size equals `sizeBytes`; the stored file type matches `type`; images total at most 80 MiB; the thread is not archived ("Unarchive the target thread before sending attachments."); the thread `runtimeMode` is within the ceiling. Evidence: B:315246–315290, B:2028–2031, B:346370–346400.
- Dispatch: `mode` is fixed at **`auto`** (B:346387). `auto` **starts** a run when the thread is idle. If a provider turn is running, the message **steers** that running turn (it is injected mid-turn). Otherwise it is started or queued after the active work (B:293095–293097, B:293195–293246). So **yes, a send starts or redirects the agent**. Attachments cannot be queued explicitly.
- The stored message has `createdBy: "agent"` and `creationSource: "mcp"` and no `senderThreadId` (B:346388–346389).

Result (B:346327–346332, B:346394–346399): `{"threadId","messageId","runId","status": <run status>}`. There is no `delivery` field. Infer it: `runId` equal to the `activeRunId` read just before the send means steered; `status: "queued"` means queued; otherwise started. "Success does not mean the provider read them or finished" (tool description).

What the agent receives (provider-dependent, B:188555–188572, B:198509–198530, B:173404): images inline when the provider supports images; PDFs and text-like files inline when the provider supports embedded context and within budget; every other file (and files over budget) as the line `[Attached file "<name>" is saved at: <absolute path>]`, plus `(text extracted to: …)` when extraction ran. HTML, JSON and ZIP files therefore reach the agent at least as a local path it can read.

### 8.9 `t3_thread_send` (text only, idempotent)

Input (B:34431–34442, T): `{"threadId","message": <trimmed, non-empty, at most 120 000>,"mode"?: "auto"|"queue"|"steer"|"restart","clientRequestId"?: <at most 256>}`.
Result (B:34443–34456): `{"threadId","link"?,"messageId","runId","taskId"?,"status","delivery":"started"|"queued"|"steered"|"restarted"}`.

- `steer` and `restart` fail when no run is steerable (B:293200–293208).
- With `clientRequestId`, `commandId` and `messageId` are deterministic: `message:mcp:client%3A<sessionId>:thread-send:<clientRequestId>` (B:344548–344584, B:345815–345824). Dispatch replays an existing receipt instead of running the command again (B:291749–291784). So a retry with the same `clientRequestId` **under the same token** is safe. After re-pairing, the session id differs and so does the key.
- It cannot carry attachments (`attachments: []`, B:345831).

### 8.10 `t3_thread_interrupt` (optional)

Input `{"threadId","runId"?,"reason"?: <at most 2000>,"stop"?: bool,"clientRequestId"?}`. Result `{"threadId","runId": string|null,"status":"interrupt_requested"|"no_active_run"|<terminal status>}` (B:34476–34505, B:345872–345926).

## 9. Send and reconciliation algorithm (ADR-0005)

`t3_thread_send_attachments` has **no retry key** ("No retry key", B:346321). A blind retry after a lost response creates a **second message**. The pending source file is copied, not moved, and every claim gets a new random final id, so the same `attachmentId`s are still accepted (B:111304, B:315281–315284).

1. Freeze the package. Make `batchId` (UUID). Put the marker `[drawspeak-batch:<batchId>]` in the **first line** of `message` so that the 1000-character queue preview contains it.
2. Before the send: `t3_thread_read {threadId, limit: 1, runLimit: 1}`. Store `thread.status`, `activeRunId` and `latestRunId`, and refuse early on `archived`, a mode above the ceiling, or a status that needs user confirmation. If `status` is `running`, ask the user whether to steer now (the only option for attachments) or wait (`t3_thread_wait`).
3. For each file: `t3_attachment_prepare_upload`, then upload. Retry each step freely. If the URL has expired, prepare a new one.
4. Call `t3_thread_send_attachments` **once**. When `result.isError` is false, store `messageId`, `runId` and `status` in the OutboxEntry and mark it **Sent (ACK)**.
5. If the outcome is unknown (transport error after the body was sent, or a timeout), mark **Delivery Unknown** and do not resend. Reconcile:
   1. `t3_thread_read {view: "messages", afterPosition: <cached position or start>}` and page to the end. Look for `type == "user_message"`, `createdBy == "agent"`, `creationSource == "mcp"`, with `text` containing the marker. If found, store its `messageId` and `runId` and mark it Sent.
   2. If not found: `t3_queue {action: "list", threadId}` and look for the marker in `text`. A queued message has no `user_message` item until its run starts (B:293236–293246).
   3. Optional: `t3_thread_search {query: "<batchId>", projectId}` (described as not exhaustive).
   4. Not found anywhere: show **Not delivered** and let the user decide to resend. A resend may reuse the pending `attachmentId`s while they are still present (about 24 h after upload). Otherwise upload again.
6. An HTTP 404 (unknown MCP session) or 401 proves the call did not run (section 5.4). For 404, initialize again and repeat once. For 401, pair again, then repeat once.
7. Text-only follow-ups use `t3_thread_send` with `clientRequestId = batchId`; these retry safely.

## 10. Pulling results back (P-12): what MCP gives, and the blocker

Through an MCP OAuth token, Drawspeak can read **only text**:

- the agent's reply text (`assistant_message`), with no size limit in practice through `maxCharsPerItem` (up to 50 000) and `itemId` + `textOffset` paging;
- tool activity text (`view: "activity"`), for example `file_change` diffs or new text of files the agent wrote, and command output.

Drawspeak **cannot** pull binary files (PNG screenshots), attachment bytes, or asset URLs through MCP in this build:

- Timeline items have no attachment fields (B:34401–34423).
- No MCP tool returns an asset or attachment URL (only `t3_attachment_prepare_upload` returns a URL, and it is for uploads).
- The REST snapshots (`/api/orchestration/threads/:id…`) and the WebSocket `assets.createUrl` RPC reject MCP tokens: "MCP client sessions are only accepted by the MCP endpoint." (B:134678, B:134743, B:134980).

Options (decision needed; not implemented here):

| Option | What it gives | Cost and risk |
|---|---|---|
| A. Text in the reply | The skill writes `review-manifest.json`, and optionally self-contained HTML, as fenced blocks in the final reply. Drawspeak reconstructs and checks the hash. | Works with this contract. The reply text becomes part of the agent context. Not suitable for PNG: base64 is 1.37 times the size, and a 3 MB PNG needs about 80 pages of 50 000 characters. |
| B. Second, read-only non-MCP credential | `POST /oauth/token` (RFC 8693, form) with `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`, `subject_token=<pairing code>`, `subject_token_type=urn:t3:params:oauth:token-type:environment-bootstrap`, `requested_token_type=urn:ietf:params:oauth:token-type:access_token`, `scope=orchestration:read filesystem:read`, `client_label=Drawspeak (iPad)` (B:4357–4359, B:4393–4402, B:20508–20512, B:134841–134869). Then the WS RPC `assets.createUrl` with `{"_tag":"workspace-file","threadId","path"}` (needs `filesystem:read`), or `attachment` / `tool-output-image` (needs `orchestration:read`), then `GET <origin><relativeUrl>` (B:34969–35018, B:328140–328146). | Second pairing code, second API family (WebSocket with Effect RPC, protocol header `2`). Needs its own contract spike. A narrow scope list keeps it read-only. |
| C. Companion service on the Mac | Agent writes the bundle to a folder; a small service serves it over the tailnet. | New component and new auth. |

Recommendation: plan **A for the manifest and HTML text plus B for images**, and run the B spike before the native pull is built. Until then, P-12 and AC-15 cannot be met for screenshots over MCP alone.

## 11. Limits (this build)

| Limit | Value | Evidence |
|---|---|---|
| Attachments per MCP message | 1 to 8 | B:346325 |
| Attachments per message (general) | 100 | B:2029 |
| Message text, `t3_thread_send_attachments` | 0 to 120 000 characters | B:346324 |
| Message text, `t3_thread_send` | 1 to 120 000 characters (trimmed) | B:34140 |
| Image size | 1 B to 10 MiB (10 485 760) | B:1905, B:35024 |
| Image MIME (upload) | `image/gif`, `image/jpeg`, `image/png`, `image/webp` | B:1908–1913, B:35022 |
| Images total per message | 80 MiB | B:1906, B:2030 |
| File size | 1 B to 50 MiB (52 428 800) | B:1907, B:35030 |
| File MIME | any string of at most 100 characters | B:35029 |
| File or image name | 1 to 255 characters | B:35021, B:35028 |
| Upload URL lifetime | 10 min | B:35019 |
| Pending upload retention | about 24 h after upload | B:111178, B:346346 |
| Redirect URIs per client | 1 to 5, at most 512 characters each | B:351753–351754 |
| Pairing code | 12 characters, 5 min, single use | B:130386–130392 |
| Authorization code | 60 s, single use, in memory | B:351751 |
| Access token | 30 days, no refresh | B:134478 |
| `clientRequestId` | at most 256 characters | B:34142 |
| `t3_thread_read` | limit at most 100, maxCharsPerItem at most 50 000, runLimit at most 50 | B:34352–34358 |
| `t3_thread_list` | limit at most 100 (default 50) | B:34302, B:344307 |
| `t3_thread_wait` | timeoutMs at most 3 600 000 (default 600 000) | B:344282–344283 |

## 12. Swift client checklist

- One `T3Endpoint` value: `origin`, `issuer`, `resource`, `environmentId`, `serverVersion`.
- `URLSessionConfiguration.ephemeral`, no cookies, no `Origin` header, `timeoutIntervalForRequest` of 60 s or more, HTTP/2.
- Pairing view: host field, code field (12 characters, uppercase, `textContentType = .oneTimeCode`), access-level picker with the ceiling explanation, Connect. It calls register, then decision, then token, all within 60 s of the decision.
- Keychain storage as in section 4.3. Re-pair when a 401 arrives or when `expiresAt` is near.
- MCP client: initialize, then `notifications/initialized`, then `tools/list`. Re-initialize on 404. Parse both JSON and SSE. Decode `structuredContent`, and fall back to `content[0].text`.
- Tool wrappers return typed results or `OrchestratorMcpFailure(code, message)`.
- Outbox state machine: Ready, Uploading, Sending, Sent(ACK), Delivery Unknown, Reconciled or Not Delivered, Failed. Never auto-retry `t3_thread_send_attachments`.
- On "Disconnect": `DELETE /mcp` for the session, remove the Keychain item, and tell the user to revoke "Drawspeak (iPad)" in Settings → Sharing & access.

## 13. Live probes (2026-11-04, read-only)

| Id | Probe | Result |
|---|---|---|
| L1 | GET the three `.well-known` documents; `POST /mcp` without a bearer | Metadata as in section 1; 401 `invalid_mcp_credential` with `www-authenticate: Bearer resource_metadata="…/.well-known/oauth-protected-resource/mcp"` |
| L2 | `POST /oauth/mcp/register` with 9 redirect variants (client `drawspeak-probe`) | Custom and reverse-DNS schemes, non-loopback http, `#`, 0 URIs and 6 URIs: 400. https, `127.0.0.1` and `localhost:port`: 201 |
| L3 | GET authorize variants | Valid: `302 /connect-agent?…`; loopback port mismatch accepted; no `resource` accepted; wrong `resource`: redirect `error=invalid_target…&iss=`; no PKCE: `error=invalid_request`; unregistered redirect: HTML 400. `client_id` decodes to `{"v":1,"n":"drawspeak-probe","r":[…]}` |
| L4 | `GET /connect-agent`; `POST /oauth/mcp/approval` without a cookie; `GET /mcp` | 200 HTML; `{"clientName":"drawspeak-probe","redirectHost":"127.0.0.1","environmentHost":"rafals-mac-mini.tail71fdd0.ts.net"}` (no csrfToken, so a pairing code is needed); 401 |
| L5 | `POST /oauth/mcp/decision` with an unknown `client_id` | 400 `{"_tag":"AuthMcpApprovalError","message":"This sign-in link names an unknown app. …"}`. No pairing code was checked. |
| L6 | `POST /oauth/mcp/token` with `grant_type=refresh_token`; with a JSON body | 400 `unsupported_grant_type`; 415 |

Not done (by design): approval, pairing, token issue, `initialize`, any tool call, upload or send.

## 14. Open items before the native MVP

1. One full Route A exchange with a real pairing code on a test machine or thread. Then `initialize` and `tools/list` to confirm the `Mcp-Session-Id` handling and the JSON or SSE framing on the device.
2. Upload, then `t3_thread_send_attachments` to an **isolated test thread**: check the ACK shape, `status` per thread state (idle, running, waiting), and the queue preview containing the marker.
3. Network drop during the send on the iPad: check that reconciliation finds the message.
4. Long-request behavior through Tailscale Serve (to choose the `t3_thread_wait` chunk size).
5. Spike for option B (section 10), or a product decision to accept option A only.
6. Repeat the code checks for each new T3 Nightly build: confirm the `serverVersion` and repeat the greps for the constants in section 11 and the lines cited here.
