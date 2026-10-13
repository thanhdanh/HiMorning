# Connect the local Qwen server

Use the working LM Studio endpoint as the first step toward replacing the movement
verifier. Start with compatibility, then a backend adapter and real exercise tests.

**Status:** Local API checked on 13 October 2026. App integration is planned.
**Audience:** Developers running HiMorning and the local inference host.

## At a glance

| Setting | Observed or proposed value |
|---|---|
| Local base URL | `http://localhost:1235/v1` |
| Served model ID | `qwen_qwen3.5-9b` |
| Quantization | API v0 reports `Q4_K_S` |
| Vision | API v1 reports vision; synthetic image answers passed |
| Integration request | `/v1/chat/completions`, strict JSON schema, `reasoning_effort: "none"` |
| Current app | OpenAI adapter remains in source; cloud checking remains off by default |

These results belong to the running local server. LM Studio/runtime versions and
GGUF/projector hashes were not recorded, so repeat compatibility checks after changes.

## How the development flow should work

```text
iOS client -> Firebase Functions Emulator -> local LM Studio -> backend decision
```

The native client should not bypass Firebase's evidence policy or hold a server
token. Running the emulator on the same Mac lets its backend reach this loopback
address. A deployed Firebase function cannot reach the Mac through `localhost`.
On a physical iPhone, `localhost` refers to the phone; connect it to the backend
emulator over the development network when that native path is implemented.
The present native source is not wired for this LM Studio flow.

## Try the working request settings

First list the models. The request must use the served ID above, not the Hugging
Face repository name:

```sh
curl --fail-with-body --silent --show-error --max-time 10 \
  http://localhost:1235/v1/models
```

A small text-only check demonstrates the tested request parameters. It does not
retest vision; see the image results below.

```sh
curl --fail-with-body --silent --show-error --max-time 15 \
  http://localhost:1235/v1/chat/completions \
  -H 'Content-Type: application/json' \
  --data-binary @- <<'JSON'
{
  "model": "qwen_qwen3.5-9b",
  "reasoning_effort": "none",
  "temperature": 0,
  "max_tokens": 128,
  "stream": false,
  "messages": [{"role": "user", "content": "Return ready=true."}],
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "readiness",
      "strict": true,
      "schema": {
        "type": "object",
        "properties": {"ready": {"type": "boolean"}},
        "required": ["ready"],
        "additionalProperties": false
      }
    }
  }
}
JSON
```

Expect JSON inside `choices[0].message.content` and `finish_reason: "stop"`.
The tested image requests also used `reasoning_effort: "none"` with JSON Schema.
A `length` finish or empty content must remain non-success. Do not increase retries
or treat the model's reasoning text as a verdict.

LM Studio documents [structured JSON](https://lmstudio.ai/docs/developer/openai-compat/structured-output)
and a native [reasoning control](https://lmstudio.ai/docs/developer/rest/chat).
Qwen documents a [template-level thinking switch](https://huggingface.co/Qwen/Qwen3.5-9B).
On this server, `chat_template_kwargs.enable_thinking=false` still produced 256
reasoning tokens and no final content; the compatible endpoint's tested
`reasoning_effort: "none"` produced zero reasoning tokens. Verify behavior rather
than assuming parameter names work across runtimes.

## What we checked

Seven local requests used only synthetic 512×256 JPEG shapes. The
[sanitized results](evaluations/lmstudio-smoke-2026-10-13.json) preserve failures,
usage, request hashes and individual timings without image data or reasoning text.

| Case | Observed result | Seconds |
|---|---|---:|
| One image, default reasoning | Output limit reached; empty final answer | 24.92 |
| Two images, default reasoning | Correct ordered answers and valid JSON | 6.95 |
| One image, template thinking flag off | Output limit reached; empty final answer | 6.24 |
| Native API, reasoning off, prompt-only JSON | Correct shape answers but a fenced array, not the requested bare object | 3.51 |
| One image, compatible API, reasoning none + schema | Correct answers and valid JSON; zero reasoning tokens | 1.89 |
| Two images, compatible API, reasoning none + schema | Correct order and valid JSON; zero reasoning tokens | 1.42 |
| Five non-human frames, existing push-up prompt/schema | `uncertain`, no reps; existing backend policy did not verify | 6.08 |

These are single observations, not latency percentiles or a controlled speed
comparison. The first request overlapped a reported model-loading state; its total
time does not separate loading from inference. Native API v0/v1 reported different
context values, so inspect the effective settings before larger batches. The
seven calls reported 2,225 input and 846 output tokens, including 699 reasoning
tokens within output: 3,071 total. This is app-model inference, separate from agent
development tokens and any paid OpenAI usage. Host operating cost was not measured.

## Next steps, in order

1. **Stabilize the local request.** Keep the served ID and tested non-thinking/schema
   settings. Load the model before testing the current 15-second provider deadline.
   Inspect idle TTL and Auto-Evict: a model can unload before the next morning.
   [LM Studio lifecycle](https://lmstudio.ai/docs/developer/core/ttl-and-auto-evict)
2. **Implement one backend adapter with TDD.** Reuse the existing `Verifier` port;
   add validated, server-owned endpoint/model/token configuration. Protect multi-image
   shape, invalid/truncated/refused output, timeout, cancellation and late results.
   Keep cloud disabled by default, strict verdict checks, one attempt and no retries.
   Keep localhost configuration limited to emulation; a deployed route needs
   authenticated HTTPS/private connectivity. No such config flags exist yet.
3. **Migrate the complete user contract.** Update EN/VI processor consent and its
   version, use provider-neutral new success outcomes, and decode historical
   `openai_verified` safely. Update shared fixtures and TypeScript/Swift consumers
   before presenting Qwen as the verifier in the app.
4. **Evaluate actual movement before enabling it.** Use consented, labeled clips
   covering correct, partial, occluded and no-person cases at 5/15/25 frames. Split
   by person; measure false acceptance/rejection, uncertainty, end-to-end waiting,
   cold starts and morning concurrency. Do not infer this from shape recognition.
5. **Rehearse the native path.** Add the development emulator connection, then test
   capture, permissions, cancellation, offline exit and sound on iPhone. Keep local
   alarms/Stop independent of inference. A safe available exit is a release gate.

Read & Choose and guided rhythm remain separate product experiments. This vision
server does not add speech recognition or precise beat scoring to the app.

## Read next

[Provider migration scope](AI-AND-CHALLENGES-PLAN.md) · [Run the app](RUNNING.md) ·
[Current stack](TECH-STACK.md) · [Product direction](PRODUCT-BRIEF.md)
