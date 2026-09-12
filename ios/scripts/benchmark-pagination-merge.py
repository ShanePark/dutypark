#!/usr/bin/env python3
"""Compare production pagination merges from a Git revision and the working tree.

Run with Xcode installed:
  python3 ios/scripts/benchmark-pagination-merge.py --baseline <revision>

The macOS harness uses actual production DTOs and Combine @Published arrays.
It measures only merge CPU work, not iOS rendering or network latency. It checks
full output equality before measuring empty, small, medium, and large fixtures.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


SPECS = [
    ("Notification", "ios/Dutypark/Features/Notifications/NotificationStore.swift", "notifications", "result.content", "NotificationDTO", 20),
    ("Inquiry", "ios/Dutypark/Features/Support/SupportViewModel.swift", "inquiries", "page.content", "MyInquiryDTO", 10),
    ("Report", "ios/Dutypark/Features/Support/SupportViewModel.swift", "reports", "page.content", "MyReportDTO", 10),
]
MODEL_PATHS = [
    "ios/Dutypark/Domain/Models/CommonModels.swift",
    "ios/Dutypark/Domain/Models/InquiryModels.swift",
    "ios/Dutypark/Domain/Models/ReportModels.swift",
    "ios/Dutypark/Domain/Models/NotificationModels.swift",
]


def merge_block(source: str, array: str, incoming: str, optimized: bool) -> str:
    marker = (f"let existingIDs = Set({array}.map(\\.id))" if optimized
              else f"{array}.append(contentsOf: {incoming}.filter")
    start = source.index(marker)
    end = source.index("\n            })", start) + len("\n            })")
    block = source[start:end]
    if not optimized and "contains(where:" not in block:
        raise ValueError("Baseline must precede the pagination ID-set optimization")
    return block.replace(incoming, "incoming").replace(array, "stored")


FIXTURES = r'''
func uuid(_ i: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", i))!
}
func makeNotification(_ i: Int) -> NotificationDTO {
    NotificationDTO(id: uuid(i), type: .inquiryAnswered, referenceType: nil,
        referenceId: "message-\(i)", actorId: nil,
        payload: try! JSONDecoder().decode(NotificationPayloadDTO.self, from: Data("{}".utf8)),
        isRead: false, createdAt: LocalDateTimeValue(rawValue: "2026-09-12T10:00:00"))
}
func makeInquiry(_ i: Int) -> MyInquiryDTO {
    MyInquiryDTO(id: uuid(i), email: nil, subject: "Inquiry \(i)", content: "Content \(i)",
        status: .open, createdAt: LocalDateTimeValue(rawValue: "2026-09-12T10:00:00"),
        answer: nil, answeredAt: nil)
}
func makeReport(_ i: Int) -> MyReportDTO {
    MyReportDTO(id: uuid(i), targetType: .member, reportedMemberName: "Member \(i)",
        reason: .spam, detail: nil, status: .open,
        createdAt: LocalDateTimeValue(rawValue: "2026-09-12T10:00:00"), resolvedAt: nil)
}
func milliseconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
}
'''


def runner(name: str, dto: str, page_size: int, before: str, after: str) -> str:
    return f'''
final class {name}Runner {{
    @Published var stored: [{dto}]
    init(_ values: [{dto}]) {{ stored = values }}
    @inline(never) func before(_ incoming: [{dto}]) {{ {before} }}
    @inline(never) func after(_ incoming: [{dto}]) {{ {after} }}
}}
func run{name}(count: Int, iterations: Int, rounds: Int) {{
    let existing = (0..<count).map(make{name})
    let incoming = (count..<(count + {page_size})).map(make{name})
    let runner = {name}Runner(existing)
    let overlap = existing.first.map {{ [$0] }} ?? []
    let cases = [incoming, overlap + incoming + [incoming[0]], [], existing]
    for candidate in cases {{
        runner.stored = existing
        runner.before(candidate)
        let expected = runner.stored
        runner.stored = existing
        runner.after(candidate)
        precondition(runner.stored == expected, "{name} merge outputs differ")
    }}
    var samples = Array(repeating: [Double](), count: 2)
    var checksum = 0
    for round in 0..<rounds {{
        for index in 0..<2 {{
            let variant = (index + round) % 2
            let start = ContinuousClock.now
            for _ in 0..<iterations {{
                runner.stored = existing
                if variant == 0 {{ runner.before(incoming) }} else {{ runner.after(incoming) }}
            }}
            let elapsed = milliseconds(ContinuousClock.now - start)
            samples[variant].append(elapsed)
            checksum += runner.stored.count
            print("sample,{name},\\(count),{page_size},\\(round),\\(variant == 0 ? "before" : "after"),\\(iterations),\\(elapsed)")
        }}
    }}
    let before = samples[0].sorted()[rounds / 2]
    let after = samples[1].sorted()[rounds / 2]
    print("median,{name},existing=\\(count),page={page_size},iterations=\\(iterations),before_ms=\\(before),after_ms=\\(after),speedup=\\(before / after),equality_cases=\\(cases.count),checksum=\\(checksum)")
}}
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True, help="Git revision before the optimization")
    parser.add_argument("--rounds", type=int, default=7)
    parser.add_argument("--iterations", type=int, default=500)
    parser.add_argument("--output", type=Path, help="Directory for sources, executable, manifest, and results")
    args = parser.parse_args()
    if args.rounds < 1 or args.iterations < 1:
        parser.error("rounds and iterations must be positive")
    root = Path(__file__).resolve().parents[2]
    commit = subprocess.check_output(
        ["git", "rev-parse", "--verify", "--end-of-options", f"{args.baseline}^{{commit}}"],
        cwd=root, text=True,
    ).strip()
    output = args.output or Path(tempfile.mkdtemp(prefix="dutypark-pagination-benchmark-"))
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    chunks = ["import Foundation\nimport Combine\n", FIXTURES]
    manifest = {"baseline": commit, "rounds": args.rounds, "iterations": args.iterations, "sources": {}}

    def source(path: str, version: str) -> str:
        value = ((root / path).read_bytes() if version == "current" else subprocess.check_output(
            ["git", "show", f"{commit}:{path}"], cwd=root,
        ))
        manifest["sources"][f"{version}:{path}"] = hashlib.sha256(value).hexdigest()
        destination = output / version / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(value)
        return value.decode()

    for path in MODEL_PATHS:
        current = source(path, "current")
        baseline = source(path, "baseline")
        if current != baseline:
            raise ValueError(f"DTO source changed since baseline: {path}; choose an equivalent baseline")
        chunks.append(current)
    for name, path, array, incoming, dto, page_size in SPECS:
        before = merge_block(source(path, "baseline"), array, incoming, optimized=False)
        after = merge_block(source(path, "current"), array, incoming, optimized=True)
        chunks.append(runner(name, dto, page_size, before, after))
    chunks.append("for count in [0, 20, 200, 2000] {\n")
    for name, *_ in SPECS:
        chunks.append(f"run{name}(count: count, iterations: {args.iterations}, rounds: {args.rounds})\n")
    chunks.append("}\n")
    swift_source = output / "benchmark.swift"
    swift_source.write_text("\n".join(chunks))
    manifest["harness_sha256"] = hashlib.sha256(swift_source.read_bytes()).hexdigest()
    manifest["swift_version"] = subprocess.check_output(["swiftc", "--version"], text=True).strip()
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    binary = output / "benchmark"
    subprocess.run([
        "swiftc", "-O", "-module-cache-path", str(output / "module-cache"),
        str(swift_source), "-o", str(binary),
    ], check=True)
    result = subprocess.check_output([str(binary)], text=True)
    (output / "results.log").write_text(result)
    print(result, end="")
    print(f"Artifacts: {output}")


if __name__ == "__main__":
    main()
