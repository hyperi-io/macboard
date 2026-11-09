#!/usr/bin/env python3
"""Install or remove macboard's zsh bindings and the ~/.zshrc line that sources them.

`install <repo>` copies shell/macboard.zsh to ~/.config/macboard/ and sources that copy,
so moving or deleting the clone cannot break new shells. A legacy line sourcing
<clone>/shell/macboard.zsh is replaced where it sits. ~/.zshrc is backed up only when
it changes, and its bytes are kept exactly apart from the macboard lines.
"""

import argparse
import os
import re
import shutil
import sys
import tempfile
import time
from pathlib import Path

DEST = Path.home() / ".config" / "macboard" / "macboard.zsh"
ZSHRC = Path.home() / ".zshrc"
COMMENT = "# macboard: PC-style word/line navigation at the zsh prompt"
# zsh expands $HOME when it reads the line, and the -f test keeps a missing file silent.
SOURCE_LINE = (
    '[ -f "$HOME/.config/macboard/macboard.zsh" ] && '
    'source "$HOME/.config/macboard/macboard.zsh"'
)
# Older installers wrote `source <clone>/shell/macboard.zsh`, quoted or not.
LEGACY_SOURCE = re.compile(r"""^(source|\.)\s+["']?\S*/shell/macboard\.zsh["']?$""")


def _is_source(line: str) -> bool:
    stripped = line.strip()
    return stripped == SOURCE_LINE or LEGACY_SOURCE.match(stripped) is not None


def _is_comment(line: str) -> bool:
    return line.strip() == COMMENT


def _read_zshrc() -> list[str]:
    if not ZSHRC.exists():
        return []
    # surrogateescape round-trips non-UTF-8 bytes, and split("\n") leaves \f, \v
    # and friends inside their line where splitlines() would break on them.
    text = ZSHRC.read_bytes().decode("utf-8", errors="surrogateescape")
    return text.removesuffix("\n").split("\n") if text else []


def _write_zshrc(lines: list[str], backup_tag: str) -> None:
    target = ZSHRC.resolve()  # write through a dotfiles-manager symlink, not over it
    if target.exists():
        stamp = time.strftime("%Y%m%d-%H%M%S")
        shutil.copy2(target, ZSHRC.with_name(f".zshrc.{backup_tag}-{stamp}"))
    text = "\n".join(lines) + "\n" if lines else ""
    # Temp file + rename so an interrupt never leaves a truncated rc.
    fd, tmp = tempfile.mkstemp(dir=target.parent, prefix=".zshrc.macboard-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(text.encode("utf-8", errors="surrogateescape"))
        if target.exists():
            shutil.copymode(target, tmp)
        os.replace(tmp, target)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def _with_source_line(lines: list[str]) -> list[str]:
    """Return lines with one current source line, at the first old one's position."""
    out: list[str] = []
    placed = False
    for line in lines:
        if _is_comment(line):
            continue
        if not _is_source(line):
            out.append(line)
            continue
        if not placed:
            indent = line[: len(line) - len(line.lstrip())]
            out += [indent + COMMENT, indent + SOURCE_LINE]
            placed = True
    if not placed:
        while out and not out[-1].strip():
            out.pop()
        out += ([""] if out else []) + [COMMENT, SOURCE_LINE]
    return out


def install(repo: Path) -> None:
    """Copy the bindings out of the clone and point ~/.zshrc at the copy."""
    src = repo / "shell" / "macboard.zsh"
    DEST.parent.mkdir(parents=True, exist_ok=True)
    if not DEST.exists() or DEST.read_bytes() != src.read_bytes():
        shutil.copyfile(src, DEST)
        print(f"Installed shell bindings to {DEST}.")

    lines = _read_zshrc()
    wanted = _with_source_line(lines)
    if wanted == lines:
        print("~/.zshrc already sources macboard.zsh; leaving as is.")
        return
    _write_zshrc(wanted, "macboard-backup")
    print(f"~/.zshrc now sources {DEST} (open a new terminal to apply).")


def uninstall() -> None:
    """Remove the macboard lines from ~/.zshrc and delete the installed copy."""
    lines = _read_zshrc()
    kept = [line for line in lines if not (_is_source(line) or _is_comment(line))]
    if kept != lines:
        _write_zshrc(kept, "macboard-preuninstall")
        print("Removed macboard source line from ~/.zshrc.")
    DEST.unlink(missing_ok=True)
    if DEST.parent.is_dir() and not any(DEST.parent.iterdir()):
        DEST.parent.rmdir()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("install").add_argument("repo", type=Path)
    sub.add_parser("uninstall")
    args = parser.parse_args()
    if args.action == "install":
        install(args.repo)
    else:
        uninstall()
    return 0


if __name__ == "__main__":
    sys.exit(main())
