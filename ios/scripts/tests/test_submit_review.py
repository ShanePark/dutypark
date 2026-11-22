"""Offline tests for ios/scripts/submit-review.py.

Run from the repository root:
  python3 -m unittest discover -s ios/scripts/tests -v

No test touches the network or a real App Store Connect key.
"""

import base64
import importlib.util
import io
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

SCRIPT_PATH = Path(__file__).resolve().parents[1] / "submit-review.py"
_spec = importlib.util.spec_from_file_location("submit_review", SCRIPT_PATH)
sr = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = sr  # dataclasses resolves annotations through sys.modules
_spec.loader.exec_module(sr)


def b64url_decode(text):
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def der_integer(value):
    body = value.lstrip(b"\x00") or b"\x00"
    if body[0] & 0x80:
        body = b"\x00" + body
    return b"\x02" + bytes([len(body)]) + body


def raw_to_der(raw):
    body = der_integer(raw[:32]) + der_integer(raw[32:])
    return b"\x30" + bytes([len(body)]) + body


class SignatureConversionTests(unittest.TestCase):
    def test_full_width_integers(self):
        r = bytes(range(1, 33))
        s = bytes(range(33, 65))
        der = b"\x30\x44" + b"\x02\x20" + r + b"\x02\x20" + s
        self.assertEqual(sr.der_to_raw_signature(der), r + s)

    def test_leading_zero_padding_is_stripped(self):
        r = b"\x80" + bytes(31)
        s = b"\xff" * 32
        der = b"\x30\x46" + b"\x02\x21\x00" + r + b"\x02\x21\x00" + s
        self.assertEqual(sr.der_to_raw_signature(der), r + s)

    def test_short_integers_are_left_padded(self):
        r = b"\x01\x02"
        s = b"\x7f" * 30
        der = b"\x30\x24" + b"\x02\x02" + r + b"\x02\x1e" + s
        raw = sr.der_to_raw_signature(der)
        self.assertEqual(len(raw), 64)
        self.assertEqual(raw[:32], bytes(30) + r)
        self.assertEqual(raw[32:], bytes(2) + s)

    def test_rejects_malformed_der(self):
        with self.assertRaises(ValueError):
            sr.der_to_raw_signature(b"\x31\x00")
        with self.assertRaises(ValueError):
            sr.der_to_raw_signature(b"\x30\x06\x02\x01\x01\x02\x05\x01")


@unittest.skipUnless(shutil.which("openssl"), "openssl is required")
class JwtTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        tmp = Path(self.tmp.name)
        self.ec_key = tmp / "ec.pem"
        self.key_path = tmp / "AuthKey_TESTKEY123.p8"
        self.pub_path = tmp / "pub.pem"
        subprocess.run(
            ["openssl", "ecparam", "-genkey", "-name", "prime256v1", "-noout", "-out", str(self.ec_key)],
            check=True, capture_output=True,
        )
        subprocess.run(
            ["openssl", "pkcs8", "-topk8", "-nocrypt", "-in", str(self.ec_key), "-out", str(self.key_path)],
            check=True, capture_output=True,
        )
        subprocess.run(
            ["openssl", "ec", "-in", str(self.ec_key), "-pubout", "-out", str(self.pub_path)],
            check=True, capture_output=True,
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_header_claims_and_signature(self):
        token = sr.make_jwt("TESTKEY123", "issuer-uuid", str(self.key_path), now=1_700_000_000)
        header_b64, claims_b64, sig_b64 = token.split(".")
        header = json.loads(b64url_decode(header_b64))
        claims = json.loads(b64url_decode(claims_b64))
        self.assertEqual(header, {"alg": "ES256", "kid": "TESTKEY123", "typ": "JWT"})
        self.assertEqual(claims["iss"], "issuer-uuid")
        self.assertEqual(claims["aud"], "appstoreconnect-v1")
        self.assertEqual(claims["iat"], 1_700_000_000)
        self.assertGreater(claims["exp"], claims["iat"])
        self.assertLessEqual(claims["exp"] - claims["iat"], 20 * 60)

        raw = b64url_decode(sig_b64)
        self.assertEqual(len(raw), 64)
        sig_path = Path(self.tmp.name) / "sig.der"
        sig_path.write_bytes(raw_to_der(raw))
        verify = subprocess.run(
            ["openssl", "dgst", "-sha256", "-verify", str(self.pub_path), "-signature", str(sig_path)],
            input=f"{header_b64}.{claims_b64}".encode(), capture_output=True,
        )
        self.assertEqual(verify.returncode, 0, verify.stdout + verify.stderr)

    def test_token_provider_regenerates_before_expiry(self):
        now = [1_700_000_000.0]
        provider = sr.TokenProvider("TESTKEY123", "issuer-uuid", str(self.key_path), clock=lambda: now[0])
        first = provider()
        now[0] += 60
        self.assertEqual(provider(), first)
        now[0] += 15 * 60
        second = provider()
        self.assertNotEqual(second, first)
        claims = json.loads(b64url_decode(second.split(".")[1]))
        self.assertEqual(claims["iat"], int(now[0]))


class ConfigTests(unittest.TestCase):
    def test_reads_marketing_version_from_xcconfig(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Version.xcconfig"
            path.write_text("// comment MARKETING_VERSION = 9.9.9\nMARKETING_VERSION = 1.3.1\n")
            self.assertEqual(sr.read_marketing_version(path), "1.3.1")

    def test_reads_repository_xcconfig(self):
        version = sr.read_marketing_version(sr.VERSION_CONFIG_PATH)
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")

    def test_missing_marketing_version_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Version.xcconfig"
            path.write_text("OTHER = 1\n")
            with self.assertRaises(sr.ReleaseError):
                sr.read_marketing_version(path)

    def test_default_build_number_uses_kst_date(self):
        # 2026-11-21 16:30 UTC is already 2026-11-22 in Asia/Seoul.
        now = datetime(2026, 11, 21, 16, 30, tzinfo=timezone.utc)
        self.assertEqual(sr.default_build_number(now), "20261122")


class ReviewNotesTests(unittest.TestCase):
    def test_replaces_leading_version_sentence_with_summary(self):
        notes = "Version 1.3.0 adds ribbons (v1.2.9 had none). Seeded data is in August.\n\nVersion 1.3.0 again."
        self.assertEqual(
            sr.replace_review_notes_intro(notes, "1.3.1", "restores ribbon tags."),
            "Version 1.3.1 restores ribbon tags. Seeded data is in August.\n\nVersion 1.3.0 again.",
        )

    def test_replaces_sentence_ending_at_line_end(self):
        notes = "  Version 1.2 fixes sync.\nDemo account below."
        self.assertEqual(sr.replace_review_notes_intro(notes, "1.3.1", "adds tags."),
                         "  Version 1.3.1 adds tags.\nDemo account below.")

    def test_replaces_whole_notes_when_sentence_has_no_period(self):
        self.assertEqual(sr.replace_review_notes_intro("Version 1.2 fix", "1.3.1", "adds tags."),
                         "Version 1.3.1 adds tags.")

    def test_returns_none_without_prefix(self):
        self.assertIsNone(sr.replace_review_notes_intro("Demo account: none", "1.3.1", "adds tags."))
        self.assertIsNone(sr.replace_review_notes_intro("", "1.3.1", "adds tags."))
        self.assertIsNone(sr.replace_review_notes_intro(None, "1.3.1", "adds tags."))
        self.assertIsNone(sr.replace_review_notes_intro("Versioning 1.2.3", "1.3.1", "adds tags."))

    def test_read_review_summary_requires_text_and_final_period(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "summary.txt"
            path.write_text("  restores ribbon tags.\n", encoding="utf-8")
            self.assertEqual(sr.read_review_summary(str(path)), "restores ribbon tags.")
            path.write_text("restores ribbon tags", encoding="utf-8")
            with self.assertRaises(sr.ReleaseError):
                sr.read_review_summary(str(path))
            path.write_text("Version 1.3.1 restores ribbon tags.", encoding="utf-8")
            with self.assertRaises(sr.ReleaseError):
                sr.read_review_summary(str(path))
            path.write_text("", encoding="utf-8")
            with self.assertRaises(sr.ReleaseError):
                sr.read_review_summary(str(path))


def loc(loc_id, locale):
    return {"type": "appStoreVersionLocalizations", "id": loc_id, "attributes": {"locale": locale}}


class LocaleMatchingTests(unittest.TestCase):
    def test_matches_exact_preferred_locale(self):
        locs = [loc("1", "en-GB"), loc("2", "en-US"), loc("3", "ko")]
        self.assertEqual(sr.match_locale(locs, "en", "en-US")["id"], "2")
        self.assertEqual(sr.match_locale(locs, "ko", "ko")["id"], "3")

    def test_matches_unique_prefix(self):
        locs = [loc("1", "ko-KR"), loc("2", "en-AU")]
        self.assertEqual(sr.match_locale(locs, "ko", "ko")["id"], "1")
        self.assertEqual(sr.match_locale(locs, "en", "en-US")["id"], "2")

    def test_prefix_does_not_match_other_languages(self):
        with self.assertRaises(sr.ReleaseError):
            sr.match_locale([loc("1", "kok")], "ko", "ko")

    def test_missing_locale_fails(self):
        with self.assertRaises(sr.ReleaseError):
            sr.match_locale([loc("1", "ja")], "en", "en-US")

    def test_ambiguous_prefix_fails(self):
        with self.assertRaises(sr.ReleaseError):
            sr.match_locale([loc("1", "en-GB"), loc("2", "en-AU")], "en", "en-US")


def version(version_id, version_string, state):
    return {
        "type": "appStoreVersions",
        "id": version_id,
        "attributes": {"versionString": version_string, "platform": "IOS", "appVersionState": state},
    }


class VersionSelectionTests(unittest.TestCase):
    def test_reuses_editable_version(self):
        plan = sr.choose_version([version("a", "1.3.0", "READY_FOR_DISTRIBUTION"), version("b", "1.3.1", "PREPARE_FOR_SUBMISSION")], "1.3.1")
        self.assertEqual((plan.action, plan.version["id"], plan.needs_version_patch), ("reuse", "b", False))

    def test_reuses_rejected_version_and_requests_version_patch(self):
        plan = sr.choose_version([version("a", "1.3.0", "REJECTED")], "1.3.1")
        self.assertEqual((plan.action, plan.version["id"], plan.needs_version_patch), ("reuse", "a", True))

    def test_falls_back_to_deprecated_app_store_state(self):
        legacy = {"id": "a", "attributes": {"versionString": "1.3.1", "appStoreState": "DEVELOPER_REJECTED"}}
        self.assertEqual(sr.choose_version([legacy], "1.3.1").action, "reuse")

    def test_pending_review_version(self):
        plan = sr.choose_version([version("a", "1.3.0", "WAITING_FOR_REVIEW")], "1.3.1")
        self.assertEqual((plan.action, plan.version["id"]), ("pending", "a"))
        self.assertEqual(sr.choose_version([version("a", "1.3.0", "IN_REVIEW")], "1.3.1").action, "pending")

    def test_creates_when_previous_is_released_or_pending_release(self):
        for state in ("READY_FOR_DISTRIBUTION", "PENDING_DEVELOPER_RELEASE"):
            plan = sr.choose_version([version("a", "1.3.0", state)], "1.3.1")
            self.assertEqual((plan.action, plan.version), ("create", None))
        self.assertEqual(sr.choose_version([], "1.3.1").action, "create")


class FakeAsc:
    """In-memory App Store Connect stand-in behind the injected HTTP transport."""

    def __init__(self):
        self.calls = []
        self.app = {"type": "apps", "id": "app1", "attributes": {"bundleId": sr.DEFAULT_BUNDLE_ID}}
        self.build_responses = [[{"id": "build1", "attributes": {"version": "20261122", "processingState": "VALID", "usesNonExemptEncryption": False}}]]
        self.versions = {"v130": self._version("v130", "1.3.0", "READY_FOR_DISTRIBUTION")}
        self.localizations = {}
        self.review_details = {}
        self.submissions = {}
        self.items = []
        self.attached_builds = {}
        self.cancel_makes_state = "DEVELOPER_REJECTED"
        self.create_error = None
        self.counter = 0

    def _version(self, vid, version_string, state):
        return {"type": "appStoreVersions", "id": vid, "attributes": {"versionString": version_string, "platform": "IOS", "appVersionState": state}}

    def add_version(self, vid, version_string, state, notes="Version 1.3.0 test notes."):
        self.versions[vid] = self._version(vid, version_string, state)
        self.localizations[vid] = [
            {"type": "appStoreVersionLocalizations", "id": f"{vid}-ko", "attributes": {"locale": "ko", "whatsNew": "old ko"}},
            {"type": "appStoreVersionLocalizations", "id": f"{vid}-en", "attributes": {"locale": "en-US", "whatsNew": "old en"}},
        ]
        self.review_details[vid] = {"type": "appStoreReviewDetails", "id": f"{vid}-rd", "attributes": {"notes": notes}}

    def add_submission(self, sid, state, version_id=None):
        rel = {"data": {"type": "appStoreVersions", "id": version_id} if version_id else None}
        self.submissions[sid] = {
            "type": "reviewSubmissions", "id": sid,
            "attributes": {"platform": "IOS", "state": state},
            "relationships": {"appStoreVersionForReview": rel},
        }

    def write_calls(self):
        return [(m, p) for (m, p, _q, _b) in self.calls if m != "GET"]

    def __call__(self, method, url, headers, body):
        parts = urlsplit(url)
        path = parts.path
        query = {k: v[0] for k, v in parse_qs(parts.query).items()}
        payload = json.loads(body) if body else None
        self.calls.append((method, path, query, payload))
        assert headers["Authorization"] == "Bearer test-token"
        status, doc = self.route(method, path.split("/")[1:], query, payload)
        return status, (json.dumps(doc).encode() if doc is not None else b"")

    def route(self, method, seg, q, payload):
        if seg[0] != "v1":
            return 404, None
        seg = seg[1:]
        if method == "GET" and seg == ["apps"]:
            assert q["filter[bundleId]"] == sr.DEFAULT_BUNDLE_ID
            return 200, {"data": [self.app], "links": {}}
        if method == "GET" and seg == ["builds"]:
            assert q["filter[app]"] == "app1"
            data = self.build_responses.pop(0) if len(self.build_responses) > 1 else self.build_responses[0]
            return 200, {"data": data, "links": {}}
        if method == "GET" and seg == ["apps", "app1", "appStoreVersions"]:
            assert q["filter[platform]"] == "IOS"
            return 200, {"data": list(self.versions.values()), "links": {}}
        if seg[:1] == ["appStoreVersions"] and len(seg) == 2:
            v = self.versions[seg[1]]
            if method == "GET":
                return 200, {"data": v}
            if method == "PATCH":
                v["attributes"].update(payload["data"]["attributes"])
                return 200, {"data": v}
        if method == "POST" and seg == ["appStoreVersions"]:
            if self.create_error:
                return 409, {"errors": [{"status": "409", "code": "ENTITY_ERROR", "title": "Create refused", "detail": self.create_error}]}
            attrs = payload["data"]["attributes"]
            assert payload["data"]["relationships"]["app"]["data"] == {"type": "apps", "id": "app1"}
            self.add_version("new", attrs["versionString"], "PREPARE_FOR_SUBMISSION")
            return 201, {"data": self.versions["new"]}
        if method == "GET" and len(seg) == 3 and seg[0] == "appStoreVersions" and seg[2] == "appStoreVersionLocalizations":
            return 200, {"data": self.localizations[seg[1]], "links": {}}
        if method == "PATCH" and seg[0] == "appStoreVersionLocalizations":
            for locs in self.localizations.values():
                for item in locs:
                    if item["id"] == seg[1]:
                        item["attributes"].update(payload["data"]["attributes"])
                        return 200, {"data": item}
        if method == "GET" and len(seg) == 3 and seg[2] == "appStoreReviewDetail":
            return 200, {"data": self.review_details.get(seg[1])}
        if method == "PATCH" and seg[0] == "appStoreReviewDetails":
            for detail in self.review_details.values():
                if detail["id"] == seg[1]:
                    detail["attributes"].update(payload["data"]["attributes"])
                    return 200, {"data": detail}
        if method == "PATCH" and len(seg) == 4 and seg[2:] == ["relationships", "build"]:
            self.attached_builds[seg[1]] = payload["data"]["id"]
            return 204, None
        if method == "GET" and seg == ["reviewSubmissions"]:
            assert q["filter[app]"] == "app1"
            states = q.get("filter[state]", "").split(",")
            data = [s for s in self.submissions.values() if s["attributes"]["state"] in states]
            return 200, {"data": data, "links": {}}
        if method == "POST" and seg == ["reviewSubmissions"]:
            self.counter += 1
            sid = f"sub{self.counter}"
            self.add_submission(sid, "READY_FOR_REVIEW")
            return 201, {"data": self.submissions[sid]}
        if method == "POST" and seg == ["reviewSubmissionItems"]:
            rels = payload["data"]["relationships"]
            self.items.append((rels["reviewSubmission"]["data"]["id"], rels["appStoreVersion"]["data"]["id"]))
            return 201, {"data": {"type": "reviewSubmissionItems", "id": "item1"}}
        if method == "PATCH" and seg[0] == "reviewSubmissions":
            sub = self.submissions[seg[1]]
            attrs = payload["data"]["attributes"]
            if attrs.get("canceled"):
                sub["attributes"]["state"] = "CANCELING"
                vid = sub["relationships"]["appStoreVersionForReview"]["data"]["id"]
                self.versions[vid]["attributes"]["appVersionState"] = self.cancel_makes_state
            if attrs.get("submitted"):
                sub["attributes"]["state"] = "WAITING_FOR_REVIEW"
                for (s_id, vid) in self.items:
                    if s_id == sub["id"]:
                        self.versions[vid]["attributes"]["appVersionState"] = "WAITING_FOR_REVIEW"
            return 200, {"data": sub}
        return 404, {"errors": [{"status": "404", "title": "Not found", "detail": f"{method} /{'/'.join(seg)}"}]}


class Clock:
    def __init__(self):
        self.now = 0.0
        self.sleeps = []

    def monotonic(self):
        return self.now

    def sleep(self, seconds):
        self.sleeps.append(seconds)
        self.now += seconds


def make_release(fake, dry_run=False, confirm=None, **config):
    clock = Clock()
    cfg = sr.ReleaseConfig(
        version=config.get("version", "1.3.1"),
        build_number=config.get("build_number", "20261122"),
        bundle_id=sr.DEFAULT_BUNDLE_ID,
        whats_new={"ko": "새 기능", "en": "New features"},
        review_summary=config.get("review_summary", "restores ribbon tags."),
        dry_run=dry_run,
        poll_interval=30,
        build_timeout=60 * 60,
        state_timeout=10 * 60,
    )
    api = sr.ApiClient(token=lambda: "test-token", transport=fake)
    out = io.StringIO()
    release = sr.Release(api, cfg, out=out, confirm=confirm or (lambda _q: False), sleep=clock.sleep, monotonic=clock.monotonic)
    return release, out, clock


class ApiClientTests(unittest.TestCase):
    def test_follows_pagination_and_keeps_included(self):
        calls = []

        def transport(method, url, headers, body):
            calls.append(url)
            if "cursor" not in url:
                return 200, json.dumps({"data": [{"id": "1"}], "included": [{"id": "i1"}], "links": {"next": sr.API_BASE + "/v1/things?cursor=abc"}}).encode()
            return 200, json.dumps({"data": [{"id": "2"}], "links": {}}).encode()

        api = sr.ApiClient(token=lambda: "t", transport=transport)
        data, included = api.get_all("/v1/things", {"limit": 200})
        self.assertEqual([d["id"] for d in data], ["1", "2"])
        self.assertEqual(included, [{"id": "i1"}])
        self.assertEqual(calls[0], sr.API_BASE + "/v1/things?limit=200")
        self.assertEqual(calls[1], sr.API_BASE + "/v1/things?cursor=abc")

    def test_non_2xx_raises_with_error_details(self):
        def transport(method, url, headers, body):
            return 409, json.dumps({"errors": [{"code": "ENTITY_ERROR", "title": "Bad thing", "detail": "Because reasons"}]}).encode()

        api = sr.ApiClient(token=lambda: "t", transport=transport)
        with self.assertRaises(sr.AscError) as ctx:
            api.post("/v1/appStoreVersions", {"data": {}})
        message = str(ctx.exception)
        self.assertIn("409", message)
        self.assertIn("Bad thing", message)
        self.assertIn("Because reasons", message)
        self.assertEqual(ctx.exception.status, 409)

    def test_sends_json_body_and_auth(self):
        seen = {}

        def transport(method, url, headers, body):
            seen.update(method=method, headers=headers, body=json.loads(body))
            return 204, b""

        api = sr.ApiClient(token=lambda: "t", transport=transport)
        self.assertIsNone(api.patch("/v1/x", {"data": {"id": "1"}}))
        self.assertEqual(seen["method"], "PATCH")
        self.assertEqual(seen["headers"]["Authorization"], "Bearer t")
        self.assertEqual(seen["headers"]["Content-Type"], "application/json")
        self.assertEqual(seen["body"], {"data": {"id": "1"}})


class WaitForBuildTests(unittest.TestCase):
    def test_waits_until_valid(self):
        fake = FakeAsc()
        fake.build_responses = [
            [],
            [{"id": "build1", "attributes": {"version": "20261122", "processingState": "PROCESSING", "usesNonExemptEncryption": None}}],
            [{"id": "build1", "attributes": {"version": "20261122", "processingState": "VALID", "usesNonExemptEncryption": False}}],
        ]
        release, out, clock = make_release(fake)
        build = release.wait_for_build("app1")
        self.assertEqual(build["id"], "build1")
        self.assertEqual(clock.sleeps, [30, 30])
        build_calls = [q for (m, p, q, _b) in fake.calls if p == "/v1/builds"]
        self.assertEqual(build_calls[0]["filter[version]"], "20261122")
        self.assertEqual(build_calls[0]["filter[preReleaseVersion.version]"], "1.3.1")
        self.assertIn("PROCESSING", out.getvalue())

    def test_invalid_build_fails(self):
        for state in ("INVALID", "FAILED"):
            fake = FakeAsc()
            fake.build_responses = [[{"id": "build1", "attributes": {"version": "20261122", "processingState": state}}]]
            release, _out, _clock = make_release(fake)
            with self.assertRaisesRegex(sr.ReleaseError, state):
                release.wait_for_build("app1")

    def test_times_out(self):
        fake = FakeAsc()
        fake.build_responses = [[]]
        release, _out, clock = make_release(fake)
        with self.assertRaisesRegex(sr.ReleaseError, "Timed out"):
            release.wait_for_build("app1")
        self.assertGreaterEqual(clock.now, 60 * 60)

    def test_reports_missing_encryption_declaration(self):
        fake = FakeAsc()
        fake.build_responses = [[{"id": "build1", "attributes": {"version": "20261122", "processingState": "VALID", "usesNonExemptEncryption": None}}]]
        release, out, _clock = make_release(fake)
        release.wait_for_build("app1")
        self.assertIn("usesNonExemptEncryption", out.getvalue())


class SubmissionFlowTests(unittest.TestCase):
    def test_creates_version_and_submits_in_order(self):
        fake = FakeAsc()
        release, out, _clock = make_release(fake)
        release.run()
        self.assertEqual(fake.write_calls(), [
            ("POST", "/v1/appStoreVersions"),
            ("PATCH", "/v1/appStoreVersionLocalizations/new-ko"),
            ("PATCH", "/v1/appStoreVersionLocalizations/new-en"),
            ("PATCH", "/v1/appStoreReviewDetails/new-rd"),
            ("PATCH", "/v1/appStoreVersions/new/relationships/build"),
            ("POST", "/v1/reviewSubmissions"),
            ("POST", "/v1/reviewSubmissionItems"),
            ("PATCH", "/v1/reviewSubmissions/sub1"),
        ])
        locs = {l["attributes"]["locale"]: l["attributes"]["whatsNew"] for l in fake.localizations["new"]}
        self.assertEqual(locs, {"ko": "새 기능", "en-US": "New features"})
        self.assertEqual(fake.review_details["new"]["attributes"]["notes"], "Version 1.3.1 restores ribbon tags.")
        self.assertEqual(fake.attached_builds, {"new": "build1"})
        self.assertEqual(fake.items, [("sub1", "new")])
        submitted = [b for (m, p, _q, b) in fake.calls if p == "/v1/reviewSubmissions/sub1"][0]
        self.assertEqual(submitted["data"]["attributes"], {"submitted": True})
        create = [b for (m, p, _q, b) in fake.calls if (m, p) == ("POST", "/v1/appStoreVersions")][0]
        self.assertEqual(create["data"]["attributes"], {"platform": "IOS", "versionString": "1.3.1"})
        summary = out.getvalue()
        self.assertIn("1.3.1", summary)
        self.assertIn("20261122", summary)
        self.assertIn("sub1", summary)
        self.assertIn("WAITING_FOR_REVIEW", summary)

    def test_reuses_editable_version_patches_version_string_and_open_submission(self):
        fake = FakeAsc()
        fake.add_version("v131", "1.3.0", "PREPARE_FOR_SUBMISSION")
        fake.add_submission("draft", "READY_FOR_REVIEW")
        release, _out, _clock = make_release(fake)
        release.run()
        self.assertEqual(fake.write_calls()[0], ("PATCH", "/v1/appStoreVersions/v131"))
        self.assertEqual(fake.versions["v131"]["attributes"]["versionString"], "1.3.1")
        self.assertNotIn(("POST", "/v1/reviewSubmissions"), fake.write_calls())
        self.assertEqual(fake.items, [("draft", "v131")])
        self.assertEqual(fake.write_calls()[-1], ("PATCH", "/v1/reviewSubmissions/draft"))

    def test_skips_item_when_open_submission_already_has_version(self):
        fake = FakeAsc()
        fake.add_version("v131", "1.3.1", "REJECTED")
        fake.add_submission("unresolved", "UNRESOLVED_ISSUES", "v131")
        release, _out, _clock = make_release(fake)
        release.run()
        self.assertNotIn(("POST", "/v1/reviewSubmissionItems"), fake.write_calls())
        self.assertNotIn(("PATCH", "/v1/appStoreVersions/v131"), fake.write_calls())
        self.assertEqual(fake.write_calls()[-1], ("PATCH", "/v1/reviewSubmissions/unresolved"))

    def test_leaves_notes_without_version_prefix(self):
        fake = FakeAsc()
        fake.add_version("v131", "1.3.1", "PREPARE_FOR_SUBMISSION", notes="Demo account not needed.")
        release, out, _clock = make_release(fake)
        release.run()
        self.assertNotIn(("PATCH", "/v1/appStoreReviewDetails/v131-rd"), fake.write_calls())
        self.assertEqual(fake.review_details["v131"]["attributes"]["notes"], "Demo account not needed.")
        self.assertIn("warning", out.getvalue().lower())

    def test_pending_review_replaced_when_confirmed(self):
        fake = FakeAsc()
        fake.add_version("v130b", "1.3.0", "WAITING_FOR_REVIEW")
        fake.add_submission("active", "WAITING_FOR_REVIEW", "v130b")
        questions = []
        release, _out, _clock = make_release(fake, confirm=lambda q: questions.append(q) or True)
        release.run()
        self.assertEqual(questions, ["1.3.0 is WAITING_FOR_REVIEW. Remove it from review and replace it with 1.3.1 build 20261122? [y/N] "])
        writes = fake.write_calls()
        self.assertEqual(writes[0], ("PATCH", "/v1/reviewSubmissions/active"))
        cancel = [b for (m, p, _q, b) in fake.calls if (m, p) == ("PATCH", "/v1/reviewSubmissions/active")][0]
        self.assertEqual(cancel["data"]["attributes"], {"canceled": True})
        self.assertEqual(writes[1], ("PATCH", "/v1/appStoreVersions/v130b"))
        self.assertEqual(fake.versions["v130b"]["attributes"]["versionString"], "1.3.1")
        self.assertEqual(fake.attached_builds, {"v130b": "build1"})

    def test_pending_review_declined_aborts_without_writes(self):
        fake = FakeAsc()
        fake.add_version("v130b", "1.3.0", "IN_REVIEW")
        fake.add_submission("active", "IN_REVIEW", "v130b")
        release, _out, _clock = make_release(fake, confirm=lambda _q: False)
        with self.assertRaisesRegex(sr.ReleaseError, "Aborted"):
            release.run()
        self.assertEqual(fake.write_calls(), [])

    def test_cancel_waits_for_editable_state(self):
        fake = FakeAsc()
        fake.add_version("v130b", "1.3.0", "WAITING_FOR_REVIEW")
        fake.add_submission("active", "WAITING_FOR_REVIEW", "v130b")
        fake.cancel_makes_state = "WAITING_FOR_REVIEW"
        release, _out, clock = make_release(fake, confirm=lambda _q: True)
        with self.assertRaisesRegex(sr.ReleaseError, "Timed out"):
            release.run()
        self.assertGreaterEqual(clock.now, 10 * 60)

    def test_create_refusal_surfaces_error(self):
        fake = FakeAsc()
        fake.create_error = "You cannot create a new version of the App in the current state."
        release, _out, _clock = make_release(fake)
        with self.assertRaisesRegex(sr.AscError, "cannot create a new version"):
            release.run()

    def test_dry_run_makes_no_write_calls(self):
        for setup in ("create", "reuse", "pending"):
            fake = FakeAsc()
            if setup == "reuse":
                fake.add_version("v131", "1.3.0", "PREPARE_FOR_SUBMISSION")
            if setup == "pending":
                fake.add_version("v130b", "1.3.0", "WAITING_FOR_REVIEW")
                fake.add_submission("active", "WAITING_FOR_REVIEW", "v130b")
            fake.build_responses = [[]]
            release, out, clock = make_release(fake, dry_run=True, confirm=lambda _q: self.fail("dry run must not prompt"))
            release.run()
            self.assertEqual(fake.write_calls(), [], setup)
            self.assertEqual(clock.sleeps, [], setup)
            self.assertIn("dry-run", out.getvalue())


class UploadTests(unittest.TestCase):
    def test_upload_command_and_key_dir(self):
        runs = []

        def runner(cmd, env):
            runs.append((cmd, env))

        sr.upload_build("/x/Dutypark.ipa", "KEY", "ISS", "/keys/AuthKey_KEY.p8", runner=runner, env={"PATH": "/bin"}, out=io.StringIO())
        cmd, env = runs[0]
        self.assertEqual(cmd, ["xcrun", "altool", "--upload-app", "-f", "/x/Dutypark.ipa", "-t", "ios", "--apiKey", "KEY", "--apiIssuer", "ISS"])
        self.assertEqual(env["API_PRIVATE_KEYS_DIR"], "/keys")

    def test_default_key_dir_needs_no_override(self):
        runs = []
        default = str(sr.DEFAULT_KEY_DIR / "AuthKey_KEY.p8")
        sr.upload_build("/x/Dutypark.ipa", "KEY", "ISS", default, runner=lambda c, e: runs.append(e), env={}, out=io.StringIO())
        self.assertNotIn("API_PRIVATE_KEYS_DIR", runs[0])

    def test_dry_run_does_not_run(self):
        out = io.StringIO()
        sr.upload_build("/x/Dutypark.ipa", "KEY", "ISS", "/k/AuthKey_KEY.p8", runner=lambda c, e: self.fail("ran"), env={}, out=out, dry_run=True)
        self.assertIn("altool", out.getvalue())


if __name__ == "__main__":
    unittest.main()
