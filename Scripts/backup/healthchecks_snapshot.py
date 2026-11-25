"""Create an encrypted, consistent snapshot of the live Healthchecks database."""

import argparse
import os
import sqlite3
import subprocess
import tempfile
import time
from contextlib import closing
from pathlib import Path


def snapshot(source: Path) -> bytes:
    """Read SQLite through its online backup API without writing a plaintext copy."""
    deadline = time.monotonic() + 30

    def check_deadline(_status: int, _remaining: int, _total: int) -> None:
        if time.monotonic() > deadline:
            raise TimeoutError("Timed out taking the SQLite snapshot")

    with (
        closing(
            sqlite3.connect(source.resolve().as_uri() + "?mode=ro", uri=True)
        ) as db,
        closing(sqlite3.connect(":memory:")) as copy,
    ):
        db.backup(copy, pages=64, progress=check_deadline)
        if copy.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
            raise ValueError("SQLite snapshot failed its integrity check")
        return copy.serialize()


def encrypt(data: bytes, recipient: Path, output: Path) -> None:
    """Replace the previous encrypted snapshot only after encryption succeeds."""
    output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (
        tempfile.TemporaryDirectory(prefix="healthchecks-gpg-") as keyring,
        tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as encrypted,
    ):
        temporary = Path(encrypted.name)
        try:
            subprocess.run(
                [
                    "gpg",
                    "--no-options",
                    "--batch",
                    "--homedir",
                    keyring,
                    "--recipient-file",
                    str(recipient),
                    "--encrypt",
                ],
                input=data,
                stdout=encrypted,
                stderr=subprocess.DEVNULL,
                check=True,
                timeout=30,
            )
            encrypted.flush()
            if not encrypted.tell():
                raise ValueError("Encryption produced an empty file")
            os.fsync(encrypted.fileno())
            temporary.replace(output)
        finally:
            temporary.unlink(missing_ok=True)


def main() -> None:
    """Snapshot the database and publish only the encrypted artifact."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("recipient", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        encrypt(snapshot(args.source), args.recipient, args.output)
    except (OSError, ValueError, sqlite3.Error, subprocess.SubprocessError) as error:
        parser.exit(1, f"Healthchecks snapshot failed: {type(error).__name__}\n")


if __name__ == "__main__":
    main()
