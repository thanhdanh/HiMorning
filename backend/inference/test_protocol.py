import base64
import io
import json
import unittest
from pathlib import Path
from PIL import Image
from protocol import MODEL, completion_request, parse_completion, validate_request, completion_batches, combine_verdicts


def request(target=1):
    frames = []
    for i in range(target * 5):
        image = Image.new("RGB", (32, 32), ((i * 30) % 256, i, 80))
        stream = io.BytesIO()
        image.save(stream, format="JPEG")
        frames.append({"id": f"f{i}", "timestampMs": i * 300,
                       "dataURL": "data:image/jpeg;base64," + base64.b64encode(stream.getvalue()).decode()})
    return {"model": MODEL, "target": target, "deadlineAt": 181000, "frames": frames}


class ProtocolTests(unittest.TestCase):
    def test_ordered_images_and_strict_non_thinking_completion(self):
        data = validate_request(request(), now_ms=1000)
        payload = completion_request(data)
        self.assertEqual(payload["max_tokens"], 4096)
        self.assertEqual(payload["reasoning_effort"], "none")
        self.assertFalse(payload["cache_prompt"])
        self.assertTrue(payload["response_format"]["json_schema"]["strict"])
        content = payload["messages"][1]["content"]
        self.assertEqual([x["image_url"]["url"] for x in content if x["type"] == "image_url"], [x["dataURL"] for x in data["frames"]])
        self.assertIn("Frame f4, t=1200ms", [x["text"] for x in content if x["type"] == "text"])

    def test_supports_fifty_cycles_with_bounded_output(self):
        for target in (5, 10, 20, 50):
            self.assertEqual(len(validate_request(request(target), now_ms=1000)["frames"]), target * 5)

    def test_rejects_surplus_frames_before_inference_dispatch(self):
        data = request(2)
        data["target"] = 1
        with self.assertRaises(ValueError):
            validate_request(data, now_ms=1000)
        with self.assertRaises(ValueError):
            completion_batches(data)

    def test_batches_fifty_cycles_without_cross_batch_or_partial_success(self):
        with self.assertRaises(ValueError):
            completion_request(request(50))
        batches = completion_batches(validate_request(request(50), now_ms=1000))
        self.assertEqual(len(batches), 10)
        self.assertTrue(all(batch["target"] == 5 and len(batch["frames"]) == 25 for batch in batches))
        self.assertEqual([f["id"] for b in batches for f in b["frames"]], [f"f{i}" for i in range(250)])
        def verdict(batch):
            return {"status": "complete", "cue": "none", "reps": [
                {"frameIDs": [f["id"] for f in batch["frames"][i:i+5]]} for i in range(0, len(batch["frames"]), 5)]}
        verdicts = [verdict(batch) for batch in batches]
        self.assertEqual(len(combine_verdicts(batches, verdicts)["reps"]), 50)
        self.assertEqual(combine_verdicts(batches, verdicts)["status"], "complete")
        self.assertEqual(combine_verdicts(batches, verdicts[:-1])["status"], "uncertain")
        verdicts[-1] = verdict(batches[0])
        self.assertEqual(combine_verdicts(batches, verdicts)["status"], "uncertain")
        verdicts[-1] = {"status": "uncertain", "reps": [], "cue": "none"}
        self.assertEqual(combine_verdicts(batches, verdicts)["status"], "uncertain")
        verdicts[-1] = {"status": "complete", "reps": [], "cue": "none"}
        self.assertEqual(combine_verdicts(batches, verdicts)["status"], "incomplete")
        self.assertEqual([b["target"] for b in completion_batches(request(7))], [5, 2])

    def test_rejects_invalid_images_order_counts_targets_and_deadlines(self):
        mutations = [
            lambda d: d.update(target=True), lambda d: d.update(target=51),
            lambda d: d.update(model="arbitrary-download"), lambda d: d.update(extra=True),
            lambda d: d.update(deadlineAt=1000), lambda d: d.update(deadlineAt=181001),
            lambda d: d["frames"].pop(), lambda d: d["frames"][1].update(id="f0"),
            lambda d: d["frames"][1].update(timestampMs=0), lambda d: d["frames"][0].update(timestampMs=-1),
            lambda d: d["frames"][0].update(dataURL="https://attacker.test/image"),
            lambda d: d["frames"][0].update(dataURL="data:image/jpeg;base64," + "x" * 70000),
            lambda d: d["frames"][1].update(dataURL=d["frames"][0]["dataURL"]),
            lambda d: d["frames"][0].update(dataURL="data:image/jpeg;base64,eA=="),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                data = request()
                mutate(data)
                with self.assertRaises((ValueError, OSError)):
                    validate_request(data, now_ms=1000)

    def test_never_parses_reasoning_fences_truncation_or_refusal_as_success(self):
        verdict = {"status": "complete", "reps": [{"frameIDs": [f"f{i}" for i in range(5)]}], "cue": "none"}
        response = {"choices": [{"finish_reason": "stop", "message": {"content": json.dumps(verdict)}}]}
        self.assertEqual(parse_completion(response), verdict)
        for malformed in [{}, {"choices": []}, {"choices": [{"finish_reason": "length", "message": {"content": json.dumps(verdict)}}]},
                          {"choices": [{"finish_reason": "stop", "message": {"content": "```json\n{}\n```"}}]},
                          {"choices": [{"finish_reason": "stop", "message": {"content": json.dumps(verdict), "refusal": "no"}}]}]:
            self.assertEqual(parse_completion(malformed), {"status": "uncertain", "reps": [], "cue": "none"})

    def test_artifact_pins_are_immutable_and_generated_schema_bounds_cycles(self):
        pins = json.loads(Path(__file__).with_name("pins.json").read_text())
        self.assertRegex(pins["runtimeImage"], r"@sha256:[a-f0-9]{64}$")
        self.assertRegex(pins["revision"], r"^[a-f0-9]{40}$")
        for kind in ("model", "projector"):
            self.assertRegex(pins[kind]["sha256"], r"^[a-f0-9]{64}$")
        schema = completion_request(request())["response_format"]["json_schema"]["schema"]
        self.assertFalse(schema["additionalProperties"])
        self.assertEqual(schema["properties"]["reps"]["maxItems"], 1)
        exported = json.loads(Path(__file__).with_name("verdict.schema.json").read_text())
        self.assertEqual(exported["properties"]["reps"]["maxItems"], 50)
        self.assertEqual(schema["properties"]["reps"]["items"]["properties"]["frameIDs"]["minItems"], 5)


class SmokeFixtureTests(unittest.TestCase):
    def test_remote_smoke_only_generates_bounded_non_person_images(self):
        from smoke import synthetic_request
        for count in (5, 15, 25, 50, 100, 250):
            data = synthetic_request(count)
            self.assertEqual(len(validate_request(data)["frames"]), count)
        with self.assertRaises(ValueError):
            synthetic_request(26)


if __name__ == "__main__":
    unittest.main()
