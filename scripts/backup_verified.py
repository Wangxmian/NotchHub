#!/usr/bin/env python3
"""Archive the exact source snapshot associated with a successful verification."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
from datetime import datetime
from zoneinfo import ZoneInfo
import zipfile


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()


def capture_repository(root: Path, snapshot: Path) -> dict:
    """Capture tracked and non-ignored new files before a test starts."""
    metadata = {'base_commit': git(root, 'rev-parse', 'HEAD'),
                'branch': git(root, 'branch', '--show-current'),
                'working_tree_dirty': bool(git(root, 'status', '--porcelain'))}
    names = subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z',
                                     '--cached', '--others', '--exclude-standard']).split(b'\0')
    snapshot.mkdir(parents=True, exist_ok=True)
    for name in sorted(set(names)):
        if not name:
            continue
        relative = Path(os.fsdecode(name))
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError(f'Unsafe repository path: {relative}')
        source = root / relative
        if not source.is_file() and not source.is_symlink():
            continue  # A deletion in the working tree is part of the snapshot.
        target = snapshot / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target, follow_symlinks=False)
    return metadata


def archive_verified(root: Path, snapshot: Path, metadata: dict, label: str,
                     destination: Path | None = None, evidence: str | None = None) -> Path:
    destination = destination or (Path(os.environ['NOTCHHUB_BACKUP_DIR']) if os.environ.get('NOTCHHUB_BACKUP_DIR') else root.parent / 'NotchHub-代码备份')
    destination.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(ZoneInfo('Asia/Shanghai')).strftime('%Y%m%d-%H%M%S-%f')
    safe_label = re.sub(r'[^\w.-]+', '-', label).strip('-')[:70] or 'verified'
    name = f'{stamp}-{metadata["base_commit"][:7]}-{safe_label}'
    final = destination / name
    pending = destination / ('.pending-' + name)
    pending.mkdir()
    try:
        hashes = {}
        with zipfile.ZipFile(pending / 'source.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(snapshot.rglob('*')):
                relative = path.relative_to(snapshot).as_posix()
                if path.is_symlink():
                    data = os.readlink(path).encode()
                    info = zipfile.ZipInfo(relative)
                    info.create_system = 3
                    info.external_attr = (stat.S_IFLNK | 0o777) << 16
                    archive.writestr(info, data)
                elif path.is_file():
                    data = path.read_bytes()
                    archive.write(path, relative)
                else:
                    continue
                hashes[relative] = hashlib.sha256(data).hexdigest()
        subprocess.run(['git', '-C', str(root), 'bundle', 'create',
                        str(pending / 'history.bundle'), '--all'], check=True, capture_output=True)
        subprocess.run(['git', '-C', str(root), 'bundle', 'verify',
                        str(pending / 'history.bundle')], check=True, capture_output=True)
        with zipfile.ZipFile(pending / 'source.zip') as archive:
            if archive.testzip() is not None:
                raise ValueError('Source archive integrity check failed')
        report = {**metadata, 'verified_at': datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
                  'verification': label, 'evidence': evidence,
                  'ci_run_url': (f'https://github.com/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{os.environ["GITHUB_RUN_ID"]}'
                                 if os.environ.get('GITHUB_RUN_ID') else None),
                  'scope_note': 'Only the stated verification passed; this is not a full release acceptance claim.',
                  'source_sha256': hashlib.sha256((pending / 'source.zip').read_bytes()).hexdigest(),
                  'files': hashes}
        (pending / 'verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        (pending / 'RESTORE.txt').write_text(
            'Restore source: extract source.zip into a new directory.\n'
            'Restore committed history: git clone history.bundle <new-directory>\n'
            'Use separate new directories for source and history. source.zip is the authoritative tested tree.\n'
            'Do not blindly overlay onto an old working tree: files deleted in the tested snapshot would remain.\n'
            'verification.json records the base commit, verification scope and SHA-256 hashes.\n')
        pending.rename(final)
        return final
    except BaseException:
        shutil.rmtree(pending)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True, help='The verification that has already passed.')
    parser.add_argument('--evidence', help='Path or URL of the successful verification evidence.')
    parser.add_argument('--destination', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='notchhub-backup-source-') as temp:
        snapshot = Path(temp) / 'Source'
        metadata = capture_repository(root, snapshot)
        result = archive_verified(root, snapshot, metadata, args.label, args.destination, args.evidence)
    print(f'Verified source backup: {result}')


if __name__ == '__main__':
    main()
