mode: "{{TSDD_MODE}}"
addr: ":8090"
grpcAddr: "0.0.0.0:6979"
appName: "{{TSDD_APP_NAME}}"
adminpwd: "{{TSDD_ADMIN_PWD}}"
rootDir: "/home/data"
messageSaveAcrossDevice: true
phoneSearchOff: false
onlineStatusOn: true

wukongIM:
  apiURL: "http://wukongim:5001"
  managerToken: "{{WK_MANAGER_TOKEN}}"

db:
  mysqlAddr: "{{MYSQL_DSN}}"
  redisAddr: "redis:6379"
  redisPass: "{{REDIS_PASSWORD}}"

external:
  ip: "{{EXTERNAL_IP}}"
  baseURL: "{{TSDD_BASE_URL}}"
  webLoginURL: "{{TSDD_WEB_LOGIN_URL}}"

logger:
  level: 2
  dir: "/home/logs"
  lineNum: false

smsCode: "{{TSDD_SMS_CODE}}"

fileService: "minio"
minio:
  url: "{{MINIO_INTERNAL_URL}}"
  uploadURL: "{{MINIO_INTERNAL_URL}}"
  downloadURL: "{{MINIO_DOWNLOAD_URL}}"
  accessKeyID: "{{MINIO_ROOT_USER}}"
  secretAccessKey: "{{MINIO_ROOT_PASSWORD}}"

cache:
  tokenExpire: 30d
  loginDeviceCacheExpire: 10m
  friendApplyExpire: 15d
