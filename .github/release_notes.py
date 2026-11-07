"""Release notes for a version: the header below plus that version's CHANGELOG.md section."""
import re
import sys

ver = sys.argv[1]
text = open('CHANGELOG.md', encoding='utf-8').read()
m = re.search(r'^## \[' + re.escape(ver) + r'\][^\n]*\n(.*?)(?=^## \[|^\[|\Z)', text, re.S | re.M)
changes = m.group(1).strip() if m else '_See CHANGELOG.md._'

print(f"""Monitor, GPU tuning and EC fan curves for the **Clevo P775DM3-G** (i7-8700K + RTX 3080 Laptop GPU).

### Download
- **`ClevoTune.v{ver}.zip`** (recommended): contains `ClevoTune (v{ver}).exe`, `ClevoTune (v{ver}).cmd`, the `Language` folder, `README.md` and `CHANGELOG.md`
- `ClevoTune.v{ver}.exe`: the program on its own (asks for administrator, no console window)
- `ClevoTune.v{ver}.cmd`: the same program as a script

Extract the zip to a permanent folder and run `ClevoTune (v{ver}).exe`. On the first start ClevoTune installs the signed PawnIO driver and its modules and downloads mVolt+ into a `mVolt+` folder next to the program. If Windows blocks the zip, open its **Properties** and tick **Unblock**.

### Changes in {ver}
{changes}

Full history: [CHANGELOG.md](https://github.com/j0p3s/Clevo-tuner/blob/main/CHANGELOG.md) · Documentation: [README.md](https://github.com/j0p3s/Clevo-tuner#readme)

> ClevoTune writes to the embedded controller and changes GPU settings. Use it at your own risk.""")
