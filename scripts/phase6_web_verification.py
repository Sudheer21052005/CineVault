"""Verify the live Phase 6 redesign in isolated desktop and phone-sized Chrome profiles."""

import argparse
from pathlib import Path
import time

from phase1_web_benchmark import chrome, serve
from phase2_screenshots import BREAKPOINTS
from phase3_web_verification import control, document, route, screenshot, seek, tap


def wheel(browser, x, y, horizontal=0, vertical=0):
    browser.call('Input.dispatchMouseEvent', type='mouseWheel', x=x, y=y,
                 deltaX=horizontal, deltaY=vertical)


def wait_label(browser, label):
    return browser.wait(lambda: control(browser, label), label)


def key(browser, value, code, vk):
    for event in ('rawKeyDown', 'keyUp'):
        browser.call('Input.dispatchKeyEvent', type=event, key=value, code=code,
                     windowsVirtualKeyCode=vk, nativeVirtualKeyCode=vk)


def section(browser, name, width, height):
    if not control(browser, name, exact=True):
        strip = seek(browser, 'Overview', exact=True)
        wheel(browser, int(width * .66), int(strip['y']), horizontal=480)
        until = time.monotonic() + .3
        while time.monotonic() < until:
            browser.poll()
    tap(browser, name, exact=True)


def movie(browser, out, width, height):
    size = 'phone' if width < 600 else 'desktop'
    document(browser, '/search?q=Iron%20Man&scope=movie', 'Iron Man 2008', width=width, height=height)
    tap(browser, 'Iron Man 2008', role='button')
    route(browser, '/movie/1726')
    wait_label(browser, 'Iron Man')
    screenshot(browser, out, f'iron-man-{size}')
    seek(browser, 'Top cast')
    seek(browser, 'Robert Downey Jr.')
    if width < 600:
        wheel(browser, int(width * .58), int(height * .68), vertical=200)
    screenshot(browser, out, f'overview-{size}')
    if width < 600:
        assert control(browser, 'Library', exact=True, role='button'), 'Phone navigation unavailable on a title'
        tap(browser, 'Robert Downey Jr.')
        browser.wait(lambda: browser.evaluate("location.hash.startsWith('#/person/')"), 'person link')
        person = browser.evaluate('location.hash')
        wait_label(browser, 'Biography')
        screenshot(browser, out, 'portrait-phone')
        tap(browser, 'Library', exact=True)
        route(browser, '/library/watchlist')
        tap(browser, 'Search', exact=True)
        route(browser, person[1:])
        tap(browser, 'Full filmography', exact=True)
        route(browser, person[1:] + '/filmography')
        wait_label(browser, 'Popularity')
        assert control(browser, 'Library', exact=True, role='button')
        screenshot(browser, out, 'filmography-phone')
        tap(browser, 'Back', exact=True)
        route(browser, person[1:])
        wait_label(browser, 'Biography')
        browser.evaluate('history.back()')
        route(browser, '/library/watchlist')
        wait_label(browser, 'Watchlist')
        browser.evaluate('history.forward()')
        route(browser, person[1:])
        wait_label(browser, 'Biography')
        tap(browser, 'Back', exact=True)
        route(browser, '/movie/1726')
        tap(browser, 'Search', exact=True)
        route(browser, '/search')
        wait_label(browser, 'Iron Man 2008')
        print('Phone tab switch, exploration Back, browser Back/Forward and destination reselection passed.', flush=True)
        document(browser, '/movie/1726', 'Iron Man', width=width, height=height)

    section(browser, 'Media', width, height)
    seek(browser, 'View backdrops 1')
    screenshot(browser, out, f'artwork-grid-{size}')
    tap(browser, 'View backdrops 1')
    wait_label(browser, '1 of')
    screenshot(browser, out, f'viewer-{size}')
    key(browser, 'ArrowRight', 'ArrowRight', 39)
    wait_label(browser, '2 of')
    tap(browser, 'Zoom in', exact=True)
    screenshot(browser, out, f'viewer-zoom-{size}')
    tap(browser, 'Fit image', exact=True)
    tap(browser, 'Thumbnail 1', exact=True)
    wait_label(browser, '1 of')
    if width >= 600:
        browser.call('Page.setDownloadBehavior', behavior='allow', downloadPath=str(out.resolve()))
        tap(browser, 'Download image', exact=True)
        downloaded = browser.wait(lambda: next(iter(out.glob('cinevault-*.jpg')), None), 'saved artwork', seconds=25)
        assert downloaded.stat().st_size > 1000
        print('Original TMDB artwork download passed.', flush=True)
    key(browser, 'Escape', 'Escape', 27)
    browser.wait(lambda: not control(browser, 'Zoom in', exact=True), 'viewer closed')
    print(f'{size} media tabs, fullscreen viewer, keyboard navigation and zoom controls passed.', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chrome', required=True)
    parser.add_argument('--build', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--phone', action='store_true')
    parser.add_argument('--overview-only', action='store_true')
    parser.add_argument('--breakpoints', action='store_true')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    width, height = (390, 844) if args.phone else (1440, 900)
    with serve(args.build, False) as origin, chrome(args.chrome, origin, False) as browser:
        if args.breakpoints:
            for width, height in BREAKPOINTS:
                document(browser, '/movie/1726', 'Iron Man', width=width, height=height)
                seek(browser, 'Overview', exact=True)
                navigation = 'Library' if width < 1024 else 'Watchlist'
                assert control(browser, navigation, exact=True, role='button'), (width, navigation)
                screenshot(browser, args.out, f'detail-{width}')
            return
        if args.overview_only:
            document(browser, '/movie/1726', 'Iron Man', width=width, height=height)
            screenshot(browser, args.out, 'movie-top')
            seek(browser, 'Top cast')
            screenshot(browser, args.out, 'movie-cast')
            return
        movie(browser, args.out, width, height)
        document(browser, '/tv/1396', 'Breaking Bad', width=width, height=height)
        section(browser, 'Seasons', width, height)
        seek(browser, 'Season 1')
        screenshot(browser, args.out, 'tv-seasons')
        tap(browser, 'Season 1')
        route(browser, '/tv/1396/season/1')
        tap(browser, 'Pilot')
        route(browser, '/tv/1396/season/1/episode/1')
        tap(browser, 'Episode stills', exact=True)
        tap(browser, 'View stills 1', exact=True)
        wait_label(browser, '1 of')
        screenshot(browser, args.out, 'episode-viewer')


if __name__ == '__main__':
    main()
