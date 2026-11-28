"""Exercise the knowledge graph against live TMDB or time equivalent title markers."""

import argparse
import base64
import json
from pathlib import Path
import time

from phase1_web_benchmark import chrome, serve, summarize
from phase2_renderer_benchmark import interactive, used_heap


DESTINATIONS = (
    ("movie", "/movie/27205", "Runtime: 148 minutes"),
    ("series", "/tv/1396", "Breaking Bad"),
    ("person", "/person/6193", "Biography"),
    ("filmography", "/person/6193/filmography?sort=topRated&votes=1000", "Highest rated"),
    ("collection", "/collection/10", "Films in this collection"),
    ("company", "/company/174", "Warner Bros. Pictures"),
    ("network", "/network/174", "AMC"),
    ("genre", "/genre/movie/878", "Science Fiction"),
    ("keyword", "/keyword/83", "saving the world"),
    ("season", "/tv/1396/season/1", "Pilot"),
    ("specials", "/tv/1396/season/0", "Good Cop / Bad Cop"),
    ("episode", "/tv/1396/season/1/episode/1", "Pilot"),
    ("search", "/search?q=Leonardo%20DiCaprio&scope=person", "Leonardo DiCaprio"),
)


def document(browser, path, marker, *, width=1440, height=900):
    browser.device(width, height)
    browser.sample += 1
    browser.open(f"?graph={browser.sample}#{path}")
    browser.enable_semantics()
    browser.wait(lambda: control(browser, marker), marker)


def control(browser, label, *, exact=False, role=""):
    args = json.dumps([label, exact, role])
    return browser.evaluate(fr"""(([needle, exact, role]) => {{
      const candidates = [];
      function scan(root) {{
        for (const el of root.querySelectorAll('flt-semantics, [aria-label]')) {{
          if (el.getAttribute('aria-hidden') === 'true') continue;
          if (role && el.getAttribute('role') !== role) continue;
          const explicit = el.getAttribute('aria-label') || el.getAttribute('flt-semantics-label');
          const name = (explicit || el.textContent || '').replace(/\s+/g, ' ').trim();
          if (exact ? name !== needle : !name.includes(needle)) continue;
          const rect = el.getBoundingClientRect();
          const left = Math.max(0, rect.left), right = Math.min(innerWidth, rect.right);
          const top = Math.max(0, rect.top), bottom = Math.min(innerHeight, rect.bottom);
          if (left >= right || top >= bottom || rect.width * rect.height === 0) continue;
          candidates.push({{x: (left + right) / 2, y: (top + bottom) / 2,
            score: rect.width * rect.height + (explicit ? 0 : innerWidth * innerHeight)}});
        }}
        for (const host of root.querySelectorAll('flt-glass-pane, flt-scene-host, flt-semantics-host')) {{
          if (host.shadowRoot) scan(host.shadowRoot);
        }}
      }}
      scan(document);
      candidates.sort((left, right) => left.score - right.score);
      return candidates[0] || null;
    }})({args})""")


def seek(browser, label, *, exact=False, direction=1, role=""):
    for _ in range(17):
        point = control(browser, label, exact=exact, role=role)
        if point:
            return point
        vw, vh = browser.evaluate("[innerWidth, innerHeight]")
        browser.call("Input.dispatchMouseEvent", type="mouseWheel",
                     x=int(vw * .66), y=int(vh * .68), deltaX=0, deltaY=direction * 320)
        until = time.monotonic() + .3
        while time.monotonic() < until:
            browser.poll()
    return browser.wait(lambda: control(browser, label, exact=exact, role=role), label)


def tap(browser, label, **options):
    browser.click(seek(browser, label, **options))


def route(browser, path):
    # Identifiers here are test inputs. Diagnostic output omits raw network URLs.
    expected = json.dumps("#" + path)
    browser.wait(lambda: browser.evaluate(
        f"location.hash === {expected} || location.hash.startsWith({expected} + '?')"
    ), "expected graph route")


def screenshot(browser, out, name):
    until = time.monotonic() + .65
    while time.monotonic() < until:
        browser.poll()
    frame = browser.call("Page.captureScreenshot", format="jpeg", quality=88)["data"]
    (out / f"{name}.jpg").write_bytes(base64.b64decode(frame))
    print(name, flush=True)


def live_chains(browser, out):
    document(browser, "/movie/27205", "Runtime: 148 minutes")
    browser.call("Performance.enable")
    heap_before = used_heap(browser)
    tap(browser, "Cast & crew", exact=True)
    seek(browser, "Leonardo DiCaprio")
    screenshot(browser, out, "movie-cast-desktop")
    tap(browser, "Leonardo DiCaprio")
    route(browser, "/person/6193")
    browser.point("Biography")
    tap(browser, "Full filmography")
    route(browser, "/person/6193/filmography")
    browser.point("Filmography")
    tap(browser, "Popularity")
    tap(browser, "Highest rated", exact=True)
    browser.wait(lambda: browser.evaluate("location.hash.includes('sort=topRated')"), "filmography sort URL")
    tap(browser, "Any vote count")
    tap(browser, "1000+ votes", exact=True)
    browser.wait(lambda: browser.evaluate("location.hash.includes('votes=1000')"), "filmography votes URL")
    django = seek(browser, "Django Unchained", role="button")
    browser.click(django)
    route(browser, "/movie/68718")
    tap(browser, "Cast & crew", exact=True)
    tap(browser, "Crew", exact=True)
    tap(browser, "Quentin Tarantino")
    route(browser, "/person/138")
    browser.point("Biography")
    chain_heap = used_heap(browser)
    # The outer Flutter toolbar can expose the tooltip independently of the page semantics tree.
    browser.click(control(browser, "Back", exact=True) or {"x": 279, "y": 34})
    route(browser, "/movie/68718")
    browser.evaluate("history.back()")
    route(browser, "/person/6193/filmography")
    browser.wait(lambda: browser.evaluate("location.hash.includes('votes=1000') && location.hash.includes('sort=topRated')"),
                 "restored filmography filters")
    restored = browser.wait(lambda: control(browser, "Django Unchained", role="button"), "restored filmography scroll")
    if abs(restored["y"] - django["y"]) > 120:
        raise AssertionError("Filmography returned at a different scroll position")
    browser.evaluate("history.forward()")
    route(browser, "/movie/68718")
    browser.evaluate("history.back()")
    route(browser, "/person/6193/filmography")
    browser.call("HeapProfiler.collectGarbage")
    print(json.dumps({"live_movie_chain_js_heap_mib": {
        "before": round(heap_before, 2), "at_director": round(chain_heap, 2),
        "back_after_gc": round(used_heap(browser), 2),
    }}), flush=True)

    document(browser, "/movie/11", "Star Wars")
    tap(browser, "Star Wars Collection")
    route(browser, "/collection/10")
    tap(browser, "The Empire Strikes Back", role="button")
    route(browser, "/movie/1891")
    browser.point("The Empire Strikes Back")

    document(browser, "/tv/1396", "Breaking Bad", width=390, height=844)
    tap(browser, "Season 1", exact=True)
    route(browser, "/tv/1396/season/1")
    tap(browser, "Pilot")
    route(browser, "/tv/1396/season/1/episode/1")
    tap(browser, "Guest stars", exact=True)
    seek(browser, "Steven Michael Quezada")
    screenshot(browser, out, "episode-guests-mobile")
    tap(browser, "Steven Michael Quezada")
    route(browser, "/person/61535")
    browser.point("Biography")
    browser.evaluate("history.back()")
    route(browser, "/tv/1396/season/1/episode/1")
    browser.call("Page.reload")
    browser.enable_semantics()
    browser.point("Pilot")
    tap(browser, "Episode stills", exact=True)
    seek(browser, "View stills 1")
    screenshot(browser, out, "episode-stills-mobile")

    document(browser, "/search?q=tt1375666", "Inception 2010")
    browser.point("External ID lookup")
    document(browser, "/movie/27205", "Runtime: 148 minutes")
    tap(browser, "Where to watch", exact=True)
    seek(browser, "JustWatch")
    screenshot(browser, out, "regional-availability-desktop")

    for label, target in (
        ("Warner Bros. Pictures", "/company/174"),
        ("Science Fiction", "/genre/movie/878"),
        ("dreams", None),
    ):
        document(browser, "/movie/27205", "Runtime: 148 minutes")
        tap(browser, label, exact=True)
        if target:
            route(browser, target)
        else:
            browser.wait(lambda: browser.evaluate("location.hash.startsWith('#/keyword/')"),
                         "linked keyword route")
        seek(browser, "Associated titles")
    document(browser, "/tv/1396", "Breaking Bad")
    tap(browser, "AMC", exact=True)
    route(browser, "/network/174")
    seek(browser, "Associated titles")

    document(browser, "/search?q=Star%20Wars&scope=collection", "Star Wars Collection")
    document(browser, "/search?q=Warner%20Bros&scope=company", "Warner Bros. Pictures")
    document(browser, "/search?q=saving%20the%20world&scope=keyword", "saving the world")
    print("Live movie, franchise, episode, catalogue relationships, search scopes and availability passed.", flush=True)


def matrix(browser, out):
    for label, path, marker in DESTINATIONS:
        for size, width, height in (("desktop", 1440, 900), ("mobile", 390, 844)):
            document(browser, path, marker, width=width, height=height)
            screenshot(browser, out, f"{label}-{size}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--out", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--matrix-only", action="store_true")
    mode.add_argument("--chains-only", action="store_true")
    args = parser.parse_args()
    if args.baseline:
        for label, path in (("phase2", args.baseline), ("phase3", args.build)):
            with serve(path, True) as origin, chrome(args.chrome, origin, True, artwork=True) as browser:
                samples = [interactive(browser) for _ in range(args.samples)]
                print(json.dumps({label: summarize(samples)}, indent=2), flush=True)
        return
    if args.out is None:
        parser.error("--out is required for live verification")
    args.out.mkdir(parents=True, exist_ok=True)
    with serve(args.build, False) as origin, chrome(args.chrome, origin, False) as browser:
        if not args.matrix_only:
            live_chains(browser, args.out)
        if not args.chains_only:
            matrix(browser, args.out)


if __name__ == "__main__":
    main()
