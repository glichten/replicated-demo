{{/*
Render ingress rules
This template generates the rules section of the Ingress resource.
It handles both host-based and path-based routing configurations.

Parameters:
  - . : The rules object from the values file

Usage:
  {{- include "ingressRules" $component.ingress.rules }}
*/}}
{{- define "ingressRules" -}}
{{- range $ruleName, $rule := . }}
{{- if ne $rule.enabled false }}
{{- if $rule.host }}
- host: {{ $rule.host }}
  http:
    paths:
    {{- range $pathName, $pathConfig := $rule.paths }}
    {{- if ne $pathConfig.enabled false }}
    - path: {{ $pathConfig.pathObject.path }}
      pathType: {{ $pathConfig.pathObject.pathType }}
      backend:
        service:
          name: {{ $pathConfig.pathObject.backend.service.name }}
          port: 
            number: {{ $pathConfig.pathObject.backend.service.port.number }}
    {{- end }}
    {{- end }}
{{- else }}
- http:
    paths:
    {{- range $pathName, $pathConfig := $rule.paths }}
    {{- if ne $pathConfig.enabled false }}
    - path: {{ $pathConfig.pathObject.path }}
      pathType: {{ $pathConfig.pathObject.pathType }}
      backend:
        service:
          name: {{ $pathConfig.pathObject.backend.service.name }}
          port: 
            number: {{ $pathConfig.pathObject.backend.service.port.number }}
    {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Render TLS configuration
This template generates the tls section of the Ingress resource.
It handles configurations with hosts, secretName, or both.

Parameters:
  - . : The tls object from the values file

Usage:
  {{- include "ingressTLS" $component.ingress.tls }}
*/}}
{{- define "ingressTLS" -}}
{{- range $tlsName, $tlsConfig := . }}
{{- if ne $tlsConfig.enabled false }}
{{- if $tlsConfig.hosts }}
- hosts: {{ $tlsConfig.hosts | toJson }}
  {{- if $tlsConfig.secretName }}
  secretName: {{ $tlsConfig.secretName }}
  {{- end }}
{{- else if $tlsConfig.secretName }}
- secretName: {{ $tlsConfig.secretName }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
