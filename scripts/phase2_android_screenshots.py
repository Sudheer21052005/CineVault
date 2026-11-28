"""Capture live CineVault screens on an explicitly selected Android emulator."""

import argparse
import io
from pathlib import Path
import re
import subprocess
import time
from xml.etree import ElementTree

from PIL import Image

APP = "com.sudheerprajapati.cinevault"
DUMP = "/sdcard/cinevault-phase2-layout.xml"


class Emulator:
    def __init__(self, serial):
        if not re.fullmatch(r"emulator-\d+", serial):
            raise ValueError("Select an isolated emulator serial")
        self.prefix = ["adb", "-s", serial]

    def command(self, *args):
        return subprocess.check_output(self.prefix + list(args), timeout=25)

    def nodes(self):
        dumped = self.command("shell", "uiautomator", "dump", DUMP)
        if DUMP.encode() not in dumped:
            return []
        tree = ElementTree.fromstring(self.command("exec-out", "cat", DUMP))
        return [node.attrib for node in tree.iter("node") if node.attrib.get("package") == APP]

    def find(self, token, *, exact=False, widget_class=None):
        stop = time.monotonic() + 18
        while time.monotonic() < stop:
            for node in self.nodes():
                if widget_class is not None and node.get("class") != widget_class:
                    continue
                label = " ".join((node.get("content-desc", "") + " " + node.get("text", "")).split())
                if (label.casefold() == token.casefold() if exact
                        else token.casefold() in label.casefold()):
                    return node
        raise TimeoutError(f"Timed out waiting for Android screen marker {token}")

    def open(self):
        self.command("shell", "am", "force-stop", APP)
        self.command("shell", "am", "start", "-W", "-n", APP + "/.MainActivity")
        self.find("View details")

    def tap(self, node):
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", node["bounds"]))
        self.command("shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2))

    def choose(self, label):
        self.tap(self.find(label, exact=True))

    def search(self, title):
        self.choose("Search")
        self.tap(self.find("", widget_class="android.widget.EditText"))
        self.command("shell", "input", "text", title)

    def back(self):
        self.command("shell", "input", "keyevent", "4")

    def dismiss_keyboard(self):
        if b"mInputShown=true" in self.command("shell", "dumpsys", "input_method"):
            self.back()

    def capture(self, out, name):
        time.sleep(.4)
        image = Image.open(io.BytesIO(self.command("exec-out", "screencap", "-p"))).convert("RGB")
        image.thumbnail((570, 1280), Image.Resampling.LANCZOS)
        image.save(out / (name + ".jpg"), quality=90)
        print(name, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    emulator = Emulator(args.device)
    emulator.open()
    emulator.capture(args.out, "android-home")
    emulator.choose("Discover")
    emulator.find("Explore movies")
    emulator.capture(args.out, "android-discover")
    for name, title, marker in (
        ("movies", "Movies", "Browse new releases"),
        ("tv", "TV Shows", "Find your next series"),
        ("now-playing", "Now Playing", "Films in theatrical release"),
    ):
        emulator.choose(title)
        emulator.find(marker)
        emulator.capture(args.out, "android-" + name)
        emulator.choose("Discover")
    emulator.search("Inception")
    emulator.find("Inception 2010")
    emulator.dismiss_keyboard()
    emulator.capture(args.out, "android-search")
    emulator.tap(emulator.find("Inception 2010"))
    emulator.find("Overview")
    emulator.capture(args.out, "android-detail")
    try:
        emulator.choose("Add to watchlist")
    except TimeoutError:
        pass
    emulator.find("Remove from watchlist")
    emulator.back()
    emulator.find("Inception 2010")
    emulator.dismiss_keyboard()
    emulator.choose("Library")
    emulator.find("saved title")
    emulator.capture(args.out, "android-watchlist")
    emulator.choose("Statistics")
    emulator.find("Viewing status")
    emulator.capture(args.out, "android-statistics")


if __name__ == "__main__":
    main()
