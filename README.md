# MoonC3D

用 MoonBit 读取、整理和写出运动捕捉 C3D 二进制数据，保留点与模拟信号的同步关系。模块 `red6667/moonc3d@0.1.0`，MIT 许可证。

面向三类使用者：采集工具开发者把文件解码为校准后的点和模拟样本；数据整理人员裁剪、选择通道、换算单位后写回；分析系统作者提取时间序列、质量摘要和 CSV。三个可运行流程分别见 [导入](examples/ingest/main.mbt)、[整理](examples/edit/main.mbt)、[导出](examples/export/main.mbt)。示例和兼容性样本均为合成数据，未使用真实受试者数据。

## 能力与边界

- 读取 Intel IEEE（84）与 MIPS IEEE（86）C3D，支持 int16/float32 点、带符号和无符号整型模拟数据及浮点模拟数据；解析分组参数、维度、类型、字符串和字节序。
- 校准模拟样本：`(raw - offset) * channel_scale * general_scale`。模拟数组固定为 `[子帧][通道]`，点残差与相机掩码独立解释，负残差表示缺失。
- 检查头部与 POINT/ANALOG 参数一致性、文件和数组预算；随机读取单帧；返回 `C3dError`，不猜测损坏文件的意图。
- 按帧或时间裁剪、通道选择/排序/改名、m/cm/mm 单位转换、右手正交刚体变换；生成轨迹、模拟序列、缺失段与数值摘要。
- 输出规范化 Intel float32 C3D，以及长表 CSV；提供 `moonc3d/1` JSON 宿主桥接和命令行入口。

这是有明确支持边界的交换库。它不提供 DEC/VAX 数值编码、超过传统 16 位帧号的扩展帧、完整厂商参数保真、骨架重定向、信号滤波、力台算法或临床结论。遇到已知扩展帧参数与头部矛盾时拒绝读取。不是官方 C3D 认证实现。

## 环境与安装

验证工具链为 `moonc 0.10.17+093cb8f9c`、`moon 0.1.20261021`，满足 moonc 不低于 0.10.16 的要求。支持 wasm-gc、wasm、js、native；CI 分别执行检查、构建、测试和示例。JS 示例需要 Node.js，native 需要 C 编译器。核心模块只依赖 MoonBit 标准库，无 Python 运行依赖。

在已有 MoonBit 项目中安装精确版本：

```sh
moon add red6667/moonc3d@0.1.0
```

在使用包的 `moon.pkg` 中加入：

```moonbit
import {
  "red6667/moonc3d",
}
```

## 可运行快速开始

下列完整 `main.mbt` 创建一帧数据，写出再读取，检查原始帧号并输出 CSV。将它放进一个可执行包，其 `moon.pkg` 使用上面的 import 并加上 `pkgtype(kind: "executable")`，执行 `moon run . --target js`。

```moonbit
fn main raise {
  let trial : @moonc3d.Trial = {
    first_frame: 7,
    point_rate: 100.0,
    analog_per_frame: 2,
    labels: ["heel"],
    analog_labels: ["Fx"],
    units: "mm",
    metadata: { groups: [], parameters: [] },
    frames: [{
      points: [{ x: 1.5, y: -2.0, z: 3.0, residual: 0.5, cameras: 3 }],
      analog: [[1.0], [2.0]],
    }],
  }
  let bytes = @moonc3d.write(trial, residual_scale=0.5)
  let restored = @moonc3d.read(bytes)
  assert_eq(restored.first_frame, 7)
  assert_eq(restored.analog_series("Fx").samples, [1.0, 2.0])
  println(restored.points_csv())
}
```

从源码仓库直接复现三个完整流程：

```sh
git clone https://github.com/red6667/moonc3d.git
cd moonc3d
moon run examples/ingest --target js
moon run examples/edit --target js
moon run examples/export --target js
```

文件系统由宿主负责：将文件读为 `Bytes` 传入库，把 `write` 返回的 `Bytes` 写入新文件。库不会覆盖磁盘文件。

## 常用 API

| 任务 | API 与结果 |
| --- | --- |
| 查看布局/参数 | `inspect(bytes)`；`layout.metadata.find("POINT", "LABELS")` 后调用 `strings()` |
| 解码全部/单帧 | `read(bytes)`；`read_frame(bytes, index)`，index 从零开始 |
| 裁剪 | `trial.crop(start, end)`，半开区间；`time_window(start_seconds, end_seconds)` |
| 选取或重排 | `trial.select(points=["heel"], analog=["Fx"])`，空列表表示删除该类通道 |
| 重命名 | `trial.rename(points=["left_heel"], analog=["force_x"])`，数量必须匹配 |
| 空间变换 | `convert_units("m")`；`transform(rotation9, translation3)`，旋转行优先且须右手正交 |
| 时间序列 | `marker_series(label)`；`analog_series(label)` |
| 质量与导出 | `marker_quality()`、`analog_quality()`、`points_csv(max_rows=10000)`、`analog_csv()` |
| 写回 | `write(trial, residual_scale=0.5)`，返回规范化 C3D 字节 |

结构、完整签名和错误类型见 [生成接口](pkg.generated.mbti)。`Trial`、`Frame` 等公开字段便于宿主接入；数组可变，调用方应避免共享可变别名及并发修改，修改后用 `validate()` 检查。

时间戳从当前 Trial 第一帧的 0 秒开始，保留 C3D `first_frame` 作为来源帧号。裁剪后的第一帧重新从 0 秒计时；模拟采样率为 `point_rate * analog_per_frame`，子帧时间依次递增。

## 写出精度和元数据策略

输出始终为 Intel 小端 float32，包含 512 字节块填充。内存模型使用 Double，但往返存在 float32 舍入。读取整型坐标按 POINT:SCALE 缩放；浮点坐标保留原值。残差来自 packed 低 8 位乘绝对 scale；相机为 7 位掩码；缺失点写入负 packed 字。

写出时 `residual_scale` 默认为 1；例如残差 0.5 需要传 0.5，mm 转 m 后可传 0.0005。scale 会先规范化为 float32。有效残差必须在 0..255 个 scale 单位内，并接近整数（编码单位容差 1e-5）；超界或不能表示时返回错误，不悄悄粗量化。缺失点必须 `residual=-1, cameras=0`；空间转换不改其 XYZ。

写出会重建 POINT 和 ANALOG 核心参数，使用已校准模拟值与单位校准参数。舍弃旧 POINT、ANALOG、EVENT、TRIAL、FORCE_PLATFORM 组，防止裁剪后引用失效；因此 ANALOG 原单位、事件、力台、厂商附加字段不会保留。其余独立组经类型/维度/名称/预算校验后保留，MIPS 数值转小端。不保证原文件逐字节往返。写出最多 255 个点和 255 个模拟通道，读取预算较宽。

## JSON 与命令行

构建并运行 Node CLI：

```sh
moon build --target js
node _build/js/debug/build/cmd/main/main.js '{"schema":"moonc3d/1","op":"read","hex":"..."}'
```

这里 `...` 必须替换成真实 C3D 的十六进制字符串。一个实际读取仓库 fixture 的完整命令（跨 shell）：

```sh
python scripts/cli_smoke.py
```

CLI 接收一个 JSON 参数；Windows 参数长度有限，大文件应使用库或 `process_json(request)` 宿主 API。`read` 返回结构化 Trial JSON；`rewrite` 返回 `{ "hex": "..." }`，可附 `residual_scale`；`points_csv` 和 `analog_csv` 返回 CSV 字符串。成功外层为 `{ "schema": "moonc3d/1", "result": ... }`，CLI 失败输出 `{ "error": "..." }` 并以非零状态退出。库 API 失败抛出 `C3dError`。拒绝未知字段、重复键及未知 schema/op。JSON 结果用于读取/导出，不提供 JSON->Trial 任意对象重建。

## 安全与资源预算

`Limits::default()`：64 MiB 输入、65535 帧、1024 点、1024 模拟通道、4000000 样本值预算、4096 元数据条目。可传更小的 `limits`，自定义上限也接受硬性范围检查。读取全部会为对象/数组额外分配内存；输入字节预算不是总堆上限，hex/JSON/CSV 还有副本。`read_frame` 校验整体数据布局但仅解码目标帧。

CSV 默认上限 1000000 行，可用 `max_rows` 降低。参数文本限 ASCII，名称大小写标准化比较，不支持 Unicode 厂商标签。非有限数、无效维度、重复标签、不完整数据和矛盾采样关系返回错误。处理不可信输入仍应由宿主加进程内存/超时限制，详见 [安全边界](SECURITY.md)。

## 检查与复现

```sh
moon info --target all
moon fmt --check
moon check --deny-warn --target all
moon test --deny-warn --target wasm-gc
moon test --deny-warn --target wasm
moon test --deny-warn --target js
moon test --deny-warn --target native
moon build --deny-warn --target js
python scripts/cli_smoke.py
python -m pip install numpy==1.24.4
python scripts/differential.py
python scripts/audit.py
```

最后两项中的差分测试需要网络获取固定提交的 py-c3d，并逐文件校验 SHA256；也可 `--reference-source /path/to/pinned/c3d` 离线运行，仍验证摘要。Python 仅用于开发验证。CI 覆盖四个后端的 check/test/build 和三个示例；JS job 另验独立兼容性、进程协议与源码审计。

33 个 MoonBit 测试覆盖主要路径、损坏输入和 640 次确定性单字节变异。6 组独立对照为 Intel/MIPS × signed int/float/unsigned int，验证非默认模拟校准与 Moon 写出后由 py-c3d 反读，比较容差 1e-6。MIPS fixture 来自独立 Python 字节序转换，并非真实 MIPS 硬件采集。未测声明外的所有 C3D 变体，也未做真实设备兼容率、覆盖率或性能提升声明。详见 [验收方法](docs/competition/acceptance.md)、[语义查重](docs/competition/duplicate-check.md)、[架构](ARCHITECTURE.md)。

## 许可证、参考与 AI 使用

原创 MoonBit 实现采用 [MIT](LICENSE)。格式依据 [C3D 官方文档](https://www.c3d.org/HTML/default.htm)，行为对照为 [py-c3d](https://github.com/EmbodiedCognition/py-c3d) 的固定提交，来源、MIT 许可和 fixture 派生说明见 [第三方归属](THIRD_PARTY.md)。py-c3d 不作为运行时依赖；不把本项目描述为其完整移植。实现和文档由 AI 编程助手参与完成，实际命令验证及限制见 [AI 使用说明](AI_USE.md)。
