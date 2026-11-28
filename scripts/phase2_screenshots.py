"""Capture CineVault release screenshots in an isolated Chrome profile."""

import argparse
import base64
from pathlib import Path
import time

from phase1_web_benchmark import chrome, serve


BREAKPOINTS = ((320, 740), (390, 844), (599, 844), (600, 900), (768, 900),
               (1023, 900), (1024, 900), (1440, 900))
SCREENS = (
    ("discover", "/discover", "Discover"),
    ("movies", "/discover/movies", "Movies"),
    ("tv", "/discover/tv", "TV Shows"),
    ("now-playing", "/discover/now-playing", "Now Playing"),
    ("search", "/search?q=Inception", "Inception 2010"),
    ("detail", "/movie/27205", "Runtime: 148"),
    ("watchlist", "/library/watchlist", "Watchlist"),
    ("statistics", "/library/stats", "Statistics"),
)


def open_screen(browser, path, width, height, marker):
    browser.device(width, height)
    browser.sample += 1
    browser.open(f"?visual={browser.sample}#{path}")
    browser.enable_semantics()
    browser.point(marker)


def settle_artwork(browser, minimum):
    if minimum:
        browser.wait(lambda: browser.evaluate(
            """performance.getEntriesByType('resource').filter(item =>
               item.name.startsWith('https://image.tmdb.org/')).length >= """ + str(minimum)
        ), "live TMDB artwork", seconds=14)
    until = time.monotonic() + .5
    while time.monotonic() < until:
        browser.poll()


def screenshot(browser, directory, name):
    data = browser.call("Page.captureScreenshot", format="jpeg", quality=87)["data"]
    (directory / (name + ".jpg")).write_bytes(base64.b64decode(data))
    print(name, flush=True)


def add_title(browser, path, name):
    open_screen(browser, path, 1440, 900, name)
    browser.tap("Add to watchlist", role="button")
    browser.point("Remove from watchlist")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--before", action="store_true")
    parser.add_argument("--breakpoints", action="store_true")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    with serve(args.build, False) as origin, chrome(args.chrome, origin, False) as browser:
        prefix = "before" if args.before else "after"
        for width, height in (BREAKPOINTS if args.breakpoints else ((1440, 900), (390, 844))):
            open_screen(browser, "/", width, height, "Trending this week")
            settle_artwork(browser, 3)
            screenshot(browser, args.out, f"{prefix}-home-{width}")
        if args.breakpoints:
            return
        if args.before:
            open_screen(browser, "/movie/27205", 1440, 900, "Runtime: 148")
            settle_artwork(browser, 1)
            screenshot(browser, args.out, "before-detail-1440")
            return
        add_title(browser, "/movie/27205", "Inception")
        add_title(browser, "/movie/157336", "Interstellar")
        for name, path, marker in SCREENS:
            for width, height in ((1440, 900), (390, 844)):
                open_screen(browser, path, width, height, marker)
                settle_artwork(browser, 0 if name == "statistics" else 1)
                screenshot(browser, args.out, f"after-{name}-{width}")


if __name__ == "__main__":
    main()
