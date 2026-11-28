"""Capture live graph destinations and verify traversal on an isolated emulator."""

import argparse
from pathlib import Path
import re
import shlex
import time

from phase2_android_screenshots import Emulator


class GraphEmulator(Emulator):
    def __init__(self, serial):
        super().__init__(serial)
        dimensions = re.findall(rb"(\d+)x(\d+)", self.command("shell", "wm", "size"))
        self.width, self.height = map(int, dimensions[-1])

    def open_route(self, path):
        self.command("shell", "am", "start", "-W", "-a", "android.intent.action.VIEW",
                     "-d", shlex.quote("cinevault://open" + path))

    def seek(self, label, *, exact=False):
        for index in range(14):
            for node in self.nodes():
                name = " ".join((node.get("text", "") + " " + node.get("content-desc", "")).split())
                if (name.casefold() == label.casefold() if exact else label.casefold() in name.casefold()):
                    return node
            if index < 2:
                time.sleep(.3)
                continue
            x = round(self.width * .62)
            start, end = round(self.height * .75), round(self.height * .39)
            self.command("shell", "input", "swipe", str(x), str(start), str(x), str(end), "350")
        raise TimeoutError(f"Could not locate Android marker {label}")

    def open_label(self, label, *, exact=False):
        self.tap(self.seek(label, exact=exact))


def check(device, out):
    device.open_route("/movie/27205")
    device.find("Inception", exact=True)
    device.capture(out, "android-movie")
    device.open_label("Cast & crew")
    device.seek("Leonardo DiCaprio")
    device.capture(out, "android-cast")
    device.open_label("Leonardo DiCaprio")
    device.find("Biography")
    device.capture(out, "android-person")
    device.open_label("Full filmography")
    device.open_label("Popularity")
    device.find("Highest rated", exact=True)
    device.open_label("Highest rated", exact=True)
    device.open_label("Any vote count")
    device.open_label("1000+ votes", exact=True)
    device.capture(out, "android-filmography")
    device.open_label("Django Unchained")
    device.find("Django Unchained", exact=True)
    device.open_label("Cast & crew")
    device.open_label("Crew", exact=True)
    device.open_label("Quentin Tarantino")
    device.find("Biography")
    device.back()
    device.find("Quentin Tarantino")
    device.back()
    device.seek("Django Unchained")

    device.open_route("/movie/11")
    device.open_label("Star Wars Collection")
    device.find("Films in this collection")
    device.capture(out, "android-collection")
    device.open_label("The Empire Strikes Back")
    device.find("The Empire Strikes Back", exact=True)

    device.open_route("/tv/1396")
    device.find("Breaking Bad", exact=True)
    device.capture(out, "android-series")
    device.open_label("Season 1", exact=True)
    device.find("Pilot")
    device.capture(out, "android-season")
    device.open_label("Pilot")
    device.find("Pilot", exact=True)
    device.capture(out, "android-episode")
    device.open_label("Guest stars")
    device.seek("Steven Michael Quezada")
    device.capture(out, "android-guests")
    device.open_label("Steven Michael Quezada")
    device.find("Biography")
    device.back()
    device.seek("Steven Michael Quezada")
    device.open_label("Episode stills")
    device.seek("View stills 1")
    device.capture(out, "android-stills")
    device.back()
    device.find("Pilot")
    print("Android movie, franchise, episode and system Back chains passed.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    check(GraphEmulator(args.device), args.out)


if __name__ == "__main__":
    main()
