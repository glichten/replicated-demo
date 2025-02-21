{{- if . }}
{{- range $key, $value := . }}
{{ $key }}={{ tpl $value . }}
{{- end }}
{{- end }}
