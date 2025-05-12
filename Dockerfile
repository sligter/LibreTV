# 使用多阶段构建
# 构建阶段
FROM alpine:3.21 AS builder

# 安装必要的构建工具
RUN apk add --no-cache python3 py3-pip nodejs npm

# 设置工作目录
WORKDIR /app

# 先复制依赖文件，利用Docker缓存层
COPY requirements.txt /app/

# 创建并激活虚拟环境，安装依赖
RUN python3 -m venv /venv && \
    /venv/bin/pip install --no-cache-dir -U pip && \
    /venv/bin/pip install --no-cache-dir -r requirements.txt

# 复制其他应用源码
COPY . /app/

# 最终镜像
FROM fabiocicerchia/nginx-lua:1.27.5-alpine3.21.3
LABEL maintainer="LibreTV Team"
LABEL description="LibreTV - 免费在线视频搜索与观看平台"
LABEL version="1.0.0"

# 设置环境变量
ENV TZ=Asia/Shanghai \
    NGINX_WORKER_PROCESSES=auto \
    NGINX_CLIENT_MAX_BODY_SIZE=10m \
    DANMAKU_API_URL=http://localhost:5000 \
    PYTHONUNBUFFERED=1 \
    PATH="/venv/bin:$PATH"

# 安装Python和依赖
RUN apk add --no-cache python3 \
    # pandas依赖项
    py3-numpy \
    py3-scipy \
    musl-dev \
    python3-dev

# 从builder阶段复制虚拟环境
COPY --from=builder /venv /venv

# 创建数据目录并设置正确权限
# 注意：基础镜像已包含nginx用户和组，所以不需要创建
RUN mkdir -p /usr/share/nginx/html/danmu_data && \
    chown -R nginx:nginx /usr/share/nginx/html

# 从构建阶段复制应用文件
COPY --from=builder --chown=nginx:nginx /app/ /usr/share/nginx/html/

# 复制Nginx配置文件
COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf

# 创建Nginx所需的工作目录并设置权限
RUN mkdir -p /tmp/nginx/run && \
    mkdir -p /tmp/nginx/logs && \
    mkdir -p /tmp/nginx/cache && \
    chown -R nginx:nginx /tmp/nginx

# 创建自定义Nginx主配置
RUN echo 'worker_processes auto;' > /etc/nginx/nginx.conf && \
    echo 'pid /tmp/nginx/run/nginx.pid;' >> /etc/nginx/nginx.conf && \
    echo 'error_log /tmp/nginx/logs/error.log warn;' >> /etc/nginx/nginx.conf && \
    echo 'events {' >> /etc/nginx/nginx.conf && \
    echo '    worker_connections 1024;' >> /etc/nginx/nginx.conf && \
    echo '}' >> /etc/nginx/nginx.conf && \
    echo 'http {' >> /etc/nginx/nginx.conf && \
    echo '    include       /etc/nginx/mime.types;' >> /etc/nginx/nginx.conf && \
    echo '    default_type  application/octet-stream;' >> /etc/nginx/nginx.conf && \
    echo '    log_format  main  '\''$remote_addr - $remote_user [$time_local] "$request" '\''' >> /etc/nginx/nginx.conf && \
    echo '                      '\''$status $body_bytes_sent "$http_referer" '\''' >> /etc/nginx/nginx.conf && \
    echo '                      '\''"$http_user_agent" "$http_x_forwarded_for"'\'';' >> /etc/nginx/nginx.conf && \
    echo '    access_log  /tmp/nginx/logs/access.log  main;' >> /etc/nginx/nginx.conf && \
    echo '    sendfile        on;' >> /etc/nginx/nginx.conf && \
    echo '    keepalive_timeout  65;' >> /etc/nginx/nginx.conf && \
    echo '    client_max_body_size 10m;' >> /etc/nginx/nginx.conf && \
    echo '    client_body_temp_path /tmp/nginx/cache/client_temp;' >> /etc/nginx/nginx.conf && \
    echo '    proxy_temp_path /tmp/nginx/cache/proxy_temp;' >> /etc/nginx/nginx.conf && \
    echo '    fastcgi_temp_path /tmp/nginx/cache/fastcgi_temp;' >> /etc/nginx/nginx.conf && \
    echo '    uwsgi_temp_path /tmp/nginx/cache/uwsgi_temp;' >> /etc/nginx/nginx.conf && \
    echo '    scgi_temp_path /tmp/nginx/cache/scgi_temp;' >> /etc/nginx/nginx.conf && \
    echo '    include /etc/nginx/conf.d/*.conf;' >> /etc/nginx/nginx.conf && \
    echo '}' >> /etc/nginx/nginx.conf && \
    chown nginx:nginx /etc/nginx/nginx.conf

# 手动创建可靠的入口脚本
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 调试输出' >> /docker-entrypoint.sh && \
    echo 'echo "环境变量检测: PASSWORD=${PASSWORD}, LIBRETV_PASSWORD=${LIBRETV_PASSWORD}"' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 检查是否提供了密码环境变量' >> /docker-entrypoint.sh && \
    echo 'if [ -n "$PASSWORD" ]; then' >> /docker-entrypoint.sh && \
    echo '  echo "使用PASSWORD环境变量作为系统密码..."' >> /docker-entrypoint.sh && \
    echo '  # 计算哈希值并替换到HTML文件' >> /docker-entrypoint.sh && \
    echo '  PASSWORD_HASH=$(echo -n "$PASSWORD" | sha256sum | cut -d" " -f1)' >> /docker-entrypoint.sh && \
    echo '  find /usr/share/nginx/html -name "*.html" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$PASSWORD_HASH\";/g" {} \;' >> /docker-entrypoint.sh && \
    echo '  find /usr/share/nginx/html -name "*.js" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$PASSWORD_HASH\";/g" {} \;' >> /docker-entrypoint.sh && \
    echo '  # 也更新原来的密码设置机制' >> /docker-entrypoint.sh && \
    echo '  if [ -f "/usr/share/nginx/html/js/password.js" ]; then' >> /docker-entrypoint.sh && \
    echo '    sed -i "s/{{PASSWORD}}/$PASSWORD_HASH/g" /usr/share/nginx/html/js/password.js' >> /docker-entrypoint.sh && \
    echo '  fi' >> /docker-entrypoint.sh && \
    echo '  # 调试输出' >> /docker-entrypoint.sh && \
    echo '  echo "PASSWORD哈希值应用完成：$(echo $PASSWORD_HASH | cut -c1-6)..."' >> /docker-entrypoint.sh && \
    echo '  echo "PASSWORD应用成功" > /tmp/password_applied.txt' >> /docker-entrypoint.sh && \
    echo 'elif [ -n "$LIBRETV_PASSWORD" ]; then' >> /docker-entrypoint.sh && \
    echo '  echo "使用LIBRETV_PASSWORD作为系统密码..."' >> /docker-entrypoint.sh && \
    echo '  # 计算哈希值' >> /docker-entrypoint.sh && \
    echo '  PASSWORD_HASH=$(echo -n "$LIBRETV_PASSWORD" | sha256sum | cut -d" " -f1)' >> /docker-entrypoint.sh && \
    echo '  # 替换HTML文件中的密码占位符' >> /docker-entrypoint.sh && \
    echo '  find /usr/share/nginx/html -name "*.html" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$PASSWORD_HASH\";/g" {} \;' >> /docker-entrypoint.sh && \
    echo '  find /usr/share/nginx/html -name "*.js" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$PASSWORD_HASH\";/g" {} \;' >> /docker-entrypoint.sh && \
    echo '  # 也更新原来的密码设置机制' >> /docker-entrypoint.sh && \
    echo '  if [ -f "/usr/share/nginx/html/js/password.js" ]; then' >> /docker-entrypoint.sh && \
    echo '    sed -i "s/{{PASSWORD}}/$PASSWORD_HASH/g" /usr/share/nginx/html/js/password.js' >> /docker-entrypoint.sh && \
    echo '  fi' >> /docker-entrypoint.sh && \
    echo 'else' >> /docker-entrypoint.sh && \
    echo '  echo "没有设置密码，使用默认值..."' >> /docker-entrypoint.sh && \
    echo '  # 使用默认密码的哈希值' >> /docker-entrypoint.sh && \
    echo '  DEFAULT_PASSWORD_HASH=$(echo -n "libretvdemo" | sha256sum | cut -d" " -f1)' >> /docker-entrypoint.sh && \
    echo '  find /usr/share/nginx/html -name "*.html" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$DEFAULT_PASSWORD_HASH\";/g" {} \;' >> /docker-entrypoint.sh && \
    echo '  find /usr/share/nginx/html -name "*.js" -type f -exec sed -i "s/window.__ENV__.PASSWORD = \"{{PASSWORD}}\";/window.__ENV__.PASSWORD = \"$DEFAULT_PASSWORD_HASH\";/g" {} \;' >> /docker-entrypoint.sh && \
    echo '  # 也更新原来的密码设置机制' >> /docker-entrypoint.sh && \
    echo '  if [ -f "/usr/share/nginx/html/js/password.js" ]; then' >> /docker-entrypoint.sh && \
    echo '    sed -i "s/{{PASSWORD}}/$DEFAULT_PASSWORD_HASH/g" /usr/share/nginx/html/js/password.js' >> /docker-entrypoint.sh && \
    echo '  fi' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 配置弹幕API地址' >> /docker-entrypoint.sh && \
    echo 'if [ -n "$DANMAKU_API_URL" ]; then' >> /docker-entrypoint.sh && \
    echo '  echo "配置弹幕API地址: $DANMAKU_API_URL"' >> /docker-entrypoint.sh && \
    echo '  # 在player.html中更新API地址' >> /docker-entrypoint.sh && \
    echo '  sed -i "s|const API_BASE_URL = .*|const API_BASE_URL = \"$DANMAKU_API_URL\";|g" /usr/share/nginx/html/player.html' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '  # 尝试更新其他API地址位置' >> /docker-entrypoint.sh && \
    echo '  # 这些命令即使失败也继续执行后续内容' >> /docker-entrypoint.sh && \
    echo '  sed -i "s|<span id=\"currentDanmakuApi\">.*</span>|<span id=\"currentDanmakuApi\">$DANMAKU_API_URL</span>|g" /usr/share/nginx/html/player.html || true' >> /docker-entrypoint.sh && \
    echo '  sed -i "s|placeholder=\"http://localhost:5000\"|placeholder=\"$DANMAKU_API_URL\"|g" /usr/share/nginx/html/index.html || true' >> /docker-entrypoint.sh && \
    echo '  # 尝试使用不同的引号嵌套方式' >> /docker-entrypoint.sh && \
    echo "  sed -i \"s|localStorage.getItem('danmakuApiUrl') || 'http://localhost:5000'|localStorage.getItem('danmakuApiUrl') || '$DANMAKU_API_URL'|g\" /usr/share/nginx/html/index.html || true" >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 配置Nginx参数' >> /docker-entrypoint.sh && \
    echo 'if [ -n "$NGINX_WORKER_PROCESSES" ]; then' >> /docker-entrypoint.sh && \
    echo '  sed -i "s/worker_processes .*/worker_processes $NGINX_WORKER_PROCESSES;/g" /etc/nginx/nginx.conf' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo 'if [ -n "$NGINX_CLIENT_MAX_BODY_SIZE" ]; then' >> /docker-entrypoint.sh && \
    echo '  sed -i "s/client_max_body_size .*/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/g" /etc/nginx/conf.d/default.conf' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 确保数据目录权限正确' >> /docker-entrypoint.sh && \
    echo 'mkdir -p /usr/share/nginx/html/danmu_data' >> /docker-entrypoint.sh && \
    echo 'chmod -R 755 /usr/share/nginx/html/danmu_data' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 确保Nginx目录权限正确' >> /docker-entrypoint.sh && \
    echo 'mkdir -p /tmp/nginx/run /tmp/nginx/logs /tmp/nginx/cache' >> /docker-entrypoint.sh && \
    echo 'chmod -R 755 /tmp/nginx' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 输出版本信息' >> /docker-entrypoint.sh && \
    echo 'echo "Starting LibreTV..."' >> /docker-entrypoint.sh && \
    echo 'if [ -f "/usr/share/nginx/html/package.json" ]; then' >> /docker-entrypoint.sh && \
    echo '  echo "Version: $(grep -m 1 '\''version'\'' /usr/share/nginx/html/package.json | cut -d'\''"'\'' -f4 || echo '\''unknown'\'')"' >> /docker-entrypoint.sh && \
    echo 'else' >> /docker-entrypoint.sh && \
    echo '  echo "Version: unknown (package.json not found)"' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo 'echo "Using Nginx: $(nginx -v 2>&1 | cut -d'\''/'\'' -f2 || echo '\''unknown'\'')"' >> /docker-entrypoint.sh && \
    echo 'echo "Python version: $(python3 --version 2>&1 || echo '\''not installed'\'')"' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 启动Python弹幕服务器' >> /docker-entrypoint.sh && \
    echo 'echo "Starting Danmaku Server..."' >> /docker-entrypoint.sh && \
    echo 'if [ -f "/usr/share/nginx/html/app.py" ]; then' >> /docker-entrypoint.sh && \
    echo '  cd /usr/share/nginx/html && /venv/bin/python app.py > /tmp/danmaku_server.log 2>&1 &' >> /docker-entrypoint.sh && \
    echo '  echo "Danmaku Server started in background"' >> /docker-entrypoint.sh && \
    echo 'else' >> /docker-entrypoint.sh && \
    echo '  echo "Danmaku Server (app.py) not found - skipping"' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 检查Python包版本' >> /docker-entrypoint.sh && \
    echo 'echo "Checking installed Python packages:"' >> /docker-entrypoint.sh && \
    echo '/venv/bin/pip list | grep -E '\''flask|pandas|requests|aiohttp'\''' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# 执行传入的命令' >> /docker-entrypoint.sh && \
    echo 'echo "Starting Nginx server..."' >> /docker-entrypoint.sh && \
    echo 'exec "$@"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh && \
    chown nginx:nginx /docker-entrypoint.sh && \
    echo "Entrypoint script created successfully"

# 定义数据卷，用于持久化弹幕数据
VOLUME ["/usr/share/nginx/html/danmu_data"]

# 暴露端口
EXPOSE 80 5000

# 切换到非root用户
USER nginx

# 设置入口点
ENTRYPOINT ["/docker-entrypoint.sh"]

# 启动nginx
CMD ["nginx", "-g", "daemon off;"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1