set -euo pipefail
cd /opt/wukongim-prod/src/deploy/production

echo '=== service health ==='
docker compose ps tsdd-api callgateway nginx

echo '=== API health ==='
curl -k -sS -i --max-time 10 'https://infoequity.qingyunshe.top/v1/ping' | sed -n '1,12p'

echo '=== image MIME verification ==='
curl -k -sS -L -o /dev/null -w 'feishu avatar => code=%{http_code} type=%{content_type} redirects=%{num_redirects}\n' --max-time 20 'https://infoequity.qingyunshe.top/v1/file/preview/common/group/063db9c564e64e7d839887a022b86189/robot/feishu_display_1777994425776.png'
curl -k -sS -L -o /dev/null -w 'chat webp => code=%{http_code} type=%{content_type} redirects=%{num_redirects}\n' --max-time 20 'https://infoequity.qingyunshe.top/v1/file/preview/chat/2/063db9c564e64e7d839887a022b86189/1777994925885531497_04abe663e6c44e608bc70beca30df5d3.webp'

echo '=== focused regression tests ==='
cd /opt/wukongim-prod/src
docker run --rm -v /opt/wukongim-prod/src:/src -v /opt/wukongim-prod/.gomodcache:/go/pkg/mod -v /opt/wukongim-prod/.gocache:/root/.cache/go-build -w /src -e GOPROXY=https://goproxy.cn,direct golang:1.20 go test ./modules/robot -run 'TestBuildFeishu(GroupRobotMessagePayloadPostWithEmbeddedImageUsesImagePayload|ShareUserRobotPayload|PreviewPath)|TestNormalizeFeishuDurationSeconds|TestBuildDingTalkGroupRobotMessagePayloadImageDownloadsAndUploads' -count=1
docker run --rm -v /opt/wukongim-prod/src:/src -v /opt/wukongim-prod/.gomodcache:/go/pkg/mod -v /opt/wukongim-prod/.gocache:/root/.cache/go-build -w /src -e GOPROXY=https://goproxy.cn,direct golang:1.20 go test ./modules/file -run 'TestMinio' -count=1

echo '=== recent post-deploy errors ==='
cd /opt/wukongim-prod/src/deploy/production
docker compose logs --since=90s --no-color nginx tsdd-api callgateway | grep -Ei ' 502 |panic|error|failed|refused' || true
