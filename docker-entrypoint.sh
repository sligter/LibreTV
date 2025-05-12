#!/bin/sh
set -e

# 调试输出
echo "=== 环境变量检测 ==="
echo "PASSWORD变量存在性: $(if [ -n "$PASSWORD" ]; then echo "是"; else echo "否"; fi)"
echo "PASSWORD值长度: $(echo -n "$PASSWORD" | wc -c)"
echo "PASSWORD首字符: $(echo "$PASSWORD" | cut -c1)"
echo "====================="

# 确保PASSWORD指向正确的变量
PASS_VALUE="$PASSWORD"

# 简化版本的密码检测逻辑
if [ -n "$PASS_VALUE" ]; then
  echo "检测到PASSWORD环境变量，值为: ${PASS_VALUE:0:1}*****"
  
  # 直接计算密码哈希 - 不考虑已经是哈希的情况
  echo "计算密码哈希值..."
  PASSWORD_HASH=$(echo -n "$PASS_VALUE" | sha256sum | cut -d' ' -f1)
  HASH_PREVIEW=$(echo "$PASSWORD_HASH" | cut -c1-6)
  echo "密码哈希值: ${HASH_PREVIEW}..."
  
  # 在HTML文件中替换密码占位符
  echo "替换密码哈希到HTML文件..."
  find /usr/share/nginx/html -name "*.html" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$PASSWORD_HASH\";/g" {} \;
  find /usr/share/nginx/html -name "*.js" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$PASSWORD_HASH\";/g" {} \;
  
  # 直接创建一个测试文件确认脚本正在运行
  echo "PASSWORD哈希值: $PASSWORD_HASH" > /tmp/password_applied.txt
elif [ -n "$LIBRETV_PASSWORD" ]; then
  echo "使用LIBRETV_PASSWORD作为系统密码..."
  # 获取密码的SHA-256哈希值
  PASSWORD_HASH=$(echo -n "$LIBRETV_PASSWORD" | sha256sum | cut -d' ' -f1)
  HASH_PREVIEW=$(echo "$PASSWORD_HASH" | cut -c1-6)
  echo "密码哈希值已生成: ${HASH_PREVIEW}..."
  
  # 在HTML文件中替换密码占位符
  echo "应用密码哈希值到HTML文件..."
  find /usr/share/nginx/html -name "*.html" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$PASSWORD_HASH\";/g" {} \;
  find /usr/share/nginx/html -name "*.js" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$PASSWORD_HASH\";/g" {} \;
else
  echo "没有设置密码，使用默认值..."
  # 使用默认密码的哈希值
  DEFAULT_PASSWORD_HASH=$(echo -n "libretvdemo" | sha256sum | cut -d' ' -f1)
  find /usr/share/nginx/html -name "*.html" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$DEFAULT_PASSWORD_HASH\";/g" {} \;
  find /usr/share/nginx/html -name "*.js" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$DEFAULT_PASSWORD_HASH\";/g" {} \;
fi

# 配置弹幕API地址
if [ -n "$DANMAKU_API_URL" ]; then
  echo "配置弹幕API地址: $DANMAKU_API_URL"
  
  # 在player.html中更新API地址和显示信息 - 多处精确替换
  # 1. 更新API_BASE_URL定义处
  sed -i "s|const API_BASE_URL = .*|const API_BASE_URL = \"$DANMAKU_API_URL\";|g" /usr/share/nginx/html/player.html
  
  # 2. 更新currentDanmakuApi显示元素
  sed -i "s|<span id=\"currentDanmakuApi\">.*</span>|<span id=\"currentDanmakuApi\">$DANMAKU_API_URL</span>|g" /usr/share/nginx/html/player.html
  
  # 3. 更新弹幕面板中的API地址信息
  sed -i "s|当前弹幕API地址: <span id=\"currentDanmakuApi\">.*</span>|当前弹幕API地址: <span id=\"currentDanmakuApi\">$DANMAKU_API_URL</span>|g" /usr/share/nginx/html/player.html
  
  # 4. 更新input的默认值
  sed -i "s|id=\"danmakuApiUrl\" value=\"[^\"]*\"|id=\"danmakuApiUrl\" value=\"$DANMAKU_API_URL\"|g" /usr/share/nginx/html/index.html
  
  # 在index.html中更新默认API地址显示
  sed -i "s|placeholder=\"http://localhost:5000\"|placeholder=\"$DANMAKU_API_URL\"|g" /usr/share/nginx/html/index.html
  sed -i "s|const apiUrl = localStorage.getItem('danmakuApiUrl') || 'http://localhost:5000';|const apiUrl = localStorage.getItem('danmakuApiUrl') || '$DANMAKU_API_URL';|g" /usr/share/nginx/html/index.html
  
  # 将API地址写入localStorage的默认值
  sed -i "s|localStorage.setItem('danmakuApiUrl', 'http://localhost:5000');|localStorage.setItem('danmakuApiUrl', '$DANMAKU_API_URL');|g" /usr/share/nginx/html/index.html
  
  echo "已更新所有弹幕API地址引用"
fi

# 配置Nginx参数
if [ -n "$NGINX_WORKER_PROCESSES" ]; then
  sed -i "s/worker_processes .*/worker_processes $NGINX_WORKER_PROCESSES;/g" /etc/nginx/nginx.conf
fi

if [ -n "$NGINX_CLIENT_MAX_BODY_SIZE" ]; then
  sed -i "s/client_max_body_size .*/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/g" /etc/nginx/conf.d/default.conf
fi

# 确保数据目录权限正确
mkdir -p /usr/share/nginx/html/danmu_data
chmod -R 755 /usr/share/nginx/html/danmu_data

# 确保Nginx目录权限正确
mkdir -p /tmp/nginx/run /tmp/nginx/logs /tmp/nginx/cache
chmod -R 755 /tmp/nginx

# 输出版本信息
echo "Starting LibreTV..."
if [ -f "/usr/share/nginx/html/package.json" ]; then
  echo "Version: $(grep -m 1 'version' /usr/share/nginx/html/package.json | cut -d'"' -f4 || echo 'unknown')"
else
  echo "Version: unknown (package.json not found)"
fi
echo "Using Nginx: $(nginx -v 2>&1 | cut -d'/' -f2 || echo 'unknown')"
echo "Python version: $(python3 --version 2>&1 || echo 'not installed')"

# 启动Python弹幕服务器
echo "Starting Danmaku Server..."
if [ -f "/usr/share/nginx/html/app.py" ]; then
  cd /usr/share/nginx/html && /venv/bin/python app.py > /tmp/danmaku_server.log 2>&1 &
  echo "Danmaku Server started in background"
else
  echo "Danmaku Server (app.py) not found - skipping"
fi

# 检查Python包版本
echo "Checking installed Python packages:"
/venv/bin/pip list | grep -E 'flask|pandas|requests|aiohttp'

# 执行传入的命令
echo "Starting Nginx server..."
exec "$@"