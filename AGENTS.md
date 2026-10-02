# NotchHub development workflow

- After every successful verification, immediately back up the exact tested source and record what passed. A Git push alone is not a separate backup.
- Local regression scripts capture the working tree before compilation and automatically archive it after success. Never substitute newer source for the tested snapshot.
- After manual UI or other checks, run `python3 scripts/backup_verified.py --label <passed-check> --evidence <record-path-or-url>` immediately while the source still matches the tested version.
- Backups contain `source.zip`, `history.bundle`, `verification.json` and restoration instructions. Default local destination is the sibling `NotchHub-代码备份` directory, outside this repository.
- Do not include personal clipboard history, credentials, local preferences or app binaries in source backups. Keep backup directories and build logs out of Git.
- Name the verification scope precisely. A passing unit test or UI check does not imply all Maccy parity or release acceptance checks passed.
- Keep only the installed application as a visible app entry. Use temporary build directories and compressed backups; retain a single current preview installer.
