from pathlib import Path
p=Path('/opt/wukongim-prod/src/modules/robot/feishu_group_bot.go')
s=p.read_text()
old='''\tcontent, _ := normalizeFeishuContent(incoming["content"])
\tswitch msgType {
'''
new='''\tcontent, _ := normalizeFeishuContent(incoming["content"])
\tif msgType == "post" || msgType == "interactive" {
\t\tif imageContent, ok := findFeishuImageContent(incoming, content); ok {
\t\t\tif payload, err := rb.buildFeishuImageRobotPayload(groupNo, model, imageContent); err == nil && len(payload) > 0 {
\t\t\t\treturn payload, nil
\t\t\t} else if err != nil {
\t\t\t\trb.logFeishuRobotPayloadFallback(groupNo, msgType, err)
\t\t\t}
\t\t}
\t}
\tswitch msgType {
'''
if old not in s:
    raise SystemExit('target switch block not found')
s=s.replace(old,new,1)
marker='func (rb *Robot) logFeishuRobotPayloadFallback(groupNo, msgType string, err error) {'
helper=r'''
func findFeishuImageContent(values ...interface{}) (map[string]interface{}, bool) {
	for _, value := range values {
		if content, ok := findFeishuImageContentValue(value); ok {
			return content, true
		}
	}
	return nil, false
}

func findFeishuImageContentValue(value interface{}) (map[string]interface{}, bool) {
	switch typed := value.(type) {
	case nil:
		return nil, false
	case map[string]interface{}:
		if content, ok := feishuImageContentFromMap(typed); ok {
			return content, true
		}
		for _, child := range typed {
			if content, ok := findFeishuImageContentValue(child); ok {
				return content, true
			}
		}
	case gin.H:
		return findFeishuImageContentValue(map[string]interface{}(typed))
	case []interface{}:
		for _, child := range typed {
			if content, ok := findFeishuImageContentValue(child); ok {
				return content, true
			}
		}
	case string:
		trimmed := strings.TrimSpace(typed)
		if trimmed == "" || !looksLikeFeishuJSONObject(trimmed) {
			return nil, false
		}
		var decoded interface{}
		decoder := json.NewDecoder(strings.NewReader(trimmed))
		decoder.UseNumber()
		if err := decoder.Decode(&decoded); err != nil {
			return nil, false
		}
		return findFeishuImageContentValue(decoded)
	}
	return nil, false
}

func feishuImageContentFromMap(value map[string]interface{}) (map[string]interface{}, bool) {
	if len(value) == 0 {
		return nil, false
	}
	tag := strings.TrimSpace(stringValue(value["tag"]))
	msgType := strings.TrimSpace(stringValue(value["msg_type"]))
	isImageNode := tag == "img" || tag == "image" || msgType == "image" || strings.TrimSpace(stringValue(firstFeishuValue(value, "image_key", "imageKey", "img_key", "imgKey", "image_url", "imageUrl"))) != ""
	if !isImageNode {
		return nil, false
	}

	content := map[string]interface{}{}
	if key := strings.TrimSpace(stringValue(firstFeishuValue(value, "image_key", "imageKey", "img_key", "imgKey"))); key != "" {
		content["image_key"] = key
	}
	if imageURL := strings.TrimSpace(stringValue(firstFeishuValue(value, "image_url", "imageUrl", "url", "href", "src"))); imageURL != "" {
		content["image_url"] = imageURL
	}
	for _, key := range []string{"width", "height", "image_width", "image_height"} {
		if raw, ok := value[key]; ok && strings.TrimSpace(stringValue(raw)) != "" {
			content[key] = raw
		}
	}
	if len(content) == 0 {
		return nil, false
	}
	return content, true
}

'''
if marker not in s:
    raise SystemExit('marker not found')
s=s.replace(marker, helper+marker,1)
p.write_text(s)
