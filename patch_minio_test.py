from pathlib import Path
p=Path('/opt/wukongim-prod/src/modules/file/service_minio_test.go')
s=p.read_text()
insert=r'''
func TestMinioDownloadURLAddsInlineContentTypeFromExtension(t *testing.T) {
	got, err := minioDownloadURL("https://example.com/minio", "chat/2/g/demo.png", "demo.png")
	require.NoError(t, err)
	require.Contains(t, got, "response-content-disposition=inline")
	require.Contains(t, got, "response-content-type=image%2Fpng")
}

'''
marker='func TestMinioUploadStreamUsesBackPressure(t *testing.T) {'
if marker not in s:
    raise SystemExit('marker not found')
if 'TestMinioDownloadURLAddsInlineContentTypeFromExtension' not in s:
    s=s.replace(marker, insert+marker,1)
p.write_text(s)
