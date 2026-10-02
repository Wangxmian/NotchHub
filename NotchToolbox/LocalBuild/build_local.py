#!/usr/bin/env python3
"""Build a local arm64 app with Command Line Tools; reuse compiled assets from an installed EasyNotch."""
from pathlib import Path
import argparse, plistlib, subprocess, tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--template', type=Path, default=Path('/Applications/NotchHub.app') if Path('/Applications/NotchHub.app').exists() else Path('/Applications/EasyNotch.app'))
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
source = project / 'NotchToolbox'
output = args.output.resolve()
if output.exists():
    raise SystemExit(f'Output already exists: {output}')
output.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(['ditto', str(args.template), str(output)], check=True)
# Keep the resource catalog and media helper, replace the main executable.
sdk = subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip()
with tempfile.TemporaryDirectory(prefix='easynotch-compile-') as cache:
    command = ['xcrun', 'swiftc', '-O', '-whole-module-optimization', '-swift-version', '5',
               '-default-isolation', 'MainActor', '-enable-upcoming-feature', 'NonisolatedNonsendingByDefault',
               '-enable-upcoming-feature', 'InferIsolatedConformances',
               '-D', 'DIRECT_DISTRIBUTION', '-D', 'LOCAL_CUSTOM', '-module-name', 'NotchToolbox',
               '-sdk', sdk, '-target', 'arm64-apple-macosx13.0', '-module-cache-path', cache,
               '-o', str(output / 'Contents/MacOS/NotchHub')]
    subprocess.run(command + [str(p) for p in sorted(source.rglob('*.swift'))], check=True)
info_path = output / 'Contents/Info.plist'
with info_path.open('rb') as f: info = plistlib.load(f)
old_executable = info.get('CFBundleExecutable', 'EasyNotch')
if old_executable != 'NotchHub':
    old_binary = output / 'Contents/MacOS' / old_executable
    if old_binary.exists(): old_binary.unlink()
info.update(CFBundleShortVersionString='1.2.0', CFBundleVersion='25',
            CFBundleExecutable='NotchHub', CFBundleName='NotchHub', CFBundleDisplayName='NotchHub',
            CFBundleIdentifier='io.github.Wangxmian.NotchHub', CFBundleIconFile='NotchHub',
            NotchHubCredentialService='com.luojie.NotchToolbox')
info.pop('CFBundleIconName', None)
info.pop('EasyNotchLocalCustomization', None)
import shutil
for asset in ['NotchHubLogo.png', 'NotchHub.icns']:
    shutil.copyfile(project.parent / 'assets' / asset, output / 'Contents/Resources' / asset)
for key in list(info):
    if key.startswith('DT') or key.startswith('EASYNOTCH_UMAMI_') or key in ('BuildMachineOSBuild', 'SUFeedURL', 'SUPublicEDKey'):
        del info[key]
with info_path.open('wb') as f: plistlib.dump(info, f)
subprocess.run(['codesign', '--force', '--deep', '--sign', '-', '--entitlements',
                str(source / 'NotchToolbox.entitlements'), str(output)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(output)], check=True)
print(f'Built and verified {output}')
