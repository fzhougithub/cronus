#!/bin/bash
if [ $# -ne 2 ]; then
    echo "用法: $0 <输入SQL文件> <输出清理后的文件>"
    exit 1
fi

# 过滤规则：
# 1. 注释掉 REPLICA IDENTITY 相关的 ALTER TABLE 语句
# 2. 保留其他所有语句
sed -e '/ALTER TABLE.*REPLICA IDENTITY/d' "$1" > "$2"

echo "清理完成！输出文件：$2"
