"""Exercise Chrome keyboard accessibility, reduced motion, and offline boot."""

import argparse
from pathlib import Path
import time

from phase1_web_benchmark import chrome, serve
from phase3_web_verification import control, document, route, screenshot, tap


def keyboard_and_attribution(browser, out):
    browser.call("Emulation.setEmulatedMedia", features=[{"name": "prefers-reduced-motion", "value": "reduce"}])
    document(browser, "/", "Trending this week")
    browser.point("View details", role="button")
    page = next(index for index in range(1, 6) if control(browser, f"{index} / 5", exact=True))
    until = time.monotonic() + 9
    while time.monotonic() < until:
        browser.poll()
    assert control(browser, f"{page} / 5", exact=True), "The hero advanced with reduced motion"
    tap(browser, "About CineVault", exact=True)
    browser.point("Developed by Sudheer Prajapati")
    browser.point("This product uses the TMDB API")
    browser.point("The Movie Database", role="button")
    screenshot(browser, out, "attribution")
    tap(browser, "Close", exact=True)
    browser.wait(lambda: not control(browser, "The Movie Database"), "About closed")

    for kind, key, code, virtual, modifiers in (
        ("rawKeyDown", "Control", "ControlLeft", 17, 2),
        ("rawKeyDown", "k", "KeyK", 75, 2),
        ("keyUp", "k", "KeyK", 75, 2),
        ("keyUp", "Control", "ControlLeft", 17, 0),
    ):
        browser.call("Input.dispatchKeyEvent", type=kind, key=key, code=code, modifiers=modifiers,
                     windowsVirtualKeyCode=virtual, nativeVirtualKeyCode=virtual)
    route(browser, "/search")
    browser.wait(lambda: browser.evaluate("""(() => {
        let element = document.activeElement;
        while (element?.shadowRoot?.activeElement) element = element.shadowRoot.activeElement;
        return ['INPUT', 'TEXTAREA'].includes(element?.tagName);
    })()"""), "keyboard-focused Search input")
    browser.call("Input.insertText", text="Inception")
    browser.point("Inception 2010", role="button")
    ax = browser.call("Accessibility.getFullAXTree")["nodes"]
    assert any("Inception 2010" in node.get("name", {}).get("value", "") and
               node.get("role", {}).get("value") == "button" for node in ax)
    print("Chrome reduced-motion carousel, About credits, keyboard Search and result semantics passed.")


def credentials_optional(browser):
    document(browser, "/discover/now-playing", "TMDB is unconfigured")
    browser.point("Retry", role="button")
    document(browser, "/library/personal/diary", "Your diary is empty.", width=390, height=844)
    assert not browser.calls, "An unconfigured app issued a TMDB request"
    print("Credential-free release displayed the setup message and opened its offline library.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", required=True)
    parser.add_argument("--live", required=True, type=Path)
    parser.add_argument("--offline", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    with serve(args.offline, False) as origin, chrome(args.chrome, origin, False) as browser:
        credentials_optional(browser)
    with serve(args.live, False) as origin, chrome(args.chrome, origin, False) as browser:
        keyboard_and_attribution(browser, args.out)
