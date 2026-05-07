from pathlib import Path
p=Path('/opt/wukongim-prod/src/modules/file/service_minio.go')
s=p.read_text()
s=s.replace('fmt.Sprintf("inline; filename="%s"", filename)', 'fmt.Sprintf("inline; filename=\\\"%s\\\"", filename)')
p.write_text(s)
