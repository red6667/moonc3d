# 架构与不变量

数据流为 Bytes -> 有界 Cursor -> Header/Metadata -> Layout -> Frame/Trial -> 操作/导出。核心不访问网络和磁盘，宿主承担 I/O。包接口由 `moon info` 生成。

| 层 | 源码 | 约束 |
| --- | --- | --- |
| 二进制 | binary/header | 字节序、有符号值、边界、有限数、资源上限 |
| 元数据 | parameter/metadata_reader/layout | linked offset、forward group、维度、POINT/ANALOG 与头部一致 |
| 解码 | point_reader/reader | 残差相机打包、模拟校准、同步子帧 |
| 模型 | model | 帧宽固定、标签唯一、缺失残差约定 |
| 写出 | metadata_validation/metadata_writer/writer | 元数据校验、规范 float32、小端、512 字节填充 |
| 操作 | crop/channels/spatial | 同步裁剪、确定重排、单位和右手刚体变换 |
| 分析 | series/quality/csv | 时间基准、缺失统计、长表与行数预算 |
| 宿主 | protocol 和 cmd/main | 有界 JSON/hex、版本协议、CLI 退出码 |

模拟值模型是物理校准后的 Double，不再保留每个通道原始整数。写出重建单位校准参数；它是语义交换，不是无损二进制编辑。独立组保留并校验，涉及索引/事件的标准组丢弃，完整策略见 README。

公开结构含可变数组。操作返回新 Trial 但不能把所有字段当作深拷贝保证；调用方避免共享可变别名。坐标、残差与模拟值均需有限数。浮点输出是 IEEE float32，残差有显式可表示性约束。

检查和运行边界分别通过四后端 CI 验证；固定 Python 参考是开发时 oracle，运行时仅标准库。fixture 是合成数据，不含个人资料。
