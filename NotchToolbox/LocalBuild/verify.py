from pathlib import Path
import subprocess, tempfile, sys
repo = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(repo / "scripts"))
from backup_verified import capture_repository, archive_verified
local = Path(__file__).resolve().parent
harness = sys.argv[1] if len(sys.argv) > 1 else 'PomodoroRegression.swift'
if harness not in ('PomodoroRegression.swift', 'ClipboardRegression.swift'):
    raise SystemExit('Choose PomodoroRegression.swift or ClipboardRegression.swift')
with tempfile.TemporaryDirectory(prefix='easynotch-regression-') as scratch:
    build = Path(scratch)
    captured = build / 'Repository'
    metadata = capture_repository(repo, captured)
    snapshot = captured / 'NotchToolbox/NotchToolbox'
    sources = [str(p) for p in sorted(snapshot.rglob('*.swift')) if p.name != 'NotchToolboxApp.swift']
    args = ['xcrun', 'swiftc', '-swift-version', '5', '-default-isolation', 'MainActor',
            '-enable-upcoming-feature', 'NonisolatedNonsendingByDefault',
            '-enable-upcoming-feature', 'InferIsolatedConformances',
            '-D', 'DIRECT_DISTRIBUTION', '-D', 'LOCAL_CUSTOM',
            '-module-cache-path', str(build/'cache'), '-o', str(build/'Regression')]
    subprocess.run(args + sources + [str(captured / 'NotchToolbox/LocalBuild' / harness)], check=True)
    subprocess.run([str(build/'Regression'), str(build/'data')], check=True)
    checkpoint = archive_verified(repo, captured, metadata, harness.removesuffix(".swift") + "-passed")
    print(f"Verified source backup: {checkpoint}")
