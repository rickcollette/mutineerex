#!/usr/bin/env python3
"""Build, validate, tag, push, and publish a Mutineer-eX GitHub release.

Typical use, after committing the release changes on the branch to publish:

    python tools/release.py

The version comes from VERSION and produces tag v<VERSION>.  The script
refuses a dirty tree, non-fast-forward push, conflicting tag, or existing
GitHub release.  Use --dry-run to build/package locally and print the GitHub
mutations without performing them.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "VERSION"
PRODUCT = "Mutineer-eX"
PRODUCT_ID = "mutinrex"


class ReleaseError(RuntimeError):
    pass


def display_command(args: list[str]) -> str:
    if os.name == "nt":
        return subprocess.list2cmdline(args)
    return shlex.join(args)


def run(args: list[str], *, capture: bool = False,
        check: bool = True) -> subprocess.CompletedProcess[str]:
    print("+ " + display_command(args), flush=True)
    result = subprocess.run(
        args, cwd=ROOT, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    if check and result.returncode:
        detail = ""
        if capture:
            detail = (result.stderr or result.stdout or "").strip()
        raise ReleaseError(
            "%s failed with exit code %d%s" %
            (args[0], result.returncode, ": " + detail if detail else "")
        )
    return result


def output(args: list[str]) -> str:
    return run(args, capture=True).stdout.strip()


def read_version() -> str:
    version = VERSION_FILE.read_text(encoding="ascii").strip()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?", version):
        raise ReleaseError("VERSION is not a supported semantic version: %r" % version)
    return version


def github_repo(remote_url: str) -> str:
    """Return OWNER/REPO from an HTTPS, SSH, or scp-like GitHub URL."""
    value = remote_url.strip()
    if value.startswith("git@github.com:"):
        path = value.split(":", 1)[1]
    else:
        parsed = urlparse(value)
        if parsed.hostname != "github.com":
            raise ReleaseError("remote is not on github.com: " + value)
        path = parsed.path.lstrip("/")
    if path.endswith(".git"):
        path = path[:-4]
    if not re.fullmatch(r"[^/\s]+/[^/\s]+", path):
        raise ReleaseError("cannot determine OWNER/REPO from remote: " + value)
    return path


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise ReleaseError("required command is not installed or not on PATH: " + name)


def git_ref_commit(ref: str) -> str | None:
    result = run(
        ["git", "rev-parse", "--verify", "--quiet", ref + "^{commit}"],
        capture=True, check=False,
    )
    if result.returncode == 0:
        return result.stdout.strip()
    if result.returncode == 1:
        return None
    raise ReleaseError("could not inspect git ref " + ref)


def remote_tag_commit(remote: str, tag: str) -> str | None:
    result = output([
        "git", "ls-remote", "--tags", remote,
        "refs/tags/" + tag, "refs/tags/" + tag + "^{}",
    ])
    if not result:
        return None
    refs = {}
    for line in result.splitlines():
        sha, ref = line.split(None, 1)
        refs[ref] = sha
    return refs.get("refs/tags/" + tag + "^{}") or refs.get("refs/tags/" + tag)


def ensure_no_release(repo: str, tag: str) -> None:
    result = run(
        ["gh", "api", "repos/%s/releases/tags/%s" % (repo, tag), "--silent"],
        capture=True, check=False,
    )
    if result.returncode == 0:
        raise ReleaseError("GitHub release already exists for " + tag)
    message = (result.stderr or result.stdout or "").lower()
    if "404" not in message and "not found" not in message:
        raise ReleaseError("could not check for an existing GitHub release: " +
                           message.strip())


def ensure_clean_tree() -> None:
    dirty = output(["git", "status", "--porcelain", "--untracked-files=all"])
    if dirty:
        raise ReleaseError(
            "working tree is not clean; commit or remove these changes before releasing:\n" +
            dirty
        )


def preflight(remote: str, version: str) -> tuple[str, str, str, bool]:
    for tool in ("git", "gh"):
        require_tool(tool)
    root = Path(output(["git", "rev-parse", "--show-toplevel"])).resolve()
    if root != ROOT.resolve():
        raise ReleaseError("script is not running in its own git worktree")
    ensure_clean_tree()
    branch = output(["git", "symbolic-ref", "--quiet", "--short", "HEAD"])
    head = output(["git", "rev-parse", "HEAD"])
    remote_url = output(["git", "remote", "get-url", remote])
    repo = github_repo(remote_url)
    run(["gh", "auth", "status", "--hostname", "github.com"])
    run(["git", "fetch", "--prune", "--tags", remote])

    remote_branch = "refs/remotes/%s/%s" % (remote, branch)
    if git_ref_commit(remote_branch) is not None:
        relation = run(
            ["git", "merge-base", "--is-ancestor", remote_branch, "HEAD"],
            capture=True, check=False,
        )
        if relation.returncode != 0:
            raise ReleaseError(
                "%s/%s is not an ancestor of HEAD; update the branch first" %
                (remote, branch)
            )

    tag = "v" + version
    local_tag = git_ref_commit("refs/tags/" + tag)
    if local_tag is not None and local_tag != head:
        raise ReleaseError("local tag %s points to %s, not HEAD %s" %
                           (tag, local_tag, head))
    published_tag = remote_tag_commit(remote, tag)
    if published_tag is not None and published_tag != head:
        raise ReleaseError("remote tag %s points to %s, not HEAD %s" %
                           (tag, published_tag, head))
    ensure_no_release(repo, tag)
    return branch, head, repo, local_tag is not None


def build_and_test(version: str, skip_runtime_tests: bool) -> tuple[Path, Path]:
    command = [sys.executable, "tools/build_all.py", "--bump", "none"]
    if skip_runtime_tests:
        command.append("--skip-runtime-tests")
    run(command)
    atrs = tuple(
        ROOT / "disk" / ("%s-%s-v%s.atr" % (PRODUCT_ID, platform, version))
        for platform in ("eos", "sdx")
    )
    for atr in atrs:
        if not atr.is_file():
            raise ReleaseError("build did not produce " + str(atr))
    return atrs


def package(version: str, atrs: tuple[Path, Path]) -> tuple[Path, ...]:
    out = ROOT / "release" / ("v" + version)
    out.mkdir(parents=True, exist_ok=True)
    release_atrs = tuple(out / atr.name for atr in atrs)
    checksum = out / "SHA256SUMS.txt"
    for target in (*release_atrs, checksum):
        if target.exists():
            target.unlink()
    lines = []
    for atr, release_atr in zip(atrs, release_atrs):
        shutil.copyfile(atr, release_atr)
        digest = hashlib.sha256(release_atr.read_bytes()).hexdigest()
        lines.append("%s  %s\n" % (digest, release_atr.name))
    checksum.write_text("".join(lines), encoding="ascii", newline="\n")
    print("Release assets:")
    for release_atr in release_atrs:
        print("  " + str(release_atr.relative_to(ROOT)))
    print("  " + str(checksum.relative_to(ROOT)))
    return *release_atrs, checksum


def publish(args: argparse.Namespace, version: str, branch: str,
            expected_head: str, repo: str, local_tag_exists: bool,
            assets: tuple[Path, ...]) -> None:
    tag = "v" + version
    title = "%s %s" % (PRODUCT, version)
    tag_command = ["git", "tag", "--annotate", tag, "--message", title]
    push_command = [
        "git", "push", "--atomic", args.remote, branch, "refs/tags/" + tag,
    ]
    release_command = [
        "gh", "release", "create", tag,
        *(str(asset) for asset in assets),
        "--repo", repo,
        "--verify-tag",
        "--title", title,
        "--fail-on-no-commits",
    ]
    if args.notes_file:
        release_command.extend(["--notes-file", str(args.notes_file.resolve())])
    else:
        release_command.append("--generate-notes")
    if args.draft:
        release_command.append("--draft")
    if args.prerelease:
        release_command.append("--prerelease")

    if args.dry_run:
        print("Dry run; remote mutations not executed:")
        if not local_tag_exists:
            print("+ " + display_command(tag_command))
        print("+ " + display_command(push_command))
        print("+ " + display_command(release_command))
        return

    # Recheck after build/tests so no source mutation can slip into the tag.
    ensure_clean_tree()
    current_head = output(["git", "rev-parse", "HEAD"])
    if current_head != expected_head:
        raise ReleaseError(
            "HEAD changed during release validation (%s -> %s); run again" %
            (expected_head, current_head)
        )
    if not local_tag_exists:
        run(tag_command)
    run(push_command)
    run(release_command)
    url = output([
        "gh", "release", "view", tag, "--repo", repo,
        "--json", "url", "--jq", ".url",
    ])
    print("Published " + url)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--remote", default="origin",
                        help="git remote to push (default: origin)")
    parser.add_argument("--notes-file", type=Path,
                        help="release notes file; otherwise GitHub generates notes")
    parser.add_argument("--draft", action="store_true",
                        help="create a draft GitHub release")
    parser.add_argument("--prerelease", action="store_true",
                        help="mark the GitHub release as a prerelease")
    parser.add_argument("--skip-runtime-tests", action="store_true",
                        help="skip the Altirra/Atari800 runtime suites")
    parser.add_argument("--dry-run", action="store_true",
                        help="build/package but do not tag, push, or publish")
    args = parser.parse_args()
    if args.notes_file and not args.notes_file.is_file():
        parser.error("notes file does not exist: " + str(args.notes_file))
    return args


def main() -> int:
    args = parse_args()
    try:
        version = read_version()
        branch, head, repo, local_tag_exists = preflight(args.remote, version)
        atrs = build_and_test(version, args.skip_runtime_tests)
        assets = package(version, atrs)
        publish(args, version, branch, head, repo, local_tag_exists, assets)
        return 0
    except (OSError, ReleaseError) as exc:
        print("release: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
