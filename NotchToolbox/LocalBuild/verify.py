from pathlib import Path
import subprocess, tempfile, sys, shutil
local = Path(__file__).resolve().parent
base = local.parent / 'NotchToolbox'
with tempfile.TemporaryDirectory(prefix='easynotch-regression-') as scratch:
    build = Path(scratch)
    snapshot = build / 'Source'
    shutil.copytree(base, snapshot)
    sources = [str(p) for p in sorted(snapshot.rglob('*.swift')) if p.name != 'NotchToolboxApp.swift']
    args = ['xcrun', 'swiftc', '-swift-version', '5', '-default-isolation', 'MainActor',
            '-enable-upcoming-feature', 'NonisolatedNonsendingByDefault',
            '-enable-upcoming-feature', 'InferIsolatedConformances',
            '-D', 'DIRECT_DISTRIBUTION', '-D', 'LOCAL_CUSTOM',
            '-module-cache-path', str(build/'cache'), '-o', str(build/'Regression')]
    subprocess.run(args + sources + [str(local / (sys.argv[1] if len(sys.argv) > 1 else 'PomodoroRegression.swift'))], check=True)
    subprocess.run([str(build/'Regression'), str(build/'data')], check=True)
