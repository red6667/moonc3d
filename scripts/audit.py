"""Reproduce the conservative production source and nonempty history inventory."""
from pathlib import Path
import json,subprocess,re
ROOT=Path(__file__).resolve().parents[1]
def git(*args): return subprocess.check_output(["git",*args],cwd=str(ROOT)).decode("utf-8").strip()
files=[]
for f in sorted(ROOT.glob("*.mbt")):
 if f.name.endswith(("_test.mbt","_wbtest.mbt")): continue
 text=f.read_text(encoding="utf-8")
 files.append(dict(path=f.name,physical_lines=len(text.splitlines()),nonblank_lines=sum(bool(x.strip()) for x in text.splitlines())))
commits=[]
for sha in reversed(git("rev-list","HEAD").splitlines()):
 paths=git("diff-tree","--root","--no-commit-id","--name-only","-r",sha).splitlines()
 if paths: commits.append(dict(sha=sha,subject=git("show","-s","--format=%s",sha),paths=paths))
count=sum(x["physical_lines"] for x in files)
assert count>=1500,("insufficient substantive production lines",count)
assert len(commits)>=20,("insufficient nonempty history",len(commits))
tests=sum(len(re.findall(r'^test "',f.read_text(encoding="utf-8"),re.M)) for f in ROOT.glob("*_test.mbt"))+sum(len(re.findall(r'^test "',f.read_text(encoding="utf-8"),re.M)) for f in ROOT.glob("*_wbtest.mbt"))
print(json.dumps(dict(commit=git("rev-parse","HEAD"),production_physical_lines=count,production_files=files,test_blocks=tests,nonempty_commits=commits),indent=2))
