"""Exercise the public command contract on a real process, including exit codes."""
import json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CLI=ROOT/"_build/js/debug/build/cmd/main/main.js"
hex_data=(ROOT/"fixtures/integer-intel.hex").read_text().strip()
for op in ["read","rewrite","points_csv","analog_csv"]:
 request=json.dumps(dict(schema="moonc3d/1",op=op,hex=hex_data,residual_scale=0.5))
 r=subprocess.run(["node",str(CLI),request],capture_output=True,encoding="utf-8")
 assert r.returncode==0,r.stderr
 response=json.loads(r.stdout)
 assert response["schema"]=="moonc3d/1" and "result" in response
for request in ['{}','{"schema":"moonc3d/2"}','{"schema":"a","schema":"b"}']:
 r=subprocess.run(["node",str(CLI),request],capture_output=True,encoding="utf-8")
 assert r.returncode!=0
 assert "error" in json.loads(r.stdout)
r=subprocess.run(["node",str(CLI)],capture_output=True,encoding="utf-8")
assert r.returncode!=0 and "error" in json.loads(r.stdout)
print("CLI: four successful operations and four failure contracts passed")
