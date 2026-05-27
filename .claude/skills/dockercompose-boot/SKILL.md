---
name: dockercompose-boot
description: 当用户执行 docker compose up 失败、准备启动 compose、或遇到挂载类型错误时触发。负责启动前的文件准备检查和常见问题快速修复。
---

# Docker Compose Boot Helper

快速完成 Docker Compose 启动前的文件准备，诊断并修复因文件缺失、类型不匹配导致的挂载失败。

## 触发场景

- `docker compose up` 报错 "not a directory" / "mount a directory onto a file"
- 用户说"启动 docker compose"、"运行 compose"、"compose 起不来"
- 新增服务后首次启动，需要把 example 模板复制到运行时目录

## 启动前检查清单

每次执行 `docker compose up` 前，按此清单检查：

### 1. 配置文件就位（关键）

```bash
# Standalone 模式（双重 service 名）
# compose 在 <service>/ 目录执行，运行时目录是 <service>/<service>/
<service>/
├── docker-compose.yml
├── example/
│   ├── conf/          # 模板配置
│   └── init/          # 初始化脚本
└── <service>/         # ← 运行时目录（gitignored）
    ├── conf/          # 从 example/conf 复制后修改
    └── data/          # 运行时数据

# 复制命令
cp -r <service>/example/conf/* <service>/<service>/conf/
```

```bash
# Stack 模式（单层 service 名）
# compose 在 <stack>/ 目录执行，运行时目录是 <stack>/<service>/
<stack>/
├── docker-compose.yml
├── example/
│   ├── nginx/conf/
│   └── mysql/init/
├── nginx/
│   ├── conf/          # 从 example/nginx/conf 复制
│   └── logs/
└── mysql/
    └── init/

# 复制命令
cp -r <stack>/example/nginx/conf/* <stack>/nginx/conf/
```

### 2. 挂载路径类型校验

| 容器目标 | 宿主机路径必须是 | 常见错误 |
|---------|----------------|---------|
| `/etc/nginx/nginx.conf` | **文件** | 路径不存在 → Docker 自动创建目录 |
| `/etc/nginx/conf.d` | **目录** | 复制时少了子目录 |
| `/var/log/nginx` | **目录** | 目录不存在 |
| `/data` | **目录** | 文件误当成目录挂载 |

### 3. 快速校验命令

```bash
# 在 compose 文件所在目录执行
for v in $(docker compose config --volumes 2>/dev/null || true); do
  # 检查每个卷挂载的宿主机路径是否存在且类型正确
  :
done

# 手动检查：列出所有 bind mount 的宿主机路径
grep -E '^\s+- \./' docker-compose.yml

# 逐个确认类型
file ./nginx/nginx.conf
file ./nginx/conf.d
```

## 案例：文件挂载类型不匹配

### 现象

```
Error response from daemon: ... error mounting "..." to rootfs at "/etc/nginx/nginx.conf":
not a directory: Are you trying to mount a directory onto a file (or vice-versa)?
```

### 根因

`docker-compose.yml` 中 `./nginx/nginx.conf:/etc/nginx/nginx.conf:ro` 的宿主机路径 `nginx/nginx.conf` **不存在**，Docker 自动创建了一个**目录**，导致把目录挂载到容器的文件上。

### 修复步骤

```bash
# Step 1: 停止并删除容器
docker compose down

# Step 2: 删除 Docker 自动创建的目录（不是文件！）
rm -rf ./nginx/nginx.conf

# Step 3: 从 example 复制真正的配置文件
cp ./example/conf/nginx.conf ./nginx/nginx.conf

# Step 4: 确认是文件不是目录
file ./nginx/nginx.conf  # 应输出 "ASCII text"

# Step 5: 如果还在报错，重启 Docker Desktop（WSL2 文件系统缓存问题）
# Windows 托盘 → Quit Docker Desktop → 重新打开

# Step 6: 重新启动
docker compose up
```

## 错误案例

| 错误操作 | 实际后果 | 正确做法 |
|---------|---------|---------|
| 直接 `docker compose up`，未从 `example/` 复制配置 | 配置文件缺失，Docker 自动创建空目录，挂载到容器文件时报 "not a directory" | 启动前执行 `cp -r example/conf/* <service>/conf/` |
| 手动把目录改成文件后未 `docker compose down` | Docker 仍使用旧的挂载缓存，继续报错 | 先 `docker compose down` 再 `docker compose up` |
| 在 WSL 终端操作，但文件是在 Windows 侧创建/修改 | WSL2 文件系统视图不一致，Docker 看到的类型仍错误 | 重启 Docker Desktop 刷新文件系统缓存 |
| `example/conf/nginx.conf` 被直接挂载，而非复制到运行时目录 | example 里的模板被运行时修改污染，下次拉取代码冲突 | 始终复制到运行时目录后再挂载 |
| 用 `**/data/` 通配排除运行时数据 | example/data/ 等模板目录也被误忽略 | `.gitignore` 逐行写具体运行时目录，如 `nginx/nginx/` |

## 快速修复流程

遇到挂载报错时，按优先级执行：

1. **看错误类型** — "not a directory" = 宿主机路径是目录但容器要文件（或反之）
2. **查路径存在性** — `ls -la ./<挂载路径>` 确认文件/目录是否存在
3. **查 example 模板** — 是否未从 `example/` 复制到运行时目录
4. **清 Docker 状态** — `docker compose down` 删除旧容器
5. **清错误目录** — `rm -rf` 删除 Docker 自动创建的目录
6. **复制正确文件** — 从 `example/` 复制模板到正确位置
7. **重启 Docker** — 如果以上都做了还报错，重启 Docker Desktop
