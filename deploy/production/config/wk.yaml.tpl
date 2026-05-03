mode: "release"
addr: "tcp://0.0.0.0:5100"
httpAddr: "0.0.0.0:5001"
wsAddr: "ws://0.0.0.0:5200"
dataDir: "/root/wukongim/data"
tokenAuthOn: true
managerToken: "{{WK_MANAGER_TOKEN}}"

external:
  ip: "{{EXTERNAL_IP}}"
  tcpAddr: ""
  wsAddr: "wss://{{PUBLIC_DOMAIN}}/ws"
  apiUrl: "{{WK_PUBLIC_API_URL}}"

webhook:
  grpcAddr: "tsdd-api:6979"

conversation:
  on: true
  cacheExpire: 1d
  syncInterval: 1m
  syncOnce: 100
