# 来源与许可

MoonBit 核心实现为本项目新编写，运行时依赖 MoonBit core。数据语义参考 C3D 官方格式文档 https://www.c3d.org/HTML/default.htm ，不复制其说明文本，也不声称官方认可。

独立验证使用 EmbodiedCognition/py-c3d（MIT），固定提交 `b3060462bf3566f69de76a9d3f915073c41dc8a7`，https://github.com/EmbodiedCognition/py-c3d/tree/b3060462bf3566f69de76a9d3f915073c41dc8a7 。其许可证保留在 `third-party/py-c3d-LICENSE.txt`；源码不随本库作为运行依赖，开发脚本按 `scripts/reference-lock.json` 中的 SHA256 下载或读取离线原文件。

六个 fixtures/*.hex 是 `scripts/differential.py` 调用该固定 Writer 生成的合成数据，MIPS 变体通过独立 Python 字节序转换生成。README 披露该测试来源和范围。NumPy 1.24.4 用于开发对比，不是核心依赖，不打包其源码。本项目不是 py-c3d 的完整移植，不复制第三方测试数据或其他 MoonBit 项目的实现。
