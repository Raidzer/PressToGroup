"""Build a reproducible PressToGroup release using Python 3.10+ and stdlib."""

import argparse
import hashlib
import io
import os
from pathlib import Path
import re
import tempfile
import zipfile


FILES = (
    "PressToGroup.toc",
    "Locale.lua",
    "Filters.lua",
    "Input.lua",
    "Engine.lua",
    "UI.lua",
    "WoW.lua",
    "Bindings.xml",
    "README.md",
    "README.ru.md",
    "Media/Icon.tga",
    "LICENSE",
)


def build_release(source_root: Path, output_dir: Path) -> tuple[Path, str]:
    source_root = Path(source_root).resolve(strict=True)
    contents = {}
    for name in FILES:
        source = (source_root / name).resolve(strict=True)
        if not source.is_relative_to(source_root) or not source.is_file():
            raise ValueError(f"Release file must be inside the source folder: {name}")
        contents[name] = source.read_bytes()
        if not contents[name]:
            raise ValueError(f"Release file is empty: {name}")

    toc = contents["PressToGroup.toc"].decode("utf-8-sig")
    versions = [line.split(":", 1)[1].strip() for line in toc.splitlines()
                if line.startswith("## Version:")]
    if len(versions) != 1 or not re.fullmatch(
        r"[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)*)?",
        versions[0],
    ):
        raise ValueError("TOC must contain one safe release version")
    version = versions[0]
    toc_files = tuple(line.strip() for line in toc.splitlines()
                      if line.strip() and not line.lstrip().startswith("#"))
    if toc_files != FILES[1:7]:
        raise ValueError("TOC must list the six release Lua files in load order")
    for name in ("README.md", "README.ru.md"):
        if contents[name].decode("utf-8-sig").partition("\n")[0].rstrip("\r") != f"# PressToGroup {version}":
            raise ValueError(f"Version does not match TOC: {name}")
    log_function = re.search(
        r"^function PTG:PrintLog\(\)(.*?)^end\b",
        contents["WoW.lua"].decode("utf-8-sig"), re.MULTILINE | re.DOTALL,
    )
    if not log_function or re.findall(
        r'print\("PressToGroup ([^":\r\n]+): ', log_function[1]
    ) != [version]:
        raise ValueError("PrintLog version does not match TOC: WoW.lua")

    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, data in contents.items():
            entry = zipfile.ZipInfo(f"PressToGroup/{name}", (1980, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data, zipfile.ZIP_DEFLATED, compresslevel=9)
    payload = buffer.getvalue()
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        if archive.namelist() != [f"PressToGroup/{name}" for name in FILES]:
            raise ValueError("Release ZIP file list verification failed")
        for name, data in contents.items():
            if archive.read(f"PressToGroup/{name}") != data:
                raise ValueError(f"Release ZIP content verification failed: {name}")

    digest = hashlib.sha256(payload).hexdigest()
    output_dir = Path(output_dir).resolve()
    archive_path = output_dir / f"PressToGroup-{version}.zip"
    artifacts = {
        archive_path: payload,
        archive_path.with_suffix(".zip.sha256"): f"{digest}  {archive_path.name}\n".encode("ascii"),
    }
    pending = {}
    for path, data in artifacts.items():
        if path.is_symlink() or (path.exists() and (not path.is_file() or path.read_bytes() != data)):
            raise FileExistsError(f"Refusing to replace an existing release artifact: {path.name}")
        if not path.exists():
            pending[path] = data
    output_dir.mkdir(parents=True, exist_ok=True)
    created = []
    publish = os.rename if os.name == "nt" else os.link
    try:
        with tempfile.TemporaryDirectory(prefix=".ptg-package-", dir=output_dir) as staging:
            for path, data in pending.items():
                temporary = Path(staging) / path.name
                temporary.write_bytes(data)
                # Windows rename and POSIX hard links refuse to replace an existing release.
                publish(temporary, path)
                created.append(path)
    except BaseException:
        for path in created:
            path.unlink()
        raise
    return archive_path, digest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("dist"))
    args = parser.parse_args()
    try:
        archive_path, digest = build_release(Path(__file__).resolve().parents[1], args.output)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Package failed: {error}\n")
    print(f"{archive_path}: {len(FILES)} files; SHA256 {digest}")


if __name__ == "__main__":
    main()
