"""Verify the local release's personalized library and run matched Web timings."""

import argparse
import json
from pathlib import Path
import time

from phase1_web_benchmark import chrome, serve, summarize
from phase2_renderer_benchmark import interactive, sustained_scroll
from phase3_web_verification import control, document, screenshot, seek, tap


def find(browser, label):
    return browser.wait(lambda: control(browser, label), label)


def fill(browser, label, value):
    active_text = """(() => {
      let node = document.activeElement;
      while (node?.shadowRoot?.activeElement) node = node.shadowRoot.activeElement;
      return ['INPUT', 'TEXTAREA'].includes(node?.tagName) ? node.value : null;
    })()"""

    def focus():
        point = control(browser, label)
        if point:
            browser.click(point)
        return browser.evaluate(active_text) == ""

    seek(browser, label)
    browser.wait(focus, f"focused {label} editor")
    browser.call("Input.insertText", text=value)
    browser.wait(lambda: browser.evaluate(active_text) == value, f"completed {label} editor")
    # Layout and hit targets can still move while the Flutter dialog animates in.
    until = time.monotonic() + .35
    while time.monotonic() < until:
        browser.poll()


def view(browser, width, height, out):
    document(browser, "/movie/27205", "Inception", width=width, height=height)
    tap(browser, "Favorite", exact=True)
    find(browser, "Favorited")
    for index in range(2):
        tap(browser, "Log viewing", exact=True)
        find(browser, "Viewing date")
        if index == 0:
            fill(browser, "Private notes", "Rewatched for the score.")
            fill(browser, "Review", "The practical effects still stand out.")
        tap(browser, "Save viewing", exact=True)
        browser.wait(lambda: not control(browser, "Save viewing", exact=True), "viewing editor closed")
    document(browser, "/library/personal/diary", "Use Log viewing", width=width, height=height)
    find(browser, "Inception")
    screenshot(browser, out, "diary")

    document(browser, "/library/personal/lists", "Create a list", width=width, height=height)
    tap(browser, "Create a list", exact=True)
    fill(browser, "List name", "Weekend films")
    tap(browser, "Save list", exact=True)
    try:
        find(browser, "Weekend films")
    except TimeoutError:
        screenshot(browser, out, "lists-save-failure")
        raise
    document(browser, "/movie/27205", "Inception", width=width, height=height)
    tap(browser, "Add to list", exact=True)
    tap(browser, "Weekend films")
    tap(browser, "Done", exact=True)
    document(browser, "/library/personal/lists", "Weekend films", width=width, height=height)
    tap(browser, "Weekend films")
    find(browser, "Inception")
    screenshot(browser, out, "lists")

    document(browser, "/tv/1396/season/1/episode/1", "Pilot", width=width, height=height)
    tap(browser, "Mark watched", exact=True)
    find(browser, "Mark unwatched")
    browser.evaluate("location.hash = '#/library/personal/progress'")
    find(browser, "Breaking Bad · Season 1")
    tap(browser, "Breaking Bad · Season 1")
    seek(browser, "Next unwatched episode")
    screenshot(browser, out, "progress")
    for path, name in (("/person/525", "Christopher Nolan"), ("/collection/10", "Star Wars Collection")):
        document(browser, path, name, width=width, height=height)
        tap(browser, "Favorite", exact=True)
        find(browser, "Favorited")
    document(browser, "/library/personal/favorites", "Inception", width=width, height=height)
    find(browser, "Christopher Nolan")
    find(browser, "Star Wars Collection")
    screenshot(browser, out, "favorites")
    document(browser, "/library/personal/recent", "Pilot", width=width, height=height)
    screenshot(browser, out, "recent")
    document(browser, "/library/stats", "Statistics", width=width, height=height)
    seek(browser, "Personal viewing statistics")
    browser.call("Input.dispatchMouseEvent", type="mouseWheel", x=int(width * .67),
                 y=int(height * .68), deltaX=0, deltaY=505)
    screenshot(browser, out, "stats")
    document(browser, "/", "Trending this week", width=width, height=height)
    seek(browser, "Recommended for you")
    seek(browser, "Because of")
    browser.call("Input.dispatchMouseEvent", type="mouseWheel", x=int(width * .67),
                 y=int(height * .68), deltaX=0, deltaY=340)
    screenshot(browser, out, "home-personal")

    document(browser, "/library/personal/data", "Save JSON backup", width=width, height=height)
    screenshot(browser, out, "backup")
    browser.call("Page.setDownloadBehavior", behavior="allow", downloadPath=str(out.resolve()))
    tap(browser, "Save JSON backup", exact=True)
    backup = browser.wait(lambda: next(iter(out.glob("cinevault-library-*.json")), None),
                          "written local JSON backup")
    with backup.open(encoding="utf-8") as contents:
        data = json.load(contents)
    assert len(data["personal"]["diary"]) == 2
    assert any(row["notes"] == "Rewatched for the score." and
               row["review"] == "The practical effects still stand out."
               for row in data["personal"]["diary"])
    assert len(data["personal"]["episodes"]) == 1
    assert len(data["personal"]["favorites"]) == 3
    assert data["personal"]["lists"][0]["titles"][0]["route"] == "/movie/27205"
    tap(browser, "Export CSV", exact=True)
    browser.wait(lambda: any(out.glob("cinevault-library-*.csv")), "written local CSV export")
    browser.call("Network.setBlockedURLs", urls=["*api.themoviedb.org*", "*image.tmdb.org*"])
    document(browser, "/library/personal/diary", "Use Log viewing", width=width, height=height)
    find(browser, "Inception")
    document(browser, "/library/personal/progress", "Breaking Bad · Season 1", width=width, height=height)
    tap(browser, "Breaking Bad · Season 1")
    seek(browser, "Next unwatched episode")
    print("Web diary, list membership, favorites, episode progress, downloads and offline reload passed.", flush=True)
    return backup


def restore(browser, backup, out, width, height):
    document(browser, "/library/personal/data", "Restore JSON", width=width, height=height)
    browser.call("Page.setInterceptFileChooserDialog", enabled=True)
    root = browser.call("DOM.getDocument", depth=1)["root"]["nodeId"]
    for _ in range(2):
        tap(browser, "Restore JSON", exact=True)
        node = browser.wait(lambda: browser.call("DOM.querySelector", nodeId=root,
                                                 selector="input[type=file]")["nodeId"],
                            "backup file input")
        browser.call("DOM.setFileInputFiles", nodeId=node, files=[str(backup.resolve())])
        find(browser, "Merge this backup")
        tap(browser, "Confirm", exact=True)
        find(browser, "Backup restored.")
    browser.call("Page.setDownloadBehavior", behavior="allow", downloadPath=str(out.resolve()))
    tap(browser, "Save JSON backup", exact=True)
    reread = browser.wait(lambda: next(iter(out.glob("cinevault-library-*.json")), None),
                          "restored JSON export")
    assert json.loads(reread.read_text(encoding="utf-8")) == json.loads(backup.read_text(encoding="utf-8"))
    print("A fresh Web profile restored the same JSON twice and exported identical records.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--scroll-samples", type=int, default=5)
    parser.add_argument("--scroll-seconds", type=float, default=12)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--mobile", action="store_true")
    args = parser.parse_args()
    if args.baseline:
        for label, path in (("phase3", args.baseline), ("phase4", args.build)):
            with serve(path, True) as origin, chrome(args.chrome, origin, True, artwork=True) as browser:
                print(json.dumps({label: summarize([interactive(browser) for _ in range(args.samples)])},
                                 indent=2), flush=True)
                if args.scroll_samples:
                    scrolling = [sustained_scroll(browser, args.scroll_seconds) for _ in range(args.scroll_samples)]
                    print(json.dumps({f"{label}_scroll": summarize(scrolling)}, indent=2), flush=True)
        return
    if args.out is None:
        parser.error("--out is required for the walkthrough")
    args.out.mkdir(parents=True, exist_ok=True)
    if any(args.out.glob("cinevault-library-*")):
        parser.error("Choose a new output directory for this run")
    width, height = (390, 844) if args.mobile else (1440, 900)
    with serve(args.build, False) as origin, chrome(args.chrome, origin, False) as browser:
        backup = view(browser, width, height, args.out)
    restored = args.out / "restored"
    restored.mkdir(exist_ok=True)
    with serve(args.build, False) as origin, chrome(args.chrome, origin, False) as browser:
        restore(browser, backup, restored, width, height)


if __name__ == "__main__":
    main()
