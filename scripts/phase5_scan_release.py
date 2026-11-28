"""Check the Phase 5 patch and distributable artifacts without printing secrets."""

import argparse
from pathlib import Path, PurePosixPath
import re
import subprocess
from zipfile import is_zipfile, ZipFile


BASE = "63ef4abe1633e55a5c8f10da775fbd6ba27e640d"


def git(*args):
    return subprocess.check_output(["git", *args])


def credential_literals():
    local = Path(".env")
    if not local.is_file():
        return ()
    match = re.search(rb"(?m)^\s*TMDB_API_KEY\s*=\s*([^\r\n]+)", local.read_bytes())
    if not match:
        return ()
    value = match[1].decode("utf-8").strip().strip("\"'")
    return tuple(value.encode(mode) for mode in ("utf-8", "utf-16le", "utf-16be")) if len(value) >= 16 else ()


def environment_path(path):
    name = PurePosixPath(str(path).replace("\\", "/")).name.lower()
    return (name.startswith(".env") and name != ".env.example") or name == "key.properties"


def scan_stream(stream, keys, label):
    overlap = max((len(key) for key in keys), default=1) - 1
    tail = b""
    while block := stream.read(1024 * 1024):
        window = tail + block
        if any(key in window for key in keys):
            raise SystemExit(f"Local credential detected in {label}")
        tail = window[-overlap:] if overlap else b""


def scan_artifact(path, keys):
    if environment_path(path):
        raise SystemExit(f"Environment or signing configuration found in {path}")
    if is_zipfile(path):
        with ZipFile(path) as bundle:
            for member in bundle.infolist():
                if environment_path(member.filename):
                    raise SystemExit(f"Environment or signing configuration found in {path.name}")
                if not member.is_dir():
                    with bundle.open(member) as stream:
                        scan_stream(stream, keys, f"{path.name}/{member.filename}")
    else:
        with path.open("rb") as stream:
            scan_stream(stream, keys, path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", nargs="*", type=Path)
    args = parser.parse_args()
    keys = credential_literals()
    patch = git("log", "-p", "--binary", f"{BASE}..HEAD") + git("diff", "--cached", "--binary")
    paths = git("ls-files", "-z").decode().split("\0")
    assignment = rb"(?im)^\+[^\r\n]*(?:api_key|bearer|TMDB_API_KEY)[ =:\"'\x27]+[A-Za-z0-9_-]{28,}"
    if any(environment_path(path) for path in paths) or any(key in patch for key in keys) or re.search(assignment, patch):
        raise SystemExit("Credential or signing configuration detected in Git input")
    for root in args.artifacts:
        if not root.exists():
            raise SystemExit(f"Artifact path does not exist: {root}")
        targets = root.rglob("*") if root.is_dir() else [root]
        count = 0
        for path in targets:
            if path.is_file():
                scan_artifact(path, keys)
                count += 1
        if count == 0:
            raise SystemExit(f"No release files found: {root}")
        print(f"Scanned {count} release file(s) under {root}")
    print("Phase 5 Git credential checks passed")


if __name__ == "__main__":
    main()
