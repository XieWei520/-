from pathlib import Path
p=Path('/opt/wukongim-prod/src/modules/robot/dingtalk_group_bot_test.go')
s=p.read_text()
if 'func (s *dingTalkMemoryFileService) InitiateMultipartUpload' not in s:
    marker='func (s *dingTalkMemoryFileService) DownloadURL(path string, filename string) (string, error) {\n\treturn fmt.Sprintf("https://robot.test/%s", strings.TrimPrefix(path, "/")), nil\n}\n\n'
    insert='''func (s *dingTalkMemoryFileService) InitiateMultipartUpload(filePath string, contentType string, fileSize int64, chunkSize int64) (map[string]interface{}, error) {
\tpanic("unexpected call to InitiateMultipartUpload")
}

func (s *dingTalkMemoryFileService) UploadMultipartPart(filePath string, uploadID string, partNumber int, reader io.Reader) error {
\tpanic("unexpected call to UploadMultipartPart")
}

func (s *dingTalkMemoryFileService) CompleteMultipartUpload(filePath string, contentType string, uploadID string, parts []int) (map[string]interface{}, error) {
\tpanic("unexpected call to CompleteMultipartUpload")
}

func (s *dingTalkMemoryFileService) AbortMultipartUpload(uploadID string) error {
\tpanic("unexpected call to AbortMultipartUpload")
}

'''
    if marker not in s:
        raise SystemExit('marker not found')
    s=s.replace(marker, marker+insert, 1)
p.write_text(s)
