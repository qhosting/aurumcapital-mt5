"""Local regression checks. This is NOT the MetaEditor compiler or Strategy Tester."""
import ast
import subprocess
import sys
import tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for folder in ('tools','tests','scratch'):
    for p in (root/folder).glob('*.py'):
        ast.parse(p.read_text(encoding='utf-8'),filename=str(p))
subprocess.run([sys.executable,'-m','unittest','discover','-s','tests','-v'],cwd=root,check=True)
with tempfile.TemporaryDirectory() as temp:
    exe=str(Path(temp)/'math')
    subprocess.run(['c++','-std=c++17','-Wall','-Wextra','-Werror','tests/test_math.cpp','-o',exe],cwd=root,check=True)
    subprocess.run([exe],check=True)
print('PASS: Python and shared math. MQL5/Pine compilation and broker integration remain native checks.')
