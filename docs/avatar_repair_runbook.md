# 线上头像修复手册

更新于：2026-03-29 06:14 (Asia/Shanghai)

## 适用场景

当线上 TangSengDaoDao Server 日志持续出现以下错误时使用：

- `下载图片失败`
- `下载图片返回状态有误`
- `组合群头像失败`

## 已确认根因

- 服务端默认头像实际读取路径为：
  - `/avatar/default/test ({id}).jpg`
- `{id}` 来源于：
  - `crc32(uid) % Avatar.DefaultCount`
- 开源默认配置中 `defaultCount` 为 `900`
- 线上 MinIO 曾缺少 `avatar` 桶与默认头像对象

## 修复步骤

### 1. 从服务端容器导出默认头像底图

```bash
docker cp fullstack_tangsengdaodaoserver_1:/home/assets/assets/avatar.png /root/avatar.png
```

### 2. 创建桶、开放下载、补齐 `0..899`

```bash
docker run --rm \
  --network fullstack_default \
  -v /root/avatar.png:/avatar.png:ro \
  --entrypoint sh \
  minio/mc -c '
    set -e
    mc alias set local http://minio:9000 wukongim wukongim123 >/dev/null
    mc mb --ignore-existing local/avatar >/dev/null
    mc anonymous set download local/avatar >/dev/null
    i=0
    while [ "$i" -lt 900 ]; do
      mc cp /avatar.png "local/avatar/default/test ($i).jpg" >/dev/null
      i=$((i+1))
    done
  '
```

## 验证步骤

### 1. 验证默认头像 302 后能落到 200

```bash
curl -s -L -D - -o /dev/null http://127.0.0.1:8090/v1/users/0a13431ca09247439ba5aaafe8f93359/avatar
curl -s -L -D - -o /dev/null http://127.0.0.1:8090/v1/users/55ef804cc8b54a79a2ba8cadf17d2981/avatar
```

### 2. 验证上传头像用户不受影响

```bash
curl -s -L -D - -o /dev/null http://127.0.0.1:8090/v1/users/u_10000/avatar
curl -s -L -D - -o /dev/null http://127.0.0.1:8090/v1/users/fileHelper/avatar
```

### 3. 验证日志恢复

```bash
docker logs --since 90s fullstack_tangsengdaodaoserver_1 2>&1
```

## 注意事项

- 不要为了修头像问题直接替换成开源 Server 镜像，当前 paid 镜像与现网数据库 migration 历史不一致。
- 如果未来 `Avatar.DefaultCount` 被改动，不要继续只补 `0..899`，要按最新配置范围重建对象。
