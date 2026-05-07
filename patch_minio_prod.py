from pathlib import Path
p=Path('/opt/wukongim-prod/src/modules/file/service_minio.go')
s=p.read_text()
if '"mime"' not in s:
    s=s.replace('"io"\n', '"io"\n\t"mime"\n', 1)
if '"path/filepath"' not in s:
    s=s.replace('"net/url"\n', '"net/url"\n\t"path/filepath"\n', 1)
start=s.index('func (sm *ServiceMinio) DownloadURL')
end=s.index('func (sm *ServiceMinio) ReadFile', start)
new='''func (sm *ServiceMinio) DownloadURL(ph string, filename string) (string, error) {
	minioConfig := sm.ctx.GetConfig().Minio
	return minioDownloadURL(minioConfig.DownloadURL, ph, filename)
}

func minioDownloadURL(downloadBaseURL string, ph string, filename string) (string, error) {
	vals := url.Values{}
	vals.Set("response-content-disposition", fmt.Sprintf("inline; filename=\"%s\"", filename))
	if contentType := strings.TrimSpace(mime.TypeByExtension(strings.ToLower(filepath.Ext(filename)))); contentType != "" {
		vals.Set("response-content-type", contentType)
	}
	result, err := url.JoinPath(downloadBaseURL, ph)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%s?%s", result, vals.Encode()), nil
}

'''
s=s[:start]+new+s[end:]
p.write_text(s)
