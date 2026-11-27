"""Compare two local Flutter release builds using Chrome and TMDB fixtures.

Requires Python 3.10+, websockets, and Chrome. Outputs only named measurements
and aggregate counts. Use --live for a small smoke test with the local build's
credential. Fixture runs override the credential asset with a dummy value.
"""

import argparse
import base64
from contextlib import contextmanager
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import math
from pathlib import Path
from queue import Empty
import statistics
import subprocess
import tempfile
from threading import Thread
import time
from urllib.parse import parse_qs, urlsplit
from urllib.request import urlopen

from websockets.sync.client import connect


FIXTURE = Path(__file__).resolve().parents[1] / "test/fixtures/tmdb_catalogue.json"
DELAY_SECONDS = 0.35


class LocalBuild(SimpleHTTPRequestHandler):
    def __init__(self, *args, fixture_mode, **kwargs):
        self.fixture_mode = fixture_mode
        super().__init__(*args, **kwargs)

    def do_GET(self):
        if self.fixture_mode and urlsplit(self.path).path == "/assets/.env":
            dummy = b"TMDB_API_KEY=fixture-only\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(dummy)))
            self.end_headers()
            self.wfile.write(dummy)
            return
        try:
            super().do_GET()
        except ConnectionError:
            # Chrome can cancel an in-flight asset when starting a new document.
            pass

    def log_message(self, _format, *_args):
        pass


@contextmanager
def serve(path, fixture_mode):
    handler = partial(LocalBuild, directory=path, fixture_mode=fixture_mode)
    with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            yield f"http://127.0.0.1:{server.server_port}/"
        finally:
            server.shutdown()
            thread.join()


class Catalogue:
    def __init__(self):
        data = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.movies = data["movies"]
        self.tv = data["tv"]
        self.genres = data["genres"]
        self.titles = self.movies + self.tv
        self.more_movies = self.movies + [
            dict(self.movies[0], id=500000 + index, title=f"Fixture movie {index}")
            for index in range(1, 37)
        ]

    def response(self, url):
        path = url.path.removeprefix("/3/").split("/")
        kind = path[0]
        params = parse_qs(url.query)
        choices = self.tv if "tv" in path else self.movies
        if kind == "genre":
            return 200, {"genres": self.genres[path[1]]}
        if kind == "search":
            text = params.get("query", [""])[0].lower()
            choices = [
                item for item in self.titles
                if (path[1] == "multi" or item["media_type"] == path[1])
                and text in (item.get("title") or item.get("name")).lower()
            ]
        elif len(path) > 2 and path[2] == "similar":
            choices = [item for item in choices if str(item["id"]) != path[1]][:1]
        elif len(path) > 2 and path[2] == "recommendations":
            choices = choices[2:]
        elif len(path) == 2 and path[1].isdigit():
            for item in choices:
                if str(item["id"]) == path[1]:
                    return 200, item
            return 404, {}
        elif path == ["movie", "now_playing"]:
            choices = self.more_movies
        return 200, {"page": 1, "total_pages": 1,
                     "total_results": len(choices), "results": choices}


DOM_HELPERS = r"""
(() => {
  function elements(root, selector) {
    const matched = [...root.querySelectorAll(selector)];
    for (const host of root.querySelectorAll('flt-glass-pane, flt-scene-host, flt-semantics-host')) {
      if (host.shadowRoot) matched.push(...elements(host.shadowRoot, selector));
    }
    return matched;
  }
  window.cvPick = (needle, mode, role, low) => {
    const now = performance.now();
    for (const el of elements(document, '[aria-label], flt-semantics, input, textarea')) {
      if (el.getAttribute('aria-hidden') === 'true') continue;
      const label = (el.getAttribute('aria-label') || el.getAttribute('placeholder') ||
        el.getAttribute('flt-semantics-label') || el.textContent || '').replace(/\s+/g, ' ').trim();
      const actualRole = el.getAttribute('role') ||
        (/^(INPUT|TEXTAREA)$/.test(el.tagName) ? 'textbox' : '');
      if (role && actualRole !== role) continue;
      if (mode === 'exact' ? label !== needle : !label.includes(needle)) continue;
      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0 || rect.left >= innerWidth ||
          rect.right <= 0 || rect.bottom <= 0 || rect.top >= innerHeight || rect.top < low * innerHeight) continue;
      return {x: Math.min(innerWidth - 1, Math.max(0, (rect.left + rect.right) / 2)),
        y: Math.min(innerHeight - 1, Math.max(0, (rect.top + rect.bottom) / 2)), now};
    }
    return null;
  };
})();
"""


class Browser:
    def __init__(self, websocket, origin, fixture_mode):
        self.socket = websocket
        self.origin = origin
        self.fixture_mode = fixture_mode
        self.catalogue = Catalogue()
        self.responses = {}
        self.pending = []
        self.serial = 0
        self.sample = 0
        self.calls = []
        self.network = []
        self.request_ids = {}
        self.call("Page.enable")
        self.call("Network.enable")
        self.call("Page.addScriptToEvaluateOnNewDocument", source=DOM_HELPERS)
        if fixture_mode:
            self.call("Fetch.enable", patterns=[
                {"urlPattern": "https://api.themoviedb.org/*"},
                {"urlPattern": "https://*.gstatic.com/flutter-canvaskit/*"},
            ])

    def send(self, method, **params):
        self.serial += 1
        self.socket.send(json.dumps({"id": self.serial, "method": method, "params": params}))
        return self.serial

    def call(self, method, **params):
        message = self.send(method, **params)
        deadline = time.monotonic() + 30
        while message not in self.responses:
            if time.monotonic() > deadline:
                raise TimeoutError(f"Browser command timed out ({method})")
            self.poll()
        result = self.responses.pop(message)
        if "error" in result:
            raise RuntimeError(f"Browser command failed ({method})")
        return result.get("result", {})

    def poll(self):
        now = time.monotonic()
        while self.pending and self.pending[0][0] <= now:
            _, request, status, body = self.pending.pop(0)
            self.send("Fetch.fulfillRequest", requestId=request, responseCode=status,
                      responseHeaders=[{"name": "Content-Type", "value": "application/json"},
                                       {"name": "Access-Control-Allow-Origin", "value": "*"}],
                      body=base64.b64encode(body).decode("ascii"))
        try:
            event = json.loads(self.socket.recv(timeout=0.018))
        except (TimeoutError, Empty):
            return
        if "id" in event:
            # Fire-and-forget Fetch responses carry no measurements.
            self.responses[event["id"]] = event
            if len(self.responses) > 100:
                self.responses.pop(next(iter(self.responses)))
            return
        params = event.get("params", {})
        if event.get("method") == "Fetch.requestPaused":
            url = urlsplit(params["request"]["url"])
            request = params["requestId"]
            if url.hostname == "api.themoviedb.org":
                status, body = self.catalogue.response(url)
                data = json.dumps(body, separators=(",", ":")).encode()
                self.calls.append(url.path)
                self.pending.append((time.monotonic() + DELAY_SECONDS, request, status, data))
            else:
                # The older build used the CanvasKit CDN. Serve its identical
                # bundled renderer from loopback to control both runs.
                tail = url.path.split("/")
                asset = "/".join(tail[-2:]) if tail[-2] in ("chromium", "webparagraph") else tail[-1]
                self.send("Fetch.continueRequest", requestId=request,
                          url=self.origin + "canvaskit/" + asset)
        elif event.get("method") == "Network.requestWillBeSent":
            url = urlsplit(params["request"]["url"])
            if url.hostname == "api.themoviedb.org":
                self.request_ids[params["requestId"]] = (url.path, params["timestamp"])
        elif event.get("method") == "Network.loadingFinished":
            req = self.request_ids.pop(params["requestId"], None)
            if req:
                self.network.append((req[0], (params["timestamp"] - req[1]) * 1000))

    def evaluate(self, expression):
        result = self.call("Runtime.evaluate", expression=expression, returnByValue=True)
        return result.get("result", {}).get("value")

    def device(self, width, height):
        self.call("Emulation.setDeviceMetricsOverride", width=width, height=height,
                  deviceScaleFactor=1, mobile=False)

    def open(self, route=""):
        self.call("Page.navigate", url=self.origin + route)

    def pick(self, label, *, exact=False, role="", low=0):
        args = json.dumps([label, "exact" if exact else "contains", role, low])
        return self.evaluate(f"window.cvPick?.(...{args})")

    def wait(self, probe, label, seconds=15):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            result = probe()
            if result:
                return result
            self.poll()
        raise TimeoutError(f"Timed out waiting for {label}")

    def point(self, label, **kwargs):
        return self.wait(lambda: self.pick(label, **kwargs), label)

    def click(self, point):
        for kind in ("mousePressed", "mouseReleased"):
            self.call("Input.dispatchMouseEvent", type=kind, x=point["x"], y=point["y"],
                      button="left", clickCount=1)

    def tap(self, label, **kwargs):
        self.click(self.point(label, **kwargs))

    def enable_semantics(self):
        self.wait(
            lambda: self.evaluate("""(() => {
              const button = document.querySelector('flt-semantics-placeholder');
              if (!button) return false;
              button.click();
              return true;
            })()"""),
            "Flutter accessibility placeholder",
        )

    def after(self, name):
        return self.evaluate(
            f"performance.getEntriesByName('cinevault.{name}').at(-1)?.detail ?? null"
        )

    def now(self):
        return self.evaluate("performance.now()")


@contextmanager
def chrome(executable, origin, fixture_mode):
    with tempfile.TemporaryDirectory(prefix="cinevault-chrome-", ignore_cleanup_errors=True) as profile:
        browser = subprocess.Popen([
            executable, "--headless=new", "--disable-gpu", "--no-first-run",
            "--disable-default-apps", "--disable-background-networking",
            "--remote-debugging-port=0", f"--user-data-dir={profile}", "about:blank",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            port_file = Path(profile) / "DevToolsActivePort"
            deadline = time.monotonic() + 12
            while not port_file.is_file():
                if browser.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Isolated Chrome failed to start")
                time.sleep(0.05)
            port = port_file.read_text(encoding="utf-8").splitlines()[0]
            with urlopen(f"http://127.0.0.1:{port}/json/list", timeout=5) as response:
                targets = json.load(response)
            url = next(target["webSocketDebuggerUrl"] for target in targets if target["type"] == "page")
            with connect(url, max_size=2 * 1024 * 1024) as socket:
                yield Browser(socket, origin, fixture_mode)
        finally:
            browser.terminate()
            browser.wait(timeout=8)


def benchmark(browser):
    browser.device(1440, 900)
    browser.call("Network.setCacheDisabled", cacheDisabled=True)
    call_start = len(browser.calls)
    browser.sample += 1
    browser.open(f"?benchmark={browser.sample}")
    browser.enable_semantics()
    startup = browser.point("Now Playing", exact=True, role="button")
    first_card = browser.point("Inception 2010", role="button")
    boot_calls = len(browser.calls) - call_start
    browser.tap("Search", role="button", exact=True, low=0.7)
    browser.tap("Search movies and TV shows")
    start = browser.now()
    request_start = len(browser.network)
    browser.call("Input.insertText", text="Inception")
    result = browser.point("Inception 2010", role="button")
    search = result["now"] - start
    api = [ms for path, ms in browser.network[request_start:] if path == "/3/search/multi"]
    search_mark = browser.after("searchResults")
    start = browser.now()
    browser.click(result)
    nav = browser.point("Back", exact=True, role="button")["now"] - start
    browser.tap("Back", exact=True, role="button")
    browser.point("Search", exact=True, role="button", low=0.7)
    browser.tap("Now Playing", exact=True, role="button", low=0.7)
    browser.point("Select a title to view its details.")
    browser.point("Inception 2010", role="button")
    start = browser.now()
    browser.call("Input.dispatchMouseEvent", type="mouseWheel", x=720, y=560, deltaX=0, deltaY=610)
    scroll = browser.wait(
        lambda: None if browser.pick("Select a title to view its details.") else browser.now(),
        "scrolled grid",
    ) - start
    shell = browser.after("startupShell")
    return {
        "reload_to_shell_ms": startup["now"],
        "reload_to_first_card_ms": first_card["now"],
        "pre_card_json_requests": boot_calls,
        "input_to_search_result_ms": search,
        "search_request_ms": api[0] if api else None,
        "title_click_to_back_control_ms": nav,
        "wheel_to_header_offscreen_ms": scroll,
        "dart_start_to_shell_ms": shell["elapsed_us"] / 1000 if shell else None,
        "dart_search_to_first_frame_ms": search_mark["elapsed_us"] / 1000 if search_mark else None,
    }


def smoke(browser, live):
    browser.device(390, 844)
    browser.open()
    browser.enable_semantics()
    browser.tap("Now Playing", role="button", exact=True, low=0.7)
    browser.point("Select a title to view its details.")
    browser.tap("Back", role="button", exact=True)
    browser.point("CineVault")
    browser.tap("Search", role="button", exact=True, low=0.7)
    browser.tap("Search movies and TV shows")
    browser.call("Input.insertText", text="Inception")
    browser.tap("Inception 2010", role="button")
    browser.wait(lambda: browser.evaluate("location.hash === '#/movie/27205'"), "canonical movie URL")
    browser.point("Runtime: 148")
    if not live:
        browser.tap("The Dark Knight", role="button", exact=True)
        browser.wait(lambda: browser.evaluate("location.hash === '#/movie/155'"), "nested movie URL")
        browser.evaluate("history.back()")
        browser.wait(lambda: browser.evaluate("location.hash === '#/movie/27205'"), "browser Back to parent title")
        browser.point("Runtime: 148")
        browser.evaluate("history.back()")
        browser.wait(lambda: browser.evaluate("location.hash.startsWith('#/search?')"), "browser Back to query")
        browser.point("Inception 2010", role="button")
        browser.evaluate("history.forward()")
        browser.wait(lambda: browser.evaluate("location.hash === '#/movie/27205'"), "browser Forward to title")
        browser.point("Runtime: 148")
        browser.open("#/search?q=Inception&scope=tv")
        browser.point("No matching titles found.")
        if "/3/search/tv" not in browser.calls:
            raise AssertionError("TV scope did not use the TV search endpoint")
        browser.open("#/search?mode=discover&kind=tv&sort=release")
        browser.point("Browsing TV shows")
        browser.point("Breaking Bad 2008", role="button")
        if "/3/discover/tv" not in browser.calls:
            raise AssertionError("Discovery did not use the TV discovery endpoint")
        browser.open("#/library/watchlist")
        browser.point("0 saved titles")
    browser.open("#/movie/27205")
    browser.point("Runtime: 148")
    return ("live title search and deep link passed" if live else
            "mobile tabs, browser history, TV search/discovery and empty library passed")


def summarize(samples):
    output = {}
    for name in samples[0]:
        values = sorted(row[name] for row in samples if row[name] is not None)
        if values:
            output[name] = {
                "n": len(values), "p50": round(statistics.median(values), 2),
                "p95": round(values[math.ceil(len(values) * .95) - 1], 2),
            }
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=30)
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--live", action="store_true")
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be positive")
    if args.live or args.smoke:
        with serve(args.current, not args.live) as origin, chrome(args.chrome, origin, not args.live) as browser:
            print(json.dumps({"smoke": smoke(browser, args.live)}), flush=True)
        return
    for label, path in [("baseline", args.baseline), ("phase1", args.current)]:
        if path is None:
            continue
        with serve(path, True) as origin, chrome(args.chrome, origin, True) as browser:
            samples = [benchmark(browser) for _ in range(args.samples)]
            print(json.dumps({label: summarize(samples)}, indent=2), flush=True)


if __name__ == "__main__":
    main()
