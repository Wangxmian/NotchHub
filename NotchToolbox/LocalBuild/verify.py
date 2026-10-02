from pathlib import Path
import subprocess, tempfile
local = Path(__file__).resolve().parent
base = local.parent / 'NotchToolbox'
with tempfile.TemporaryDirectory(prefix='easynotch-regression-') as scratch:
    build = Path(scratch)
    sources = [str(p) for p in sorted(base.rglob('*.swift')) if p.name != 'NotchToolboxApp.swift']
    args = ['xcrun', 'swiftc', '-swift-version', '5', '-default-isolation', 'MainActor',
            '-enable-upcoming-feature', 'NonisolatedNonsendingByDefault',
            '-enable-upcoming-feature', 'InferIsolatedConformances',
            '-D', 'DIRECT_DISTRIBUTION', '-D', 'LOCAL_CUSTOM',
            '-module-cache-path', str(build/'cache'), '-o', str(build/'Regression')]
    subprocess.run(args + sources + [str(local/'PomodoroRegression.swift')], check=True)
    subprocess.run([str(build/'Regression'), str(build/'data')], check=True)
