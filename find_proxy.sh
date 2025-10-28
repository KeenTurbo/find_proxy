#!/bin/bash

# --- 修正1: 确保我们在正确的项目目录下 ---
# 脚本将从当前目录执行，请确保您已在 /root/grok2api 目录下
echo "✅ 当前目录: $(pwd)"

# --- 代理列表 ---
# 从文档提取的代理列表（注意：这些是免费公共代理，成功率很低）
cat > /tmp/elite_proxies.txt << 'EOL'
47.252.81.108:8118
47.252.29.28:11222
198.54.124.88:8080
192.64.112.150:8080
162.240.19.30:80
108.170.12.10:80
129.213.69.94:80
5.161.103.41:88
192.73.244.36:80
82.180.132.69:80
147.75.34.92:9443
41.32.39.7:3128
8.210.17.35:8445
147.75.34.105:443
35.183.64.191:30309
43.156.15.111:20002
113.163.5.253:8080
5.252.33.13:2025
195.114.209.50:80
45.22.209.157:8888
154.65.39.8:80
202.181.16.173:3325
38.54.71.67:80
156.38.112.11:80
46.39.105.157:8080
182.52.165.147:8080
14.251.13.0:8080
EOL

echo "🚀 代理池启动：开始测试代理..."

BEST_PROXY=""
FASTEST_TIME=10 # 设置一个较高的初始响应时间

# --- 代理测试循环 ---
for proxy in $(cat /tmp/elite_proxies.txt | sort -u); do # 使用 sort -u 去重
  echo "🧪 测试: http://$proxy"
  # 使用 curl 测试代理是否能访问 httpbin.org，超时时间为5秒
  # -s 静默模式, -I 只获取头部信息, -m 超时时间, -x 使用代理
  RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" -x "http://$proxy" https://httpbin.org/get -m 5)
  
  # 检查 curl 是否成功执行 (退出码为0) 并且响应时间小于记录的最快时间
  if [ $? -eq 0 ] && (( $(echo "$RESPONSE_TIME < $FASTEST_TIME" | bc -l) )); then
    BEST_PROXY="$proxy"
    FASTEST_TIME=$RESPONSE_TIME
    echo "✅ 找到更优代理: http://$proxy (响应时间: ${FASTEST_TIME}秒)"
  fi
done

# --- 检查是否找到可用代理并更新配置 ---
if [ -n "$BEST_PROXY" ]; then
  echo "🏆 选定最优代理: http://$BEST_PROXY (响应时间: ${FASTEST_TIME}秒)"
  
  # --- 修正2: 使用 docker exec 在容器内部修改配置文件 ---
  # 动态获取容器名
  CONTAINER_NAME=$(docker compose ps -q)
  if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ 错误：找不到正在运行的grok2api容器！"
    exit 1
  fi
  
  echo "✍️ 正在更新容器 $CONTAINER_NAME 内的配置文件..."
  # 使用 # 作为 sed 的分隔符，避免与URL中的 / 冲突
  docker compose exec "$CONTAINER_NAME" sed -i "s#proxy_url = \".*\"#proxy_url = \"http://$BEST_PROXY\"#" /app/data/setting.toml
  
  echo "🔄 重启grok2api服务以应用新配置..."
  docker compose restart
  sleep 5 # 等待服务重启
  
  echo "🔬 最终测试：向本地grok2api服务发送一个请求..."
  # --- 修正3: 在最终测试中加入认证头 ---
  # 请将 YOUR_API_KEY_HERE 替换为您在后台设置的真实API Key
  API_KEY="YOUR_API_KEY_HERE" 
  curl -s -X POST http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d '{"model": "grok-4-fast", "messages": [{"role": "user", "content": "你好，测试代理是否成功"}], "stream": false}'
  echo "" # 换行
  echo "🎉 脚本执行完毕！请检查上面的输出判断是否成功。"

else
  echo "❌ 遗憾：在此次测试中没有找到任何可用的代理。"
fi

# 清理临时文件
rm -f /tmp/elite_proxies.txt