"""Independent checks against a pinned MIT reference; fixtures are synthetic."""
import argparse, hashlib, importlib, io, json, struct, subprocess, sys, tempfile, urllib.request
from pathlib import Path
import numpy as np
ROOT = Path(__file__).resolve().parents[1]

def load_reference(directory, cache=None):
    lock = json.loads((ROOT / "scripts/reference-lock.json").read_text())
    package = Path(directory) / "c3d"
    package.mkdir()
    for filename, expected in lock["sha256"].items():
        url = "https://raw.githubusercontent.com/{}/{}/c3d/{}".format(lock["repository"], lock["commit"], filename)
        content = (Path(cache) / filename).read_bytes() if cache else urllib.request.urlopen(url, timeout=30).read()
        assert hashlib.sha256(content).hexdigest() == expected, "reference digest mismatch"
        (package / filename).write_bytes(content)
    sys.path.insert(0, directory)
    return importlib.import_module("c3d")

def invoke(data, op="read", scale=0.5):
    request = dict(schema="moonc3d/1", op=op, hex=data.hex(), residual_scale=scale)
    executable = ROOT / "_build/js/debug/build/cmd/main/main.js"
    result = subprocess.run(["node", str(executable), json.dumps(request, separators=(",", ":"))],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, encoding="utf-8")
    value = json.loads(result.stdout)
    assert "error" not in value, value
    return value["result"]

def reference_frames(c3d, data):
    reader = c3d.Reader(io.BytesIO(data))
    frames = list(reader.read_frames(copy=True, camera_sum=False))
    return reader, frames

def make_fixture(c3d, floating):
    w = c3d.Writer(point_rate=100., analog_rate=200., point_scale=-0.5 if floating else 0.5, gen_scale=0.25)
    w.set_point_labels(["heel", "toe"])
    w.set_analog_labels(["Fx", "EMG"])
    w.set_analog_scales([0.5, -2.])
    w.set_analog_offsets([100, -20])
    w.set_start_frame(7)
    frames = []
    for i in range(3):
        points = np.array([[1.5+i, -2., 3., 1.5, 3.], [10., 20., 30., -1. if i == 1 else 2., 0. if i == 1 else 9.]])
        analog = np.array([[1.+i, 2.+i], [3.+i, 4.+i]])
        frames.append((points, analog))
    pairs = np.empty((len(frames), 2), dtype=object)
    for i, (points, analog) in enumerate(frames):
        pairs[i, 0], pairs[i, 1] = points, analog
    w.add_frames(pairs)
    out = io.BytesIO()
    w.write(out)
    return out.getvalue()

def to_mips(data):
    # Independent structural conversion of header, parameter and frame numeric fields.
    b = bytearray(data)
    for start, width in [(2,2),(4,2),(6,2),(8,2),(10,2),(12,4),(16,2),(18,2),(20,4)]:
        b[start:start+width] = data[start:start+width][::-1]
    base = (data[0]-1)*512
    b[base+3] = 86
    pos = base+4
    while data[pos] and data[pos+1]:
        size, gid = struct.unpack_from("bb", data, pos)
        offset_pos = pos+2+abs(size)
        offset = struct.unpack_from("<H", data, offset_pos)[0]
        b[offset_pos:offset_pos+2] = data[offset_pos:offset_pos+2][::-1]
        if gid > 0:
            width, ndim = struct.unpack_from("bB", data, offset_pos+2)
            count = 1
            for d in data[offset_pos+4:offset_pos+4+ndim]: count *= d
            start = offset_pos+4+ndim
            if width in (2,4):
                for k in range(count):
                    a = start+k*width
                    b[a:a+width] = data[a:a+width][::-1]
        if not offset: break
        pos = offset_pos+offset
    data_start = (struct.unpack_from("<H",data,16)[0]-1)*512
    width = 4 if struct.unpack_from("<f",data,12)[0]<0 else 2
    points, analog, first, last = struct.unpack_from("<HHHH",data,2)
    count = (last-first+1)*(points*4+analog)
    for k in range(count):
        a = data_start+k*width
        b[a:a+width] = data[a:a+width][::-1]
    return bytes(b)

def compare(c3d, data):
    reader, frames = reference_frames(c3d,data)
    own = invoke(data)
    assert own["first_frame"] == 7
    assert own["labels"] == ["heel", "toe"]
    assert own["analog_labels"] == ["Fx", "EMG"]
    assert own["analog_per_frame"] == 2
    assert len(own["frames"]) == len(frames) == 3
    for actual, (number, points, analog) in zip(own["frames"],frames):
        mine = np.array(actual["points"])
        valid = points[:,3]>=0
        np.testing.assert_allclose(mine[valid], points[valid], rtol=0, atol=1e-6)
        np.testing.assert_array_equal(mine[~valid,3], -1)
        np.testing.assert_allclose(actual["analog"], analog.T, rtol=0, atol=1e-6)
    output = bytes.fromhex(invoke(data, "rewrite")["hex"])
    rewritten, after = reference_frames(c3d,output)
    for (_, before_p, before_a), (_, after_p, after_a) in zip(frames,after):
        valid = before_p[:,3]>=0
        np.testing.assert_allclose(after_p[valid],before_p[valid],rtol=0,atol=1e-6)
        np.testing.assert_array_equal(after_p[~valid,3],-1)
        np.testing.assert_allclose(after_a,before_a,rtol=0,atol=1e-6)
    assert rewritten.first_frame == reader.first_frame
    assert rewritten.point_rate == reader.point_rate
    return output

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--emit-fixtures", action="store_true")
    parser.add_argument("--reference-source", help="Optional offline directory; pinned hashes are still required")
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="moonc3d-reference-") as tmp:
        c3d=load_reference(tmp, args.reference_source)
        results=[]
        for floating in (False, True):
            intel=make_fixture(c3d,floating)
            for endian,data in [("intel",intel),("mips",to_mips(intel))]:
                compare(c3d,data)
                name=("float" if floating else "integer")+"-"+endian
                results.append(dict(case=name,input_sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),status="pass"))
                if args.emit_fixtures:
                    dest=ROOT/"fixtures";dest.mkdir(exist_ok=True)
                    (dest/(name+".hex")).write_text(data.hex()+"\n")
        print(json.dumps(dict(reference=c3d.__version__,cases=results,roundtrip="independent reader passed",tolerance=1e-6),indent=2))
if __name__=="__main__": main()
