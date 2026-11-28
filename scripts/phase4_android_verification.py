"""Check the personal library in an isolated Android release installation."""

import argparse
from pathlib import Path

from phase3_android_verification import GraphEmulator


def run(device, out):
    device.open_route("/movie/27205")
    device.find("Inception", exact=True)
    device.open_label("Favorite", exact=True)
    device.seek("Favorited", exact=True)
    for _ in range(2):
        device.open_label("Log viewing", exact=True)
        device.find("Viewing date")
        device.open_label("Save viewing", exact=True)
        device.seek("Log viewing", exact=True)
    device.open_route("/library/personal/diary")
    device.find("Inception")
    device.capture(out, "android-diary")

    device.open_route("/tv/1396/season/1/episode/1")
    device.find("Pilot", exact=True)
    device.open_label("Mark watched", exact=True)
    device.seek("Mark unwatched", exact=True)
    device.open_route("/library/personal/progress")
    device.find("Breaking Bad · Season 1")
    device.open_label("Breaking Bad · Season 1")
    device.seek("Next unwatched episode")
    device.capture(out, "android-progress")

    device.open_route("/library/personal/favorites")
    device.find("Inception")
    device.capture(out, "android-favorites")
    device.open_route("/library/personal/data")
    device.find("Save JSON backup")
    device.capture(out, "android-backup")
    device.command("shell", "am", "force-stop", "com.sudheerprajapati.cinevault")
    device.open_route("/library/personal/diary")
    device.find("Inception")
    device.open_route("/library/personal/progress")
    device.find("Breaking Bad · Season 1")
    print("Android diary, favorites, next episode, backup screen and restart passed.", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--out", type=Path, required=True)
    arguments = parser.parse_args()
    arguments.out.mkdir(parents=True, exist_ok=True)
    run(GraphEmulator(arguments.device), arguments.out)
