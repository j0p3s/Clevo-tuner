#!/usr/bin/env python3
"""Build ClevoTune from the sources in src/.

Outputs
  ClevoTune.cmd                 single-file script (committed)
  Language/*.lng                translation files (committed)
  dist/ClevoTune (vX.Y.Z).cmd   release script
  dist/ClevoTune (vX.Y.Z).exe   release launcher (needs the .NET SDK)
  dist/ClevoTune (vX.Y.Z).zip   exe + cmd + Language + README.md

Usage:  python build.py            (everything)
        python build.py --no-exe   (script and language files only)
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'src')
sys.path.insert(0, SRC)
import lang  # noqa: E402

HEADER = r'''<# :
@echo off
setlocal
title ClevoTune
set "CT_SELF=%~f0"
set "CT_ARGS=%*"
fltmc >nul 2>&1 && goto :run
powershell -NoProfile -ExecutionPolicy Bypass -Command "$a=@{FilePath=$env:CT_SELF;Verb='RunAs'}; if($env:CT_ARGS){$a.ArgumentList=$env:CT_ARGS}; Start-Process @a"
exit /b
:run
powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "iex ([IO.File]::ReadAllText($env:CT_SELF))"
exit /b
#>
# ClevoTune - monitor, GPU tuning and EC fan curves for Clevo P775DM3-G (i7-8700K + RTX 3080)
# https://github.com/j0p3s/Clevo-tuner
'''


def read(name):
    with open(os.path.join(SRC, name), encoding='utf-8') as f:
        return f.read()


def build_script():
    cs = read('core.cs')
    # keep the C# source ASCII-only so Windows PowerShell's compiler never depends on file encoding
    cs = ''.join(c if ord(c) < 128 else '\\u%04x' % ord(c) for c in cs)
    xaml = read('main.xaml')
    ps = read('app.ps1')
    tsv = lang.tsv()
    for part in (cs, xaml, tsv):
        assert "\n'@" not in part, 'here-string terminator inside embedded content'
    ps = ps.replace('__LANG_TSV__', tsv).replace('__CORE_CS__', cs).replace('__MAIN_XAML__', xaml)
    ver = re.search(r"\$AppVersion = '([\d.]+)'", ps).group(1)
    out = (HEADER + ps).replace('\r\n', '\n').replace('\n', '\r\n')   # batch needs CRLF
    return ver, out


def write(path, text, bom=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8-sig' if bom else 'utf-8', newline='') as f:
        f.write(text)


def build_exe(ver, script, dist):
    work = os.path.join(ROOT, 'build', 'launcher')
    shutil.rmtree(work, ignore_errors=True)
    shutil.copytree(os.path.join(SRC, 'launcher'), work)
    write(os.path.join(work, 'script.ps1'), script)
    with open(os.path.join(work, 'Launcher.cs.in'), encoding='utf-8') as f:
        write(os.path.join(work, 'Launcher.cs'), f.read().replace('__VERSION__', ver))
    os.remove(os.path.join(work, 'Launcher.cs.in'))
    dotnet = os.environ.get('DOTNET', 'dotnet')
    r = subprocess.run([dotnet, 'build', '-nologo', '-v', 'q', '-c', 'Release', '-o', os.path.join(work, 'out')],
                       cwd=work, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-4000:], r.stderr[-2000:])
        raise SystemExit('exe build failed')
    exe = os.path.join(dist, 'ClevoTune (v%s).exe' % ver)
    shutil.copy(os.path.join(work, 'out', 'ClevoTune.exe'), exe)
    return exe


def main():
    ver, script = build_script()
    dist = os.path.join(ROOT, 'dist')
    os.makedirs(dist, exist_ok=True)
    for old in glob.glob(os.path.join(dist, 'ClevoTune (v*')):
        os.remove(old)

    write(os.path.join(ROOT, 'ClevoTune.cmd'), script)
    cmd = os.path.join(dist, 'ClevoTune (v%s).cmd' % ver)
    write(cmd, script)

    ld = os.path.join(ROOT, 'Language')
    shutil.rmtree(ld, ignore_errors=True)
    for i, (code, _name) in enumerate(lang.FILES):
        write(os.path.join(ld, code + '.lng'), lang.lng_file(i, ver), bom=True)

    files = [cmd]
    if '--no-exe' not in sys.argv:
        files.insert(0, build_exe(ver, script, dist))
        z = os.path.join(dist, 'ClevoTune (v%s).zip' % ver)
        with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            for f in files:
                zf.write(f, os.path.basename(f))
            for f in sorted(glob.glob(os.path.join(ld, '*.lng'))):
                zf.write(f, 'Language/' + os.path.basename(f))
            zf.write(os.path.join(ROOT, 'README.md'), 'README.md')
            zf.write(os.path.join(ROOT, 'CHANGELOG.md'), 'CHANGELOG.md')
        files.append(z)
    print('ClevoTune', ver)
    for f in files:
        print('  ' + os.path.relpath(f, ROOT))


if __name__ == '__main__':
    main()
