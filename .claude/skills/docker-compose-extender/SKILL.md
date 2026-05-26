---
name: docker-compose-extender
description: 当用户要求向 dockerdbv2 添加新容器、新服务、新镜像，或扩展 docker-compose 配置时触发。也触发于"再加一个xx数据库"、"帮我写个xx的compose"、"扩展镜像"等场景。
---

# Docker Compose Extender for dockerdbv2

为 dockerdbv2 项目新增服务时，强制遵循已验证的目录结构和挂载规范，并生成可直接运行的脚手架。

## 核心规范

### 1. 目录与文件位置

支持两种模式，根据用户需求判断用哪种：

**模式 A：单体服务（Standalone）**
- 每个服务独占一个目录：`dockerdbv2/<service>/docker-compose.yml`
- 适用于独立运行、不依赖其他服务的数据库/中间件
- 运行时目录使用 **双重 service 名**：`redis/redis/data/`

**模式 B：聚合编排（Stack）**
- 多个服务共享一个 `docker-compose.yml`：`dockerdbv2/<stack>/docker-compose.yml`
- 适用于 Web 应用栈（如 LNMP、微服务组合），服务间需要互通
- 顶层定义统一网络（`networks:`），所有服务加入同一网络
- 运行时目录使用 **单层 service 名**：`web/mysql8/data/`（compose 在父级，路径无需嵌套）
- `example/` 集中放在栈根目录：`web/example/mysql/`、`web/example/nginx/`

如果用户说"帮我搭一套 web 环境"、"来个 LNMP"、"这些服务放一起"，触发 **Stack 模式**。

### 2. 卷挂载规范（强制）
- 所有本地挂载必须使用 `./<service-name>/子目录` 的相对路径
- 数据目录统一命名为 `data`
- 日志目录统一命名为 `logs`
- 配置目录统一命名为 `conf` 或 `config`
- 初始化脚本目录统一命名为 `init`
- **共享目录统一命名为 `shared`，挂载到容器 `/shared`，方便宿主机与容器交换文件**

**正确示例：**
```yaml
volumes:
  - ./redis/data:/data
  - ./redis/conf:/usr/local/etc/redis
  - ./redis/logs:/var/log/redis
  - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
```

**错误示例（不要这样做）：**
```yaml
volumes:
  - ./data:/var/lib/postgresql/data        # 缺少服务名前缀
  - ./redis-data:/data                     # 不规范的目录命名
  - ./hive-data:/data                      # 把其他服务名混用进来
```

### 3. 凭证规范
- 用户名优先使用 `container`
- 密码优先使用 `223456`（内部开发环境，不求复杂）
- 如果服务支持无认证运行（如某些 Redis、Traefik 场景），直接省略环境变量
- 禁止生成随机强密码，增加维护成本

### 4. .gitignore 维护

**核心原则：一个容器对应一个运行时目录排除，不用 `**/` 通配。**

- Standalone 模式：追加 `<service>/<service>/`
- Stack 模式：追加 `<stack>/<service>/`

示例：
```
# --- Standalone ---
mysql/mysql/
redis/redis/

# --- Stack: web ---
web/mysql8/
web/redis/
web/nginx/
```

- **关键：`example/` 目录绝不被忽略** — 它存放的是提交到 git 的模板文件
- 通用规则保留 `.env` 和 `**/ssl/*.pem` / `*.key` / `*.crt`（真实证书）
- 每次新增服务后，在 `.gitignore` 对应区块追加一行运行时目录

## 示例脚手架 (example/ 目录)

每个服务必须附带 `example/` 目录，内含可直接复制使用的模板文件。**`example/` 里的文件全部提交到 git。**

### 目录结构模板（双重 service 名）

运行时目录使用 **双重 service 名**：`<service>/<service>/data/`。`.gitignore` 中追加一行 `<service>/<service>/` 即可整目录排除，data、logs、conf 一次搞定。

```
<service>/
├── docker-compose.yml
├── example/
│   ├── init/          # 初始化脚本（数据库 .sql、创建库脚本等）
│   ├── conf/          # 配置文件模板（nginx.conf、redis.conf 等）
│   ├── ssl/           # SSL 证书/密钥占位（示例证书、自签生成脚本）
│   └── shared/        # 共享目录模板，挂载到容器 /shared
└── <service>/         # ← 与服务同名的运行时数据容器目录
    ├── data/          # gitignored：运行时数据
    ├── logs/          # gitignored：运行时日志
    ├── conf/          # 可选：运行时配置（用户从 example/conf 复制后修改）
    └── shared/        # 共享目录，挂载到容器 /shared
```

**为什么用双重 service 名？**
- compose 文件里写 `./redis/data`，在 `redis/` 目录执行时自然映射到 `redis/redis/data`
- `.gitignore` 追加 `<service>/<service>/` 一行即可排除整个运行时目录
- 服务目录内部结构自包含，移动或复制整目录不破坏路径关系

---

### Stack 模式目录结构（单层 service 名）

当多个服务聚合在一起时，compose 文件位于栈根目录，运行时目录只需单层 service 名。

```
web/                               # ← 栈目录
├── docker-compose.yml             # 聚合编排文件，包含 mysql + redis + nginx
├── example/                       # 集中式示例模板
│   ├── mysql/
│   │   ├── init/01-init.sql
│   │   └── conf/
│   ├── redis/
│   │   ├── conf/redis.conf
│   │   └── ssl/
│   ├── nginx/
│   │   ├── conf/nginx.conf
│   │   └── html/index.html
│├── mysql8/                        # 运行时数据（单层 service 名）
│   ├── data/
│   ├── log/
│   ├── conf.d/
│   └── shared/
├── redis/
│   ├── data/
│   ├── logs/
│   ├── redis.conf
│   └── shared/
└── nginx/
    ├── conf/
    ├── logs/
    ├── html/
    ├── ssl/
    └── shared/
```

**Stack 模式 compose 示例：**
```yaml
version: '3.8'

networks:
  app-network:
    driver: bridge

services:
  mysql:
    image: mysql:8.0
    container_name: mysql8
    environment:
      - MYSQL_ROOT_PASSWORD=223456
    volumes:
      - ./mysql8/log:/var/log/mysql
      - ./mysql8/data:/var/lib/mysql
      - ./mysql8/conf.d:/etc/mysql/conf.d
      - /etc/localtime:/etc/localtime:ro
    ports:
      - 3306:3306
    restart: always
    networks:
      - app-network

  redis:
    image: redis:latest
    container_name: redis
    restart: always
    ports:
      - '6379:6379'
    volumes:
      - ./redis/data:/data
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis/logs:/logs
    command: redis-server /usr/local/etc/redis/redis.conf
    networks:
      - app-network

  nginx:
    image: nginx:latest
    container_name: nginx
    restart: always
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ./nginx/conf/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/logs:/var/log/nginx
      - ./nginx/html:/usr/share/nginx/html
      - ./nginx/ssl:/etc/nginx/ssl
    networks:
      - app-network
```

**Stack 模式规范：**
- `docker-compose.yml` 必须显式定义 `networks:`，所有服务加入同一自定义网络
- 每个服务的 `volumes` 使用 `./<service>/子目录`，compose 在父级解析为单层路径
- `example/` 放在栈根目录，按服务分子目录：`example/mysql/init/`、`example/nginx/conf/`
- 快捷脚本放在 `example/sh/`，操作整个栈（`docker-compose up -d` 启动全部服务）
- 各服务运行时目录在 `.gitignore` 中逐行追加（如 `web/mysql8/`、`web/redis/`）

### example/init/ 规范
- 数据库服务必须提供 `init/01-init.sql`：创建常用库、用户、表结构模板
- 脚本名前加序号（`01-`、`02-`）确保执行顺序
- SQL 里密码保持和 compose 一致（`223456`），方便本地联调

```sql
-- example: mysql/example/init/01-init.sql
CREATE DATABASE IF NOT EXISTS demo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED BY '223456';
GRANT ALL PRIVILEGES ON demo.* TO 'app'@'%';
FLUSH PRIVILEGES;
```

### example/conf/ 规范
- 提供最小可用配置文件，注释说明需要用户自行调整的地方
- 文件从 `example/conf/` 复制到运行时 `conf/` 后由 compose 挂载
- 不要提交带真实域名的配置，使用 `localhost` 占位

```nginx
# example: nginx/example/conf/nginx.conf
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # TODO: 修改为真实域名后启用 SSL
    # listen 443 ssl;
    # ssl_certificate /etc/nginx/ssl/cert.pem;
    # ssl_certificate_key /etc/nginx/ssl/key.pem;
}
```

### example/ssl/ 规范
- 提供自签名证书生成脚本 `gen-selfsigned.sh`，不提交真实证书
- 提供 `.gitignore` 说明哪些 SSL 文件被忽略（在 `<service>/.gitignore` 里，不影响根目录）

```bash
#!/bin/sh
# example/ssl/gen-selfsigned.sh
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -subj "/C=CN/ST=State/L=City/O=Org/CN=localhost"
echo "Self-signed cert generated. DO NOT commit *.pem to git."
```

## 执行流程

### Standalone 模式

1. 确认服务名称（如 `mongodb`、`elasticsearch`、`kafka`）
2. 确认目标目录（根级或 `dev/` 下）
3. 拉取或回忆该服务的官方 Docker 镜像和必要端口
4. 编写 `docker-compose.yml`，强制应用双重 service 名挂载规范
5. **创建 `example/` 脚手架：**
   - `example/init/` — 初始化脚本（数据库类服务）
   - `example/conf/` — 最小可用配置文件模板
   - `example/ssl/` — 自签证书生成脚本（需要 SSL 的服务）
   - `example/shared/` — 共享目录占位
6. 创建目录并写入所有文件
7. 检查 `.gitignore` 是否已覆盖新服务的运行时目录，如未覆盖则追加
8. 向用户说明：
   - 复制 `example/conf/*` 到 `<service>/conf/`（即 `<service>/<service>/conf/`）并根据需要修改
   - 运行 `example/ssl/gen-selfsigned.sh` 生成证书（如需）

### Stack 模式

1. 确认栈名称（如 `web`、`lnmp`、`app`）及包含的服务列表
2. 确认是否需要服务间网络互通（通常需要）
3. 编写统一的 `docker-compose.yml`，定义 `networks:` 并让所有服务加入
4. 各服务使用 `./<service>/子目录` 单层挂载
5. **创建集中式 `example/` 脚手架：**
   - `example/<service>/init/` — 各数据库初始化脚本
   - `example/<service>/conf/` — 各服务配置模板
   - `example/<service>/ssl/` — 证书生成脚本
   - `example/shared/` — 共享目录占位
6. 创建目录并写入所有文件
7. 检查 `.gitignore` 追加忽略规则
8. 向用户说明：
   - 复制 `example/<service>/conf/*` 到 `<service>/conf/` 并根据需要修改
   - 快捷脚本在栈根目录执行 `docker-compose`

## 错误案例

| 错误操作 | 实际后果 | 正确做法 |
|---------|---------|---------|
| 使用 `./data:/xxx` 作为挂载路径 | 多个服务的数据目录冲突，且 `.gitignore` 无法精确排除 | 始终使用 `./<service>/data:/xxx`，并在 `.gitignore` 追加 `<service>/<service>/` |
| 把服务直接写在根目录 `docker-compose.yml` | 失去模块化，无法单独管理单个服务生命周期 | 每个服务独立目录，各自一个 compose 文件 |
| 生成随机强密码 | 用户记不住，每次都要查文档 | 统一使用简单密码或省略认证 |
| 新增服务后忘记更新 `.gitignore` | 数据文件被误提交到 git | 每新增一个服务，检查并追加 ignore 规则 |
| 混用其他服务的数据目录名（如 hbase 用 `./hive-data`） | 路径混乱，后续维护和排查困难 | 目录名必须与服务名一致 |
| **Standalone 模式下运行时目录放在 `<service>/data/` 而非 `<service>/<service>/data/`** | 单体 compose 在 `<service>/` 内执行，单层路径会导致各服务数据冲突 | Standalone 模式严格双重 service 名；Stack 模式才用单层 |
| **Stack 模式下误用双重 service 名（如 `web/nginx/nginx/data`）** | 路径冗余，compose 在 `web/` 父级执行，单层即可 | Stack 模式用 `./nginx/data`，对应 `web/nginx/data` |
| **Stack 模式遗漏 `networks:` 定义** | 服务间无法通过服务名互相访问 | Stack 必须显式定义共享网络，所有服务加入 |
| **Windows 下生成 `.sh` 脚本使用 CRLF 换行** | 脚本在 Linux 容器里无法执行，报错 `/bin/sh^M: bad interpreter` | 显式使用 LF 换行符写入脚本文件 |
| **`example/` 目录被根目录 `**/` 型规则误忽略** | 用户拉取代码后找不到配置模板 | `.gitignore` 避免 blanket 规则，或显式 `!example/` 例外 |
| **使用 `**/data/`、`**/logs/` 通配排除运行时数据** | 误伤 `example/data/`、`example/logs/` 等需要提交的案例数据 | `.gitignore` 逐行追加具体运行时目录，如 `mysql/mysql/`、`web/redis/` |
| **`.gitignore` 按直觉或挂载子目录名排除，未按实际运行时目录推导** | cloud-grafana 的 compose 在 `cloud-grafana/` 内执行，挂载 `./cloud-grafana/grafana-data` 实际对应 `cloud-grafana/cloud-grafana/grafana-data`。误写为 `cloud-grafana/grafana/` 或 `cloud-grafana/grafana-data/` 均无法正确排除 | 严格按"compose 执行目录 + 挂载相对路径"推导实际运行时目录，再写入 `.gitignore` |
| **提交真实 SSL 证书到 git** | 私钥泄露风险 | `example/ssl/` 只提交生成脚本和说明，不提交 `*.pem` |
| **shell 脚本缺少 shebang (`#!/bin/sh`)** | 在某些环境下被执行失败或行为异常 | 每个 `.sh` 文件第一行必须是 shebang |

## 输出示例

当用户说"帮我加一个 MongoDB"时，应生成：

```yaml
# mongodb/docker-compose.yml
version: '3.8'

services:
  mongodb:
    image: mongo:7
    container_name: mongodb
    restart: unless-stopped
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: container
      MONGO_INITDB_ROOT_PASSWORD: "223456"
    volumes:
      - ./mongodb/data:/data/db
      - ./mongodb/logs:/var/log/mongodb
      - ./mongodb/init:/docker-entrypoint-initdb.d
      - ./mongodb/shared:/shared
```

以及以下脚手架文件：

```javascript
// mongodb/example/init/01-init.js
db = db.getSiblingDB('demo');
db.createCollection('sample');
db.sample.insertOne({ message: 'Hello from dockerdbv2', createdAt: new Date() });
```

并在 `.gitignore` 追加 `mongodb/mongodb/` 以排除整个运行时目录。

---

当用户说"帮我搭一套 LNMP"或"来个 web 栈"时，触发 **Stack 模式**，应生成：

```yaml
# web/docker-compose.yml
version: '3.8'

networks:
  app-network:
    driver: bridge

services:
  mysql:
    image: mysql:8.0
    container_name: mysql8
    environment:
      - MYSQL_ROOT_PASSWORD=223456
    volumes:
      - ./mysql8/log:/var/log/mysql
      - ./mysql8/data:/var/lib/mysql
      - ./mysql8/conf.d:/etc/mysql/conf.d
      - /etc/localtime:/etc/localtime:ro
    ports:
      - 3306:3306
    restart: always
    networks:
      - app-network

  redis:
    image: redis:latest
    container_name: redis
    restart: always
    ports:
      - '6379:6379'
    volumes:
      - ./redis/data:/data
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
      - ./redis/logs:/logs
    command: redis-server /usr/local/etc/redis/redis.conf
    networks:
      - app-network

  nginx:
    image: nginx:latest
    container_name: nginx
    restart: always
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ./nginx/conf/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/logs:/var/log/nginx
      - ./nginx/html:/usr/share/nginx/html
      - ./nginx/ssl:/etc/nginx/ssl
    networks:
      - app-network
```

以及以下脚手架文件：

```sql
-- web/example/mysql/init/01-init.sql
CREATE DATABASE IF NOT EXISTS demo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED BY '223456';
GRANT ALL PRIVILEGES ON demo.* TO 'app'@'%';
FLUSH PRIVILEGES;
```

```nginx
# web/example/nginx/conf/nginx.conf
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # TODO: 修改为真实域名后启用 SSL
    # listen 443 ssl;
    # ssl_certificate /etc/nginx/ssl/cert.pem;
    # ssl_certificate_key /etc/nginx/ssl/key.pem;
}
```

并在 `.gitignore` 追加 `web/mysql8/`、`web/redis/`、`web/nginx/` 以排除各运行时目录。
