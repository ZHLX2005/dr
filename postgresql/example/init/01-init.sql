-- PostgreSQL 初始化脚本
-- 创建示例数据库、用户，并启用 pgvector 扩展

CREATE DATABASE IF NOT EXISTS demo;

-- 切换到 demo 数据库
\c demo;

-- 启用 pgvector 扩展（如镜像支持）
CREATE EXTENSION IF NOT EXISTS vector;

-- 创建示例表
CREATE TABLE IF NOT EXISTS items (
    id serial PRIMARY KEY,
    name text NOT NULL,
    embedding vector(3),
    created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

-- 插入示例数据
INSERT INTO items (name, embedding) VALUES
    ('apple', '[1,2,3]'),
    ('banana', '[4,5,6]'),
    ('cherry', '[7,8,9]')
ON CONFLICT DO NOTHING;
