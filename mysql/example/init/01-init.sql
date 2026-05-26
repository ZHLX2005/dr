-- MySQL 初始化脚本
-- 创建示例数据库和用户，并修复 root 远程连接权限

-- ============================================
-- 关键：MySQL 8.0 默认 root 仅允许 localhost 登录
-- 以下语句自动创建允许远程连接的 root@% 用户
-- ============================================

-- 修改 localhost root 用户的认证方式（与 compose 一致）
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '223456';

-- 创建允许从任意主机连接的 root 用户（如果不存在）
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY '223456';

-- 授予 root@% 所有权限
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;

-- ============================================
-- 业务数据库初始化
-- ============================================

CREATE DATABASE IF NOT EXISTS demo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED WITH mysql_native_password BY '223456';
GRANT ALL PRIVILEGES ON demo.* TO 'app'@'%';
FLUSH PRIVILEGES;

USE demo;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO users (username, email) VALUES
    ('admin', 'admin@example.com'),
    ('demo', 'demo@example.com')
ON DUPLICATE KEY UPDATE username = username;
