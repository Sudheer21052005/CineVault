"""Check the live review, person, and tab regressions on Web or an isolated Android emulator."""
import argparse
from pathlib import Path
import re

from phase1_web_benchmark import chrome, serve
from phase3_android_verification import GraphEmulator
from phase3_web_verification import control, document, screenshot, seek, tap
from phase6_web_verification import section, wheel


def web(browser, out):
    width, height = 1440, 900
    for route, marker in (('/movie/27205', 'Inception'), ('/tv/1396', 'Breaking Bad')):
        document(browser, route, marker, width=width, height=height)
        seek(browser, 'Where to watch')
        for step in (340, 240, -70, -70, -70, -70, -70, -70):
            wheel(browser, 970, 622, vertical=step)
            for _ in range(8):
                browser.poll()
        wheel(browser, 970, 640, vertical=1450)
        browser.wait(lambda: (control(browser, 'Reviews', exact=True) or {}).get('y', 900) < 130, 'pinned tabs')
        pinned = control(browser, 'Reviews', exact=True)['y']
        tabs = ['Reviews', 'Cast & crew', 'Media', 'Details', 'Related', 'Overview', 'Reviews']
        if route.startswith('/tv/'):
            tabs.insert(2, 'Seasons')
        for name in tabs:
            section(browser, name, width, height)
            for _ in range(16):
                browser.poll()
            position = control(browser, 'Reviews', exact=True)['y']
            assert abs(position - pinned) < 2, (marker, name, pinned, position)
        screenshot(browser, out, marker.lower().replace(' ', '-') + '-reviews')
        if route.startswith('/movie/'):
            browser.click({'x': 550, 'y': 245})
            browser.wait(lambda: control(browser, 'Read on TMDB'), 'expanded review source link')
            screenshot(browser, out, 'inception-review-expanded')
        print(marker, 'pinned y', round(pinned, 2), 'after', len(tabs), 'switches', flush=True)
    document(browser, '/person/1356210', 'Biography', width=width, height=height)
    seek(browser, 'Known for')
    seek(browser, 'Stranger Things')
    screenshot(browser, out, 'millie-known-for')
    for name in ('Stranger Things', 'Enola Holmes'):
        assert control(browser, name), name
    print('Live Known for includes Stranger Things and Enola Holmes.', flush=True)


def android(device, out, baseline):
    def swipe(delta, duration='610'):
        x, y = round(device.width * .69), round(device.height * .61)
        device.command('shell', 'input', 'swipe', str(x), str(y), str(x), str(y - delta), duration)

    def marker_nodes(labels):
        positions = {}
        for node in device.nodes():
            label = (node.get('text', '') + node.get('content-desc', '')).split('\n')[0].casefold()
            if label in labels:
                positions[label] = int(re.findall(r'\d+', node['bounds'])[1])
        return positions

    def select_tab(name):
        order = ['Overview', 'Cast & crew', 'Seasons', 'Related', 'Media', 'Details', 'Reviews']
        for _ in range(3):
            visible = {}
            for node in device.nodes():
                label = (node.get('text', '') + node.get('content-desc', '')).split('\n')[0]
                if label in order:
                    visible[label] = node
            if name in visible:
                device.tap(visible[name])
                return
            if not visible:
                swipe(round(device.height * .24))
                continue
            nearest = min(visible, key=lambda label: abs(order.index(label) - order.index(name)))
            _, top, _, bottom = map(int, re.findall(r'\d+', visible[nearest]['bounds']))
            y = str((top + bottom) // 2)
            left, right = str(round(device.width * .18)), str(round(device.width * .84))
            start, end = (left, right) if order.index(name) < order.index(nearest) else (right, left)
            device.command('shell', 'input', 'swipe', start, y, end, y, '390')
        raise TimeoutError(f'Android tab unavailable: {name}')

    for route in ('/tv/1396', '/movie/27205'):
        kind = route.split('/')[1]
        device.open_route(route)
        device.seek('Where to watch')
        for _ in range(4):
            swipe(round(device.height * .20))
        samples = []
        for _ in range(8):
            swipe(-round(device.height * .045))
            samples.append(marker_nodes({'seasons & episodes', 'where to watch'}))
        print(kind, 'slow upward positions (physical px)', samples, flush=True)
        device.capture(out, f'{kind}-upward')
        if baseline:
            continue
        select_tab('Reviews')
        device.seek('Viewer reviews')
        device.capture(out, f'{kind}-reviews')
        for tab in ('Details', 'Cast & crew', 'Overview', 'Reviews'):
            select_tab(tab)
        device.seek('Viewer reviews')
    if not baseline:
        device.open_route('/person/1356210')
        device.seek('Known for')
        device.seek('Stranger Things')
        device.capture(out, 'millie-known-for')
        print('Android review tabs and live Known for passed.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--chrome')
    parser.add_argument('--build', type=Path)
    parser.add_argument('--device')
    parser.add_argument('--baseline', action='store_true')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    if args.device:
        android(GraphEmulator(args.device), args.out, args.baseline)
    else:
        with serve(args.build, False) as origin, chrome(args.chrome, origin, False) as browser:
            web(browser, args.out)
