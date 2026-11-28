"""Benchmark equivalent Phase 4 and 5 Web releases with a verified physical GPU."""

import argparse
import base64
from collections import defaultdict
import json
from pathlib import Path
import tempfile

from phase1_web_benchmark import chrome, serve, summarize
from phase2_renderer_benchmark import interactive, sustained_scroll
from phase3_web_verification import control, document, seek, tap


def trace_scroll(browser, seconds):
    browser.call("Tracing.start", categories="devtools.timeline,v8,blink.user_timing,cc",
                 transferMode="ReturnAsStream")
    sustained_scroll(browser, seconds)
    browser.call("Tracing.end")
    stream = browser.wait(lambda: browser.trace_stream, "aggregated trace stream", seconds=30)
    chunks = []
    while True:
        chunk = browser.call("IO.read", handle=stream, size=196608)
        data = chunk["data"]
        chunks.append(base64.b64decode(data) if chunk.get("base64Encoded") else data.encode())
        if chunk["eof"]:
            break
    browser.call("IO.close", handle=stream)
    selected = {"Layout", "UpdateLayoutTree", "Decode Image", "Paint", "RasterTask",
                "MinorGC", "MajorGC", "V8.GCScavenger", "RunTask"}
    costs = defaultdict(lambda: {"count": 0, "total_ms": 0.0, "max_ms": 0.0})
    for event in json.loads(b"".join(chunks))["traceEvents"]:
        if event["name"] in selected and event.get("ph") == "X":
            row = costs[event["name"]]
            duration = event["dur"] / 1000
            row["count"] += 1
            row["total_ms"] += duration
            row["max_ms"] = max(row["max_ms"], duration)
    return dict(costs)


def backup_fixture(path):
    title = {"route": "/movie/27205", "name": "Inception", "image": "/poster-27205.jpg",
             "genreIds": [878], "genres": ["Science Fiction"], "minutes": 148}
    day = "2026-05-05"
    personal = {key: [] for key in ("diary", "lists", "favorites", "hidden", "episodes", "seasons", "history")}
    personal["favorites"] = [title]
    personal["diary"] = [{"id": "qa-viewing", "title": title, "day": day, "rating": 5}]
    watchlist = [{"type": "movie", "id": 300000 + index, "title": f"Offline fixture {index}",
                  "score": 7, "rating": 4.5, "status": "watched", "genres": ["Science Fiction"],
                  "added": day, "watched": day} for index in range(1000)]
    path.write_text(json.dumps({"format": "cinevault-library", "version": 1, "personal": personal,
                                "watchlist": watchlist, "achievements": ["qa-legacy"]}), encoding="utf-8")


def seed_library(browser, path):
    document(browser, "/library/personal/data", "Restore JSON")
    browser.call("Page.setInterceptFileChooserDialog", enabled=True)
    root = browser.call("DOM.getDocument", depth=1)["root"]["nodeId"]
    tap(browser, "Restore JSON", exact=True)
    node = browser.wait(lambda: browser.call("DOM.querySelector", nodeId=root,
                                             selector="input[type=file]")["nodeId"], "fixture picker")
    browser.call("DOM.setFileInputFiles", nodeId=node, files=[str(path.resolve())])
    tap(browser, "Confirm", exact=True)
    browser.wait(lambda: control(browser, "Backup restored."), "fixture restore completed")


def populated(browser):
    document(browser, "/", "Trending this week")
    seek(browser, "Recommended for you")
    home_ready = browser.now()
    document(browser, "/library/stats", "Statistics")
    seek(browser, "Personal viewing statistics")
    return {"home_recommendations_ms": home_ready, "personal_stats_ms": browser.now()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--scroll-samples", type=int, default=5)
    parser.add_argument("--scroll-seconds", type=float, default=20)
    parser.add_argument("--library-samples", type=int, default=12)
    parser.add_argument("--trace", action="store_true")
    args = parser.parse_args()

    for label, path in (("phase4", args.baseline), ("phase5", args.build)):
        if path is None:
            continue
        with serve(path, True) as origin:
            with chrome(args.chrome, origin, True, artwork=True, hardware=True) as browser:
                print(json.dumps({label + "_gpu": browser.gpu}), flush=True)
                if args.samples:
                    print(json.dumps({label: summarize([interactive(browser) for _ in range(args.samples)])}), flush=True)
            scrolling = []
            for _ in range(args.scroll_samples):
                with chrome(args.chrome, origin, True, artwork=True, hardware=True) as browser:
                    scrolling.append(sustained_scroll(browser, args.scroll_seconds))
            if scrolling:
                print(json.dumps({label + "_scroll": summarize(scrolling)}), flush=True)
            if args.trace:
                with chrome(args.chrome, origin, True, artwork=True, hardware=True) as browser:
                    print(json.dumps({label + "_trace": trace_scroll(browser, 6)}), flush=True)
            if args.library_samples:
                with tempfile.TemporaryDirectory() as temp:
                    fixture = Path(temp) / "library.json"
                    backup_fixture(fixture)
                    with chrome(args.chrome, origin, True, artwork=True, hardware=True) as browser:
                        seed_library(browser, fixture)
                        print(json.dumps({label + "_populated": summarize([
                            populated(browser) for _ in range(args.library_samples)
                        ])}), flush=True)


if __name__ == "__main__":
    main()
