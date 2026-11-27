"""Compare release builds with equivalent artwork, scroll, and title markers."""

import argparse
import base64
import io
import json
import math
from pathlib import Path
import statistics
import time

from PIL import Image

from phase1_web_benchmark import chrome, serve, summarize


def document(browser, route):
    browser.sample += 1
    browser.open(f"?renderer={browser.sample}#{route}")
    browser.enable_semantics()


def fixture_visible(browser):
    data = browser.call("Page.captureScreenshot", format="jpeg", quality=57)["data"]
    image = Image.open(io.BytesIO(base64.b64decode(data))).resize((144, 90)).convert("RGB")
    pixels = sum(1 for r, g, b in image.get_flattened_data() if r > 60 and b > g * 1.35 and r > g * 1.35)
    return browser.now() if pixels >= 120 else None


def focus_search(browser):
    def focus():
        if browser.evaluate("""(() => {
          let element = document.activeElement;
          while (element?.shadowRoot?.activeElement) element = element.shadowRoot.activeElement;
          return element?.tagName === 'INPUT' || element?.tagName === 'TEXTAREA';
        })()"""):
            return True
        field = browser.pick("Search movies and TV shows")
        if field:
            browser.click(field)
        return False
    browser.wait(focus, "focused search editor")


def interactive(browser):
    browser.device(1440, 900)
    browser.call("Network.setCacheDisabled", cacheDisabled=True)
    browser.call("Storage.clearDataForOrigin", origin=browser.origin.rstrip("/"), storageTypes="indexeddb")
    calls = len(browser.calls)
    art_start = len(browser.artwork_network)
    document(browser, "/")
    ready = browser.point("Trending this week")["now"]
    artwork = browser.wait(lambda: fixture_visible(browser), "first painted fixture artwork")
    images = browser.artwork_network[art_start:]
    initial_api = len(browser.calls) - calls
    document(browser, "/search")
    focus_search(browser)
    start = browser.now()
    browser.call("Input.insertText", text="Inception")
    hit = browser.point("Inception 2010", role="button")
    search = hit["now"] - start
    fresh_start = browser.now()
    fresh_calls = len(browser.calls)
    browser.click(hit)
    fresh_title = browser.point("Runtime: 148 minutes")["now"] - fresh_start
    fresh_requests = len(browser.calls) - fresh_calls
    browser.evaluate("history.back()")
    hit = browser.point("Inception 2010", role="button")
    started = browser.now()
    calls_before = len(browser.calls)
    browser.click(hit)
    cached = browser.point("Runtime: 148 minutes")["now"] - started
    cached_detail_requests = sum(path == "/3/movie/27205" for path in browser.calls[calls_before:])
    return {
        "shell_ready_ms": ready,
        "first_painted_artwork_ms": artwork,
        "first_artwork_transfer_ms": images[0][1] if images else None,
        "artwork_bytes_before_paint": sum(item[2] for item in images),
        "api_requests_before_paint": initial_api,
        "input_to_search_result_ms": search,
        "fresh_title_click_to_full_metadata_ms": fresh_title,
        "fresh_title_json_requests_before_metadata": fresh_requests,
        "cached_title_click_to_full_metadata_ms": cached,
        "cached_title_json_requests_before_metadata": cached_detail_requests,
    }


def used_heap(browser):
    metrics = browser.call("Performance.getMetrics")["metrics"]
    return next(item["value"] for item in metrics if item["name"] == "JSHeapUsedSize") / (1024 ** 2)


def sustained_scroll(browser, seconds):
    browser.device(1440, 900)
    browser.call("Network.setCacheDisabled", cacheDisabled=True)
    browser.call("Storage.clearDataForOrigin", origin=browser.origin.rstrip("/"), storageTypes="indexeddb")
    browser.call("Performance.enable")
    first_api = len(browser.calls)
    document(browser, "/discover/now-playing")
    browser.point("Inception 2010", role="button")
    browser.evaluate("""(() => {
      const probe = window.cvFrameProbe = {running:true, times:[], before:0};
      const step = time => {
        if (!probe.running) return;
        if (probe.before) probe.times.push(time - probe.before);
        probe.before = time;
        requestAnimationFrame(step);
      };
      requestAnimationFrame(step);
      return true;
    })()""")
    first_art = len(browser.artwork_network)
    heaps = [used_heap(browser)]
    start = time.monotonic()
    step = 0
    while (elapsed := time.monotonic() - start) < seconds:
        browser.call("Input.dispatchMouseEvent", type="mouseWheel", x=930, y=660,
                     deltaX=0, deltaY=540 if int(elapsed / 2.7) % 3 != 2 else -720)
        if step % 12 == 0:
            heaps.append(used_heap(browser))
        step += 1
        deadline = start + step * .08
        while time.monotonic() < deadline:
            browser.poll()
    deltas = browser.evaluate("cvFrameProbe.running = false; cvFrameProbe.times")
    images = browser.artwork_network[first_art:]
    pages = browser.calls[first_api:].count("/3/movie/now_playing")
    heaps.append(used_heap(browser))
    browser.evaluate("location.hash = '#/'")
    browser.point("Trending this week")
    post = used_heap(browser)
    browser.call("HeapProfiler.collectGarbage")
    retained = used_heap(browser)
    ordered = sorted(deltas)
    return {
        "scroll_frame_samples": len(deltas),
        "scroll_raf_p50_ms": statistics.median(deltas),
        "scroll_raf_p95_ms": ordered[math.ceil(len(ordered) * .95) - 1],
        "scroll_raf_over_16_7ms_pct": 100 * sum(frame > 16.7 for frame in deltas) / len(deltas),
        "scroll_raf_over_20ms_pct": 100 * sum(frame > 20 for frame in deltas) / len(deltas),
        "before_scroll_js_heap_mib": heaps[0],
        "scroll_peak_js_heap_mib": max(heaps),
        "after_return_js_heap_mib": post,
        "after_return_gc_js_heap_mib": retained,
        "scroll_completed_artwork_requests": len(images),
        "scroll_catalogue_pages_requested": pages,
        "scroll_artwork_mib": sum(item[2] for item in images) / (1024 ** 2),
    }


def mobile_smoke(browser):
    browser.device(390, 844)
    document(browser, "/")
    browser.tap("Now Playing", exact=True)
    browser.point("Films in theatrical release")
    browser.tap("Back", exact=True)
    browser.point("Trending this week")
    browser.tap("Search", exact=True, low=.85)
    browser.tap("Search movies and TV shows")
    browser.call("Input.insertText", text="Inception")
    browser.tap("Inception 2010", role="button")
    browser.point("Runtime: 148 minutes")
    browser.wait(lambda: browser.evaluate("location.hash === '#/movie/27205'"), "canonical title URL")
    browser.tap("Add to watchlist", role="button")
    browser.point("Remove from watchlist")
    browser.evaluate("history.back()")
    browser.point("Inception 2010", role="button")
    browser.evaluate("history.forward()")
    browser.point("Runtime: 148 minutes")
    document(browser, "/search?q=Inception&scope=tv")
    browser.point("No matching titles found.")
    document(browser, "/search?mode=discover&kind=tv&sort=release")
    browser.point("Browsing TV shows")
    browser.point("Breaking Bad 2008", role="button")
    if not {"/3/search/tv", "/3/discover/tv"}.issubset(browser.calls):
        raise AssertionError("TV title search and discovery must use distinct endpoints")
    document(browser, "/library/watchlist")
    browser.point("1 saved title")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--scroll-samples", type=int, default=5)
    parser.add_argument("--scroll-seconds", type=float, default=20)
    parser.add_argument("--smoke", action="store_true", help="exercise Phase 2 routes instead of timing")
    args = parser.parse_args()
    if args.smoke:
        with serve(args.current, True) as origin, chrome(args.chrome, origin, True) as browser:
            mobile_smoke(browser)
        print("Phone navigation, browser history, Watchlist, TV search and discovery passed.")
        return
    for label, path in [("phase1", args.baseline), ("phase2", args.current)]:
        if path is None:
            continue
        if args.samples:
            with serve(path, True) as origin, chrome(args.chrome, origin, True, artwork=True) as browser:
                measurements = [interactive(browser) for _ in range(args.samples)]
                print(json.dumps({label + "_interactive": summarize(measurements)}, indent=2), flush=True)
        if args.scroll_samples:
            samples = []
            with serve(path, True) as origin:
                for _ in range(args.scroll_samples):
                    with chrome(args.chrome, origin, True, artwork=True) as browser:
                        samples.append(sustained_scroll(browser, args.scroll_seconds))
            print(json.dumps({label + "_scroll": summarize(samples)}, indent=2), flush=True)


if __name__ == "__main__":
    main()
