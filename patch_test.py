from pathlib import Path
p=Path('/opt/wukongim-prod/src/modules/robot/feishu_group_bot_payload_test.go')
# restore baseline if backup exists
backup=Path('/tmp/feishu_group_bot_payload_test.go.before2')
if backup.exists():
    p.write_text(backup.read_text())
s=p.read_text()
s=s.replace('import (\n\t"testing"\n', 'import (\n\t"testing"\n', 1)  # no extra imports needed
insert = '''
func TestBuildFeishuGroupRobotMessagePayloadPostWithEmbeddedImageUsesImagePayload(t *testing.T) {
\trb := &Robot{}
\tmodel := &feishuGroupRobotConfig{}

\tpayload, err := rb.buildFeishuGroupRobotMessagePayload("g_image", model, map[string]interface{}{
\t\t"msg_type": "post",
\t\t"content": map[string]interface{}{
\t\t\t"post": map[string]interface{}{
\t\t\t\t"zh_cn": map[string]interface{}{
\t\t\t\t\t"content": []interface{}{
\t\t\t\t\t\t[]interface{}{
\t\t\t\t\t\t\tmap[string]interface{}{"tag": "text", "text": "before"},
\t\t\t\t\t\t\tmap[string]interface{}{"tag": "img", "image_url": "https://example.com/inline.png", "width": 640, "height": 480},
\t\t\t\t\t\t},
\t\t\t\t\t},
\t\t\t\t},
\t\t\t},
\t\t},
\t})
\tif err != nil {
\t\tt.Fatalf("expected success, got error: %v", err)
\t}

\tif got := payload["type"]; got != common.Image {
\t\tt.Fatalf("expected image payload, got %v (%v)", got, payload)
\t}
\tif got := stringValue(payload["url"]); got != "https://example.com/inline.png" {
\t\tt.Fatalf("expected embedded image url, got %q", got)
\t}
\tif got := intValue(payload["width"]); got != 640 {
\t\tt.Fatalf("expected width 640, got %d", got)
\t}
\tif got := intValue(payload["height"]); got != 480 {
\t\tt.Fatalf("expected height 480, got %d", got)
\t}
}

'''
marker='func TestNormalizeFeishuDurationSeconds(t *testing.T) {'
if marker not in s:
    raise SystemExit('marker not found')
s=s.replace(marker, insert+marker, 1)
p.write_text(s)
