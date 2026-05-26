#!/bin/sh
# 生成自签名证书（仅用于本地开发测试）
# 运行后会在当前目录生成 cert.pem 和 key.pem
# ⚠️ 真实证书不要提交到 git！

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -subj "/C=CN/ST=State/L=City/O=Dev/CN=localhost"

echo "Self-signed cert generated."
echo "Copy cert.pem and key.pem to nginx/ssl/"
echo "WARNING: DO NOT commit *.pem *.key to git."
