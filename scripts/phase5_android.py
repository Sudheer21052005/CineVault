"""Verify Android document picker round-trips and collect safe native markers."""

import argparse
from datetime import date
import json
from pathlib import Path
import re
import time
from xml.etree import ElementTree

from phase2_android_screenshots import APP, DUMP
from phase3_android_verification import GraphEmulator


class NativeAndroid(GraphEmulator):
    def picker_item(self, label, *, exact=False):
        until = time.monotonic() + 20
        while time.monotonic() < until:
            self.command("shell", "uiautomator", "dump", DUMP)
            xml = ElementTree.fromstring(self.command("exec-out", "cat", DUMP))
            for node in xml.iter("node"):
                if "documentsui" not in node.get("package", ""):
                    continue
                name = " ".join((node.get("content-desc", "") + " " + node.get("text", "")).split())
                name, wanted = name.casefold(), label.casefold()
                if name == wanted if exact else wanted in name:
                    return node.attrib
        raise TimeoutError(f"Android document picker did not display {label}")

    def memory(self):
        dump = self.command("shell", "dumpsys", "meminfo", APP).decode()
        match = re.search(r"TOTAL PSS:\s+(\d+)", dump)
        return int(match[1]) if match else None


def backup_roundtrip(device, out, resume_picker=False):
    if not resume_picker:
        device.open_route("/movie/27205")
        device.find("Inception", exact=True)
        device.open_label("Log viewing", exact=True)
        device.open_label("Save viewing", exact=True)
        device.open_route("/library/personal/data")
        device.open_label("Save JSON backup", exact=True)
    save = device.picker_item("Save", exact=True)
    device.capture(out, "android-save-picker")
    device.tap(save)
    device.find("Backup saved.")
    filename = f"cinevault-library-{date.today().isoformat()}.json"
    file = f"/sdcard/Download/{filename}"
    initial = json.loads(device.command("exec-out", "cat", file))
    assert len(initial["personal"]["diary"]) == 1

    # The device is selected only by an emulator serial. This clears the QA
    # installation while keeping the explicitly exported Downloads file.
    device.command("shell", "pm", "clear", APP)
    restore_backup(device, out, filename)


def restore_backup(device, out, filename, picker_open=False):
    if not picker_open:
        device.open_route("/library/personal/data")
    for index in range(2):
        if not (picker_open and index == 0):
            device.open_label("Restore JSON", exact=True)
        device.tap(device.picker_item(filename, exact=True))
        device.find("Merge this backup")
        device.open_label("Confirm", exact=True)
        device.find("Backup restored.")
        if index == 1:
            device.capture(out, "android-restored")
    device.open_route("/library/personal/diary")
    device.find("Inception")
    assert sum(node.get("text") == "Inception" or node.get("content-desc", "").startswith("Inception")
               for node in device.nodes()) == 1
    print("Android restored the exported JSON twice into a fresh installation and kept one viewing.", flush=True)


def profile(device):
    device.open_route("/discover/now-playing")
    device.find("Films in theatrical release")
    time.sleep(2)
    before = device.memory()
    x, top, bottom = round(device.width * .67), round(device.height * .31), round(device.height * .74)
    for index in range(18):
        start, end = (bottom, top) if index % 6 != 5 else (top, bottom)
        device.command("shell", "input", "swipe", str(x), str(start), str(x), str(end), "450")
    after = device.memory()
    device.open_route("/")
    device.find("Trending this week")
    print(json.dumps({"android_pss_kib": {"before_scroll": before, "after_scroll": after,
                                         "returned_home": device.memory()}}), flush=True)
    lines = device.command("logcat", "-d", "-s", "flutter:I", "*:S").decode(errors="replace")
    markers = []
    for line in lines.splitlines():
        if "CINEVAULT_PERF " not in line:
            continue
        sample = json.loads(line.split("CINEVAULT_PERF ", 1)[1])
        if sample["event"] in {"startupShell", "scrollFrames", "navigation", "libraryOpen"}:
            markers.append(sample)
    print(json.dumps({"android_timing_markers": markers[-85:]}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--profile-only", action="store_true")
    parser.add_argument("--resume-picker", action="store_true")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    target = NativeAndroid(args.device)
    if not args.profile_only:
        backup_roundtrip(target, args.out, args.resume_picker)
    profile(target)
