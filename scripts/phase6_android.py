"""Exercise the Phase 6 phone navigation and gallery in an isolated Android emulator."""

import argparse
from pathlib import Path
import re

from phase3_android_verification import GraphEmulator


def open_section(device, name):
    for node in device.nodes():
        label, _, _ = (node.get('text', '') + node.get('content-desc', '')).partition('\n')
        if label == name:
            device.tap(node)
            return
    overview = device.seek('Overview')
    _, top, _, bottom = map(int, re.findall(r'\d+', overview['bounds']))
    y = str((top + bottom) // 2)
    device.command('shell', 'input', 'swipe', str(round(device.width * .86)), y,
                   str(round(device.width * .2)), y, '330')
    device.open_label(name)


def check(device, out):
    device.open_route('/movie/1726')
    device.find('Iron Man', exact=True)
    device.find('Library', exact=True)
    device.capture(out, 'android-movie')
    device.open_label('Jon Favreau', exact=True)
    device.find('Biography')
    device.capture(out, 'android-person')
    device.open_label('Library', exact=True)
    device.find('Watchlist', exact=True)
    device.open_label('Home', exact=True)
    device.find('Biography')
    device.back()
    device.find('Overview')
    # The detail restores the scroll offset it had when the director opened.
    for _ in range(2):
        device.command('shell', 'input', 'swipe', str(device.width // 2), str(round(device.height * .29)),
                       str(device.width // 2), str(round(device.height * .70)), '320')
    device.find('Iron Man', exact=True)
    print('Android preserved an independent person route across Library and returned to its movie with Back.', flush=True)

    open_section(device, 'Media')
    device.open_label('View backdrops 1', exact=True)
    device.find('1 of')
    device.capture(out, 'android-viewer')
    x1, x2, y = (round(device.width * .83), round(device.width * .24), round(device.height * .46))
    device.command('shell', 'input', 'swipe', str(x1), str(y), str(x2), str(y), '260')
    device.find('2 of')
    device.open_label('Zoom in', exact=True)
    device.capture(out, 'android-zoom')
    device.open_label('Fit image', exact=True)
    device.back()
    device.find('Library', exact=True)
    print('Android system Back dismissed the full-screen viewer. Swipe and zoom controls passed.', flush=True)

    device.open_route('/tv/1396')
    device.find('Breaking Bad', exact=True)
    open_section(device, 'Seasons')
    device.open_label('Season 1')
    device.open_label('Pilot')
    device.find('Library', exact=True)
    device.capture(out, 'android-episode')
    device.open_label('Episode stills')
    device.open_label('View stills 1', exact=True)
    device.find('1 of')
    device.capture(out, 'android-episode-viewer')
    device.back()
    device.find('Library', exact=True)
    print('Android TV to season to episode and still gallery passed.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    check(GraphEmulator(args.device), args.out)
