# 变更记录

## 0.1.0 — 2026-11-11

首次交付：有界 Intel/MIPS C3D 解析、参数/校准/同步模型、规范 Intel float 写出、裁剪和通道/空间操作、序列与质量/CSV、版本化 JSON 和 CLI。包含三个下游示例、33 个 MoonBit 测试、六组独立参考兼容性用例及四后端 CI。

支持与元数据保留范围见 README；该版本不支持 DEC 与扩展帧号。

## 0.2.0 — 2026-11-25

- 增加 DEC/VAX F-floating（processor 85）读取与写出，并支持 Intel/MIPS/DEC 三种 processor 编码输出。
- 按 POINT/TRIAL 扩展参数确定有效帧区间，支持 C3D 分段标签与校准数组以及头部事件读写。
- 增加基础必需参数与部分 FORCE_PLATFORM/EVENT 参数结构的严格校验；明确该检查不代表完整厂商扩展或官方认证。
- 增补三种 processor 往返、头部事件、VAX 边界、扩展帧协调及分段数组回归测试。
