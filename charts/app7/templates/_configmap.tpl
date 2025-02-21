{{- define "flattenConfigMaps" -}}
{{- $result := dict -}}
{{- range $componentName, $componentValue := .components -}}
  {{- if and (kindIs "map" $componentValue) (hasKey $componentValue "configMap") -}}
    {{- range $configMapKey, $configMapValue := $componentValue.configMap -}}
      {{- $flatKey := printf "%s_%s" $componentName $configMapKey -}}
      {{- $_ := set $result $flatKey $configMapValue -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if hasKey . "configMap" -}}
    {{- range $configMapKey, $configMapValue := .configMap -}}
      {{- $flatKey := printf "global_%s" $configMapKey -}}
    {{- $_ := set $result $flatKey $configMapValue -}}
  {{- end -}}
{{- end -}}
{{- toYaml $result -}}
{{- end -}}

