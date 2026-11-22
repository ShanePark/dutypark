#!/usr/bin/env python3
"""Upload a Dutypark iOS build and submit it for App Review.

Run from the repository root after exporting an .ipa (see ios/README.md):
  ASC_KEY_ID=... ASC_ISSUER_ID=... python3 ios/scripts/submit-review.py \
    --whats-new-ko ko.txt --whats-new-en en.txt

Steps: upload with altool, wait for App Store Connect processing, prepare the
App Store version (What's New, review notes, build), then submit it through
the reviewSubmissions API. --dry-run performs read requests only.
Standard library only; ES256 signing shells out to openssl.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable, NamedTuple, Optional
from urllib.parse import urlencode

SCRIPT_DIR = Path(__file__).resolve().parent
IOS_DIR = SCRIPT_DIR.parent
VERSION_CONFIG_PATH = IOS_DIR / "Config" / "Version.xcconfig"
BUILD_ROOT = IOS_DIR / "build" / "testflight"
DEFAULT_BUNDLE_ID = "io.github.shanepark.dutypark"
DEFAULT_KEY_DIR = Path.home() / ".appstoreconnect" / "private_keys"
API_BASE = "https://api.appstoreconnect.apple.com"
PLATFORM = "IOS"
KST = timezone(timedelta(hours=9))

# Apple rejects tokens that expire more than 20 minutes after issue.
TOKEN_LIFETIME_SECONDS = 19 * 60
TOKEN_REFRESH_AFTER_SECONDS = 15 * 60
WHATS_NEW_MAX_LENGTH = 4000

# appVersionState values (appStoreState is the deprecated fallback). Apple does
# not publish an "editable" flag; these are the states App Store Connect lets
# you edit and resubmit. READY_FOR_REVIEW is a version added to an unsubmitted
# review submission draft.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
    "READY_FOR_REVIEW",
}
PENDING_REVIEW_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW"}
OPEN_SUBMISSION_STATES = ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES")
ACTIVE_SUBMISSION_STATES = ("WAITING_FOR_REVIEW", "IN_REVIEW")


class ReleaseError(Exception):
    pass


class AscError(ReleaseError):
    def __init__(self, status: int, method: str, url: str, body: bytes):
        self.status = status
        self.errors = []
        try:
            self.errors = json.loads(body or b"{}").get("errors") or []
        except (ValueError, AttributeError):
            pass
        lines = [f"App Store Connect returned HTTP {status} for {method} {url.replace(API_BASE, '')}"]
        for error in self.errors:
            code = f" [{error['code']}]" if error.get("code") else ""
            lines.append(f"  - {error.get('title', '')}: {error.get('detail', '')}{code}")
        if not self.errors and body:
            lines.append("  " + body.decode("utf-8", "replace")[:500])
        super().__init__("\n".join(lines))


# --- configuration helpers -------------------------------------------------


def read_marketing_version(path: Path) -> str:
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as error:
        raise ReleaseError(f"Unable to read {path}: {error}") from error
    match = re.search(r"^[ \t]*MARKETING_VERSION[ \t]*=[ \t]*([^;\s]+)", text, re.MULTILINE)
    if not match:
        raise ReleaseError(f"Unable to read MARKETING_VERSION from {path}")
    return match.group(1)


def default_build_number(now: Optional[datetime] = None) -> str:
    return (now or datetime.now(timezone.utc)).astimezone(KST).strftime("%Y%m%d")


def replace_review_notes_version(notes: Optional[str], version: str) -> Optional[str]:
    """Return notes with the leading 'Version x.y.z' replaced, or None when absent."""
    if not notes:
        return None
    match = re.match(r"(\s*)Version\s+\d+(?:\.\d+)*", notes)
    if not match:
        return None
    return f"{match.group(1)}Version {version}{notes[match.end():]}"


def match_locale(localizations: list, prefix: str, preferred: str) -> dict:
    def locale_of(item):
        return (item.get("attributes") or {}).get("locale") or ""

    for item in localizations:
        if locale_of(item).lower() == preferred.lower():
            return item
    candidates = [
        item for item in localizations
        if locale_of(item).lower() == prefix or locale_of(item).lower().startswith(prefix + "-")
    ]
    available = ", ".join(sorted(locale_of(item) for item in localizations)) or "none"
    if not candidates:
        raise ReleaseError(f"The App Store version has no '{prefix}' localization (available: {available}).")
    if len(candidates) > 1:
        raise ReleaseError(f"Multiple '{prefix}' localizations match (available: {available}); expected {preferred}.")
    return candidates[0]


def version_state(version: dict) -> str:
    attrs = version.get("attributes") or {}
    return attrs.get("appVersionState") or attrs.get("appStoreState") or "UNKNOWN"


class VersionPlan(NamedTuple):
    action: str  # "reuse", "pending" or "create"
    version: Optional[dict]
    needs_version_patch: bool = False


def choose_version(versions: list, target_version: str) -> VersionPlan:
    for version in versions:
        if version_state(version) in EDITABLE_STATES:
            current = (version.get("attributes") or {}).get("versionString")
            return VersionPlan("reuse", version, current != target_version)
    for version in versions:
        if version_state(version) in PENDING_REVIEW_STATES:
            return VersionPlan("pending", version)
    return VersionPlan("create", None)


# --- JWT -----------------------------------------------------------------


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _der_length(buf: bytes, index: int):
    first = buf[index]
    index += 1
    if first < 0x80:
        return first, index
    count = first & 0x7F
    if count not in (1, 2):
        raise ValueError("Unsupported DER length")
    return int.from_bytes(buf[index:index + count], "big"), index + count


def der_to_raw_signature(der: bytes, size: int = 32) -> bytes:
    """Convert an ASN.1 DER ECDSA signature to the raw r||s form JWS expects."""
    try:
        if der[0] != 0x30:
            raise ValueError("DER signature must start with a SEQUENCE")
        length, index = _der_length(der, 1)
        if index + length != len(der):
            raise ValueError("DER SEQUENCE length mismatch")
        parts = []
        for _ in range(2):
            if der[index] != 0x02:
                raise ValueError("DER signature must contain two INTEGERs")
            length, index = _der_length(der, index + 1)
            value = der[index:index + length]
            if len(value) != length:
                raise ValueError("Truncated DER INTEGER")
            index += length
            value = value.lstrip(b"\x00")
            if len(value) > size:
                raise ValueError("DER INTEGER is too large")
            parts.append(value.rjust(size, b"\x00"))
        if index != len(der):
            raise ValueError("Trailing bytes after DER signature")
        return b"".join(parts)
    except IndexError as error:
        raise ValueError("Truncated DER signature") from error


def openssl_sign(key_path: str, data: bytes) -> bytes:
    openssl = shutil.which("openssl")
    if not openssl:
        raise ReleaseError("openssl is required to sign App Store Connect tokens.")
    result = subprocess.run([openssl, "dgst", "-sha256", "-sign", key_path], input=data, capture_output=True)
    if result.returncode != 0:
        raise ReleaseError(f"openssl could not sign the token with {key_path}: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def make_jwt(key_id: str, issuer_id: str, key_path: str, now: Optional[float] = None,
             lifetime: int = TOKEN_LIFETIME_SECONDS, signer: Callable[[str, bytes], bytes] = openssl_sign) -> str:
    issued_at = int(time.time() if now is None else now)
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": issuer_id, "iat": issued_at, "exp": issued_at + lifetime, "aud": "appstoreconnect-v1"}
    signing_input = ".".join(b64url(json.dumps(part, separators=(",", ":")).encode()) for part in (header, claims))
    signature = der_to_raw_signature(signer(key_path, signing_input.encode("ascii")))
    return f"{signing_input}.{b64url(signature)}"


class TokenProvider:
    def __init__(self, key_id: str, issuer_id: str, key_path: str, clock: Callable[[], float] = time.time):
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.key_path = key_path
        self.clock = clock
        self._token = None
        self._issued_at = 0.0

    def __call__(self) -> str:
        now = self.clock()
        if self._token is None or now - self._issued_at >= TOKEN_REFRESH_AFTER_SECONDS:
            self._token = make_jwt(self.key_id, self.issuer_id, self.key_path, now=now)
            self._issued_at = now
        return self._token


# --- HTTP ----------------------------------------------------------------


def urllib_transport(method: str, url: str, headers: dict, body: Optional[bytes]):
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


class ApiClient:
    def __init__(self, token: Callable[[], str], transport=urllib_transport, base_url: str = API_BASE):
        self.token = token
        self.transport = transport
        self.base_url = base_url

    def request(self, method: str, path: str, params: Optional[dict] = None, body: Optional[dict] = None):
        if path.startswith("https://"):
            if not path.startswith(self.base_url + "/"):
                raise ReleaseError(f"Refusing to follow a link outside App Store Connect: {path}")
            url = path
        else:
            url = self.base_url + path
        if params:
            url += "?" + urlencode(params, safe="[],.")
        headers = {"Authorization": f"Bearer {self.token()}", "Accept": "application/json"}
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode("utf-8")
        status, raw = self.transport(method, url, headers, data)
        if not 200 <= status < 300:
            raise AscError(status, method, url, raw)
        return json.loads(raw) if raw else None

    def get(self, path: str, params: Optional[dict] = None):
        return self.request("GET", path, params)

    def get_all(self, path: str, params: Optional[dict] = None):
        data, included = [], []
        doc = self.get(path, params)
        while True:
            data.extend(doc.get("data") or [])
            included.extend(doc.get("included") or [])
            next_url = (doc.get("links") or {}).get("next")
            if not next_url:
                return data, included
            doc = self.get(next_url)

    def post(self, path: str, body: dict):
        return self.request("POST", path, body=body)

    def patch(self, path: str, body: dict):
        return self.request("PATCH", path, body=body)


# --- release flow ----------------------------------------------------------


@dataclass
class ReleaseConfig:
    version: str
    build_number: str
    bundle_id: str
    whats_new: dict = field(default_factory=dict)  # {"ko": text, "en": text}
    dry_run: bool = False
    poll_interval: int = 30
    build_timeout: int = 60 * 60
    state_timeout: int = 10 * 60


def default_confirm(question: str) -> bool:
    if not sys.stdin.isatty():
        print(question + "(non-interactive: answering no)")
        return False
    try:
        return input(question).strip().lower() in ("y", "yes")
    except EOFError:
        return False


def relationship_id(resource: dict, name: str) -> Optional[str]:
    data = ((resource.get("relationships") or {}).get(name) or {}).get("data")
    return data.get("id") if isinstance(data, dict) else None


def format_elapsed(seconds: float) -> str:
    seconds = int(seconds)
    return f"{seconds // 60:02d}:{seconds % 60:02d}"


class Release:
    def __init__(self, api: ApiClient, config: ReleaseConfig, out=None, confirm=default_confirm,
                 sleep=time.sleep, monotonic=time.monotonic):
        self.api = api
        self.cfg = config
        self.out = out or sys.stdout
        self.confirm = confirm
        self.sleep = sleep
        self.monotonic = monotonic

    def log(self, message: str = ""):
        self.out.write(message + "\n")
        self.out.flush()

    def write(self, method: str, path: str, body: dict, summary: str):
        if self.cfg.dry_run:
            self.log(f"[dry-run] would {method} {path}: {summary}")
            return None
        self.log(summary)
        return self.api.request(method, path, body=body)

    def find_app(self) -> dict:
        apps, _ = self.api.get_all("/v1/apps", {"filter[bundleId]": self.cfg.bundle_id, "limit": 200})
        apps = [app for app in apps if (app.get("attributes") or {}).get("bundleId") == self.cfg.bundle_id]
        if not apps:
            raise ReleaseError(f"No App Store Connect app found for bundle id {self.cfg.bundle_id}.")
        self.log(f"App: {self.cfg.bundle_id} (id {apps[0]['id']})")
        return apps[0]

    def fetch_build(self, app_id: str) -> Optional[dict]:
        builds, _ = self.api.get_all("/v1/builds", {
            "filter[app]": app_id,
            "filter[version]": self.cfg.build_number,
            "filter[preReleaseVersion.version]": self.cfg.version,
            "filter[preReleaseVersion.platform]": PLATFORM,
            "limit": 200,
        })
        return builds[0] if builds else None

    def wait_for_build(self, app_id: str) -> Optional[dict]:
        label = f"Build {self.cfg.version} ({self.cfg.build_number})"
        start = self.monotonic()
        while True:
            elapsed = self.monotonic() - start
            try:
                build = self.fetch_build(app_id)
            except AscError as error:
                if error.status < 500 and error.status != 429:
                    raise
                build, note = None, f"transient error HTTP {error.status}, retrying"
            except OSError as error:
                build, note = None, f"network error ({error}), retrying"
            else:
                note = None
            state = (build or {}).get("attributes", {}).get("processingState") if build else None
            self.log(f"[{format_elapsed(elapsed)}] {label}: {note or state or 'not visible yet'}")
            if state == "VALID":
                if build["attributes"].get("usesNonExemptEncryption") is None:
                    self.log("warning: the build's usesNonExemptEncryption is not set; App Store Connect may "
                             "block submission until export compliance is answered (Info.plist declares "
                             "ITSAppUsesNonExemptEncryption, so check the uploaded build).")
                return build
            if state in ("INVALID", "FAILED"):
                raise ReleaseError(f"{label} processing ended in {state}. Check the App Store Connect email/build page.")
            if self.cfg.dry_run:
                self.log("[dry-run] a real run polls every "
                         f"{self.cfg.poll_interval}s for up to {self.cfg.build_timeout // 60} min until VALID.")
                return build
            if elapsed >= self.cfg.build_timeout:
                raise ReleaseError(f"Timed out after {self.cfg.build_timeout // 60} min waiting for {label} to become VALID.")
            self.sleep(self.cfg.poll_interval)

    def list_versions(self, app_id: str) -> list:
        versions, _ = self.api.get_all(f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": PLATFORM, "limit": 200})
        return versions

    def cancel_pending(self, app_id: str, version: dict) -> dict:
        submissions, _ = self.api.get_all("/v1/reviewSubmissions", {
            "filter[app]": app_id,
            "filter[platform]": PLATFORM,
            "filter[state]": ",".join(ACTIVE_SUBMISSION_STATES),
            "include": "appStoreVersionForReview",
            "limit": 200,
        })
        matching = [s for s in submissions if relationship_id(s, "appStoreVersionForReview") == version["id"]]
        if not matching and len(submissions) == 1:
            matching = submissions
        if len(matching) != 1:
            raise ReleaseError(f"Could not identify the active review submission for version {version['id']} "
                               f"({len(submissions)} active submissions). Remove it in App Store Connect and retry.")
        submission = matching[0]
        self.write("PATCH", f"/v1/reviewSubmissions/{submission['id']}",
                   {"data": {"type": "reviewSubmissions", "id": submission["id"], "attributes": {"canceled": True}}},
                   f"Canceling review submission {submission['id']}")
        if self.cfg.dry_run:
            return version
        start = self.monotonic()
        while True:
            current = self.api.get(f"/v1/appStoreVersions/{version['id']}")["data"]
            state = version_state(current)
            elapsed = self.monotonic() - start
            self.log(f"[{format_elapsed(elapsed)}] Version state: {state}")
            if state in EDITABLE_STATES:
                return current
            if elapsed >= self.cfg.state_timeout:
                raise ReleaseError(f"Timed out after {self.cfg.state_timeout // 60} min waiting for the canceled "
                                   f"version to become editable (state {state}).")
            self.sleep(self.cfg.poll_interval)

    def select_version(self, app_id: str) -> Optional[dict]:
        target = self.cfg.version
        plan = choose_version(self.list_versions(app_id), target)
        version = plan.version
        needs_patch = plan.needs_version_patch
        if plan.action == "pending":
            attrs = version["attributes"]
            question = (f"{attrs.get('versionString')} is {version_state(version)}. Remove it from review and "
                        f"replace it with {target} build {self.cfg.build_number}? [y/N] ")
            if self.cfg.dry_run:
                self.log(f"[dry-run] a real run would ask: {question.strip()}")
            elif not self.confirm(question):
                raise ReleaseError("Aborted: the version in review was left unchanged.")
            version = self.cancel_pending(app_id, version)
            needs_patch = version["attributes"].get("versionString") != target
        if plan.action == "create":
            created = self.write("POST", "/v1/appStoreVersions", {"data": {
                "type": "appStoreVersions",
                "attributes": {"platform": PLATFORM, "versionString": target},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }}, f"Creating App Store version {target}")
            if created is None:
                return None
            version = created["data"]
        else:
            self.log(f"Reusing App Store version {version['attributes'].get('versionString')} "
                     f"(id {version['id']}, {version_state(version)})")
            if needs_patch:
                self.write("PATCH", f"/v1/appStoreVersions/{version['id']}", {"data": {
                    "type": "appStoreVersions", "id": version["id"], "attributes": {"versionString": target},
                }}, f"Changing versionString to {target}")
        return version

    def update_whats_new(self, version: dict):
        locs, _ = self.api.get_all(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations", {"limit": 200})
        targets = [(match_locale(locs, "ko", "ko"), self.cfg.whats_new["ko"]),
                   (match_locale(locs, "en", "en-US"), self.cfg.whats_new["en"])]
        for loc, text in targets:
            self.write("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": text},
            }}, f"Setting What's New for {loc['attributes']['locale']} ({len(text)} chars)")

    def update_review_notes(self, version: dict):
        try:
            detail = self.api.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")
        except AscError as error:
            if error.status != 404:
                raise
            detail = None
        detail = (detail or {}).get("data")
        if not detail:
            self.log("warning: the version has no App Review details; review notes were not changed.")
            return
        notes = (detail.get("attributes") or {}).get("notes")
        updated = replace_review_notes_version(notes, self.cfg.version)
        if updated is None:
            self.log("warning: App Review notes do not start with 'Version <x.y.z>'; notes were left unchanged.")
            return
        if updated == notes:
            self.log("App Review notes already start with the target version.")
            return
        first_line = updated.strip().splitlines()[0][:80]
        self.write("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", {"data": {
            "type": "appStoreReviewDetails", "id": detail["id"], "attributes": {"notes": updated},
        }}, f"Updating App Review notes: {first_line}")

    def attach_build(self, version: dict, build: Optional[dict]):
        if build is None:
            self.log(f"[dry-run] would attach build {self.cfg.build_number} once it is VALID")
            return
        self.write("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build",
                   {"data": {"type": "builds", "id": build["id"]}},
                   f"Attaching build {self.cfg.build_number} (id {build['id']})")

    def submit(self, app_id: str, version: dict) -> Optional[dict]:
        submissions, _ = self.api.get_all("/v1/reviewSubmissions", {
            "filter[app]": app_id,
            "filter[platform]": PLATFORM,
            "filter[state]": ",".join(OPEN_SUBMISSION_STATES),
            "include": "appStoreVersionForReview",
            "limit": 200,
        })
        submission = next((s for s in submissions if relationship_id(s, "appStoreVersionForReview") == version["id"]), None)
        has_item = submission is not None
        if submission is None and submissions:
            submission = submissions[0]
        if submission is not None:
            self.log(f"Reusing review submission {submission['id']} ({submission['attributes'].get('state')})")
        else:
            created = self.write("POST", "/v1/reviewSubmissions", {"data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": PLATFORM},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }}, "Creating review submission")
            if created is None:
                self.log("[dry-run] would add the version to the new submission and submit it")
                return None
            submission = created["data"]
        if not has_item:
            self.write("POST", "/v1/reviewSubmissionItems", {"data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}},
                },
            }}, f"Adding version {self.cfg.version} to submission {submission['id']}")
        result = self.write("PATCH", f"/v1/reviewSubmissions/{submission['id']}", {"data": {
            "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True},
        }}, f"Submitting review submission {submission['id']} for App Review")
        return result["data"] if result else None

    def run(self):
        app = self.find_app()
        build = self.wait_for_build(app["id"])
        version = self.select_version(app["id"])
        if version is None:
            self.log("[dry-run] would then set What's New (ko, en), update the review notes, attach the build "
                     "and submit for review.")
            return
        self.update_whats_new(version)
        self.update_review_notes(version)
        self.attach_build(version, build)
        submission = self.submit(app["id"], version)
        if self.cfg.dry_run:
            self.log("Dry run complete; no App Store Connect changes were made.")
            return
        current = self.api.get(f"/v1/appStoreVersions/{version['id']}")["data"]
        self.log("")
        self.log("Submitted for App Review")
        self.log(f"  Version:          {self.cfg.version}")
        self.log(f"  Build:            {self.cfg.build_number}")
        self.log(f"  Version state:    {version_state(current)}")
        self.log(f"  Submission:       {submission['id']}")
        self.log(f"  Submission state: {submission['attributes'].get('state')}")


# --- upload & CLI ----------------------------------------------------------


def run_command(cmd: list, env: dict):
    result = subprocess.run(cmd, env=env)
    if result.returncode != 0:
        raise ReleaseError(f"Command failed with exit code {result.returncode}: {cmd[0]} {cmd[1]}")


def upload_build(ipa: str, key_id: str, issuer_id: str, key_path: str, runner=run_command,
                 env: Optional[dict] = None, out=None, dry_run: bool = False):
    out = out or sys.stdout
    env = dict(os.environ if env is None else env)
    key_dir = Path(key_path).expanduser().resolve().parent
    if key_dir != DEFAULT_KEY_DIR.resolve():
        env["API_PRIVATE_KEYS_DIR"] = str(key_dir)
    cmd = ["xcrun", "altool", "--upload-app", "-f", ipa, "-t", "ios", "--apiKey", key_id, "--apiIssuer", issuer_id]
    prefix = f"API_PRIVATE_KEYS_DIR={shlex.quote(str(key_dir))} " if "API_PRIVATE_KEYS_DIR" in env else ""
    out.write(("[dry-run] would run: " if dry_run else "+ ") + prefix + " ".join(shlex.quote(c) for c in cmd) + "\n")
    out.flush()
    if not dry_run:
        runner(cmd, env)


def read_whats_new(path: str, label: str) -> str:
    try:
        text = Path(path).expanduser().read_text(encoding="utf-8").strip()
    except OSError as error:
        raise ReleaseError(f"Unable to read {label} What's New file {path}: {error}") from error
    if not text:
        raise ReleaseError(f"{label} What's New file is empty: {path}")
    if len(text) > WHATS_NEW_MAX_LENGTH:
        raise ReleaseError(f"{label} What's New is {len(text)} chars; App Store Connect allows {WHATS_NEW_MAX_LENGTH}.")
    return text


def parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Upload a Dutypark iOS build and submit it for App Review via the App Store Connect API.")
    parser.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID"), help="API key ID (env ASC_KEY_ID)")
    parser.add_argument("--issuer-id", default=os.environ.get("ASC_ISSUER_ID"), help="API issuer ID (env ASC_ISSUER_ID)")
    parser.add_argument("--key-path", help="Private key (.p8); default ~/.appstoreconnect/private_keys/AuthKey_<key-id>.p8")
    parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID, help=f"default {DEFAULT_BUNDLE_ID}")
    parser.add_argument("--version", dest="marketing_version", help="Marketing version; default from ios/Config/Version.xcconfig")
    parser.add_argument("--build-number", default=os.environ.get("BUILD_NUMBER"),
                        help="Build number (env BUILD_NUMBER); default today's KST date YYYYMMDD")
    parser.add_argument("--ipa", help="default ios/build/testflight/local-auto-export-<version>-<build>/Dutypark.ipa")
    parser.add_argument("--whats-new-ko", required=True, metavar="FILE", help="Korean What's New text (UTF-8)")
    parser.add_argument("--whats-new-en", required=True, metavar="FILE", help="English What's New text (UTF-8)")
    parser.add_argument("--skip-upload", action="store_true", help="Skip altool; the build is already uploaded")
    parser.add_argument("--dry-run", action="store_true", help="Print the plan using read-only requests; change nothing")
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    try:
        if not args.key_id or not args.issuer_id:
            raise ReleaseError("Set --key-id/ASC_KEY_ID and --issuer-id/ASC_ISSUER_ID.")
        key_path = str(Path(args.key_path or DEFAULT_KEY_DIR / f"AuthKey_{args.key_id}.p8").expanduser())
        if not Path(key_path).is_file():
            raise ReleaseError(f"API private key not found: {key_path}")
        version = args.marketing_version or read_marketing_version(VERSION_CONFIG_PATH)
        if not re.fullmatch(r"\d+\.\d+\.\d+", version):
            raise ReleaseError(f"Marketing version must contain three numeric components: {version}")
        build_number = args.build_number or default_build_number()
        if not re.fullmatch(r"\d{1,18}(\.\d{1,18}){0,2}", build_number):
            raise ReleaseError(f"Build number must contain one to three numeric components: {build_number}")
        ipa = args.ipa or str(BUILD_ROOT / f"local-auto-export-{version}-{build_number}" / "Dutypark.ipa")
        whats_new = {"ko": read_whats_new(args.whats_new_ko, "Korean"), "en": read_whats_new(args.whats_new_en, "English")}

        print(f"Release version: {version}")
        print(f"Build number: {build_number}")
        print(f"Bundle id: {args.bundle_id}")
        print(f"IPA: {'(upload skipped)' if args.skip_upload else ipa}")
        if args.dry_run:
            print("Dry run: read-only App Store Connect requests; no upload or changes.")
        sys.stdout.flush()

        if not args.skip_upload:
            if Path(key_path).name != f"AuthKey_{args.key_id}.p8":
                raise ReleaseError(f"altool requires the key file to be named AuthKey_<key-id>.p8: {key_path}")
            if not Path(ipa).is_file():
                if not args.dry_run:
                    raise ReleaseError(f"IPA not found: {ipa} (export it first, or pass --ipa / --skip-upload)")
                print(f"warning: IPA not found: {ipa}")
            upload_build(ipa, args.key_id, args.issuer_id, key_path, dry_run=args.dry_run)

        config = ReleaseConfig(version=version, build_number=build_number, bundle_id=args.bundle_id,
                               whats_new=whats_new, dry_run=args.dry_run)
        api = ApiClient(token=TokenProvider(args.key_id, args.issuer_id, key_path))
        Release(api, config).run()
        return 0
    except ReleaseError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
