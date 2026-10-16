# /// script
# requires-python = ">=3.12"
# ///
"""Writes the synthetic issue tarball used by the archive parser tests.

    uv run tool/gen_archive_fixture.py

Built with Python's tarfile, independently of the Dart parser, so the
tests check our reader against a real-world writer. Output is
deterministic: fixed timestamps, owners and gzip mtime.
"""

import gzip
import io
import pathlib
import tarfile

OUT = pathlib.Path(__file__).resolve().parent.parent / "test/archive/fixtures/phrack99.tar.gz"
MTIME = 500_000_000  # 1985-11-05; the real archive uses a fixed date too

FILES = {
    "1.txt": (
        b"---\ntitle: Introduction\nauthor: Synthetic Staff\n---\n"
        b"                    ==Phrack Inc.==\n\n"
        b"         Volume Nine, Issue 99, Phile 1 of 3\n"
    ),
    # CP437 body with no front matter: title must fall back to "Phile 2".
    "2.txt": bytes([0xC9, 0xCD, 0xCD, 0xBB, 0x0A, 0xC8, 0xCD, 0xCD, 0xBC, 0x0A]),
    # Sorts after 2.txt numerically, before it as text.
    "10.txt": b"---\ntitle: Loopback\nauthor: \n---\nten\n",
    # Not a phile: must be ignored.
    "phrack-99.pdf": b"%PDF-1.4 not really\n",
}


def add(tar: tarfile.TarFile, name: str, data: bytes) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mtime = MTIME
    info.mode = 0o644
    info.uname = info.gname = "phrack"
    tar.addfile(info, io.BytesIO(data))


raw = io.BytesIO()
with tarfile.open(fileobj=raw, mode="w", format=tarfile.PAX_FORMAT) as tar:
    root = tarfile.TarInfo("./")
    root.type = tarfile.DIRTYPE
    root.mtime = MTIME
    root.mode = 0o755
    tar.addfile(root)
    for name, data in FILES.items():
        add(tar, f"./{name}", data)
    # A name over 100 bytes forces a PAX extended header.
    add(tar, "./" + "x" * 120 + ".txt", b"---\ntitle: Long Name\n---\nlong\n")
    # Symlinks must be skipped, never followed.
    link = tarfile.TarInfo("./3.txt")
    link.type = tarfile.SYMTYPE
    link.linkname = "../../etc/passwd"
    link.mtime = MTIME
    tar.addfile(link)

OUT.parent.mkdir(parents=True, exist_ok=True)
with open(OUT, "wb") as f, gzip.GzipFile(fileobj=f, mode="wb", mtime=0, filename="") as gz:
    gz.write(raw.getvalue())
print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
