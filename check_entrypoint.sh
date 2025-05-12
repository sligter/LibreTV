#!/bin/sh
# 检查脚本格式
echo "正在检查docker-entrypoint.sh文件格式..."
if grep -q $'\r' docker-entrypoint.sh; then
  echo "警告: 检测到Windows风格的换行符(CRLF)，需要转换为Unix风格(LF)。"
  sed -i 's/\r$//' docker-entrypoint.sh
  echo "转换完成。"
else
  echo "文件格式正确，使用Unix风格换行符(LF)。"
fi

# 设置正确的权限
echo "设置执行权限..."
chmod +x docker-entrypoint.sh
echo "权限设置完成。"

echo "脚本准备就绪，可以进行Docker构建。" 