{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "labels" -}}
helm.sh/chart: {{ include "chart" . }}
{{ include "selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "selectorLabels" -}}
{{- $componentName := include "componentName" . -}}
{{- printf "app: %s" $componentName }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate container ports
*/}}
{{- define "containerPorts" -}}
{{- $sortedKeys := keys .ports | sortAlpha }}
{{- range $key := $sortedKeys }}
  {{- $portConfig := index $.ports $key }}
  {{- if or (not (hasKey $portConfig "enabled")) $portConfig.enabled }}
- containerPort: {{ $portConfig.containerPort }}
    {{- if and (hasKey $portConfig "podPortName") (not $portConfig.podPortName) }}
    {{- else if $portConfig.name }}
  name: {{ $portConfig.name }}
    {{- end }}
    {{- if $portConfig.protocol }}
  protocol: {{ $portConfig.protocol }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Generate container environment variables
*/}}
{{- define "containerEnv" -}}
{{- $sortedKeys := keys .env | sortAlpha }}
{{- range $key := $sortedKeys }}
  {{- $envVar := index $.env $key }}
  {{- if or (not (hasKey $envVar "enabled")) $envVar.enabled }}
- name: {{ $envVar.name | default $key }}
    {{- if $envVar.valueFrom }}
  valueFrom:
    {{- toYaml $envVar.valueFrom | nindent 4 }}
    {{- else if ($envVar.value | toString) }}
  value: {{ $envVar.value | quote }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Generate container probes
*/}}
{{- define "containerProbes" -}}
{{- with .probes }}
{{- if .readiness }}
readinessProbe:
  {{- toYaml .readiness | nindent 2 }}
{{- end }}
{{- if .liveness }}
livenessProbe:
  {{- toYaml .liveness | nindent 2 }}
{{- end }}
{{- if .startup }}
startupProbe:
  {{- toYaml .startup | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate component name
*/}}
{{- define "componentName" -}}
{{- $globalName := include "fullname" .global -}}
{{- if .component.nameOverride -}}
{{- .component.nameOverride -}}
{{- else -}}
{{- printf "%s-%s" $globalName .componentName | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Get exposed ports for service
*/}}
{{- define "exposedServicePorts" -}}
{{- $result := dict }}
{{- range $containerName, $container := .deployment.containers }}
  {{- if $container.enabled }}
    {{- range $portKey, $portConfig := $container.ports }}
      {{- if and (or (not (hasKey $portConfig "enabled")) $portConfig.enabled) (or (not (hasKey $portConfig "exposed")) $portConfig.exposed) }}
        {{- $_ := set $result $portKey $portConfig }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $result | toYaml }}
{{- end }}

{{/*
Generate service ports
*/}}
{{- define "servicePorts" -}}
{{- $ports := include "exposedServicePorts" . | fromYaml }}
{{- $sortedKeys := keys $ports | sortAlpha }}
{{- range $key := $sortedKeys }}
{{- $portInfo := index $ports $key }}
- port: {{ $portInfo.servicePort }}
  targetPort: {{ if and $portInfo.referenceContainerPortName $portInfo.name }}{{ $portInfo.name }}{{ else }}{{ $portInfo.containerPort }}{{ end }}
  {{- if or $portInfo.servicePortNameOverride $portInfo.name }}
  name: {{ $portInfo.servicePortNameOverride | default $portInfo.name }}
  {{- end }}
  protocol: {{ $portInfo.protocol | default "TCP" }}
{{- end }}
{{- end }}

{{/*
Generate podMonitoring endpoints
*/}}
{{- define "podMonitoringEndpoints" -}}
{{- $sortedKeys := keys .endpoints | sortAlpha }}
{{- range $key := $sortedKeys }}
  {{- $endpoint := index $.endpoints $key }}
- port: {{ $endpoint.port }}
  {{- if $endpoint.interval }}
  interval: {{ $endpoint.interval | quote }}
  {{- end }}
  {{- if $endpoint.path }}
  path: {{ $endpoint.path | quote }}
  {{- end }}
  {{- if $endpoint.params }}
  params:
    {{ toYaml $endpoint.params | nindent 4 }}
  {{- end }}
  {{- if $endpoint.scheme }}
  scheme: {{ $endpoint.scheme | quote }}
  {{- end }}
  {{- if $endpoint.timeout }}
  timeout: {{ $endpoint.timeout | quote }}
  {{- end }}
  {{- if $endpoint.metricRelabeling }}
  metricRelabeling:
    {{ toYaml $endpoint.metricRelabeling | nindent 4 }}
  {{- end }}
  {{- if $endpoint.HTTPClientConfig }}
  HTTPClientConfig:
    {{ toYaml $endpoint.HTTPClientConfig | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Generate volume mounts for a container
*/}}
{{- define "containerVolumeMounts" -}}
{{- $sortedKeys := keys .volumeMounts | sortAlpha }}
{{- range $key := $sortedKeys }}
  {{- $mountConfig := index $.volumeMounts $key }}
  {{- if ne ($mountConfig.enabled) false }}
- name: {{ $mountConfig.volume.name }}
  mountPath: {{ $mountConfig.mountPath }}
  {{- if $mountConfig.readOnly }}
  readOnly: true
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Generate volumes for a deployment
*/}}
{{- define "deploymentVolumes" -}}
{{- $volumes := dict }}
{{- range $containerName, $container := .deployment.containers }}
  {{- if $container.enabled }}
    {{- range $mountKey, $mountConfig := $container.volumeMounts }}
      {{- if ne ($mountConfig.enabled) false }}
        {{- $_ := set $volumes $mountConfig.volume.name $mountConfig.volume }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- if .deployment.additionalVolumes }}
  {{- range $volumeName, $volumeConfig := .deployment.additionalVolumes }}
    {{- if $volumeConfig.enabled }}
      {{- $_ := set $volumes $volumeName $volumeConfig }}
    {{- end }}
  {{- end }}
{{- end }}
{{- $sortedVolumeKeys := keys $volumes | sortAlpha }}
{{- range $volumeName := $sortedVolumeKeys }}
  {{- $volumeConfig := index $volumes $volumeName }}
- name: {{ $volumeName }}
  {{- toYaml (omit $volumeConfig "name") | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Build the image values for a component
*/}}
{{- define "globalImageConfig" -}}
{{- $globalValues := .global.Values }}
{{- $container := .container }}
{{- $name := "" }}
{{- $tag := "" }}
{{- $pullPolicy := "IfNotPresent" }}
{{- if and (not $container.useLocalImageConfig) $container.globalName (hasKey $globalValues.global $container.globalName) (hasKey (index $globalValues.global $container.globalName) "image") }}
  {{- $globalImage := (index $globalValues.global $container.globalName).image }}
  {{- $name = $globalImage.name }}
  {{- $tag = $globalImage.tag | default "" }}
  {{- if $tag }}
  {{- $pullPolicy = $globalImage.pullPolicy | default "IfNotPresent" }}
  {{- else }}
  {{- $pullPolicy = $globalImage.pullPolicy | default "Always" }}
  {{- end }}
{{- else if $container.image }}
  {{- $name = $container.image.name }}
  {{- $tag = $container.image.tag | default "" }}
  {{- if $tag }}
  {{- $pullPolicy = $container.image.pullPolicy | default "IfNotPresent" }}
  {{- else }}
  {{- $pullPolicy = $container.image.pullPolicy | default "Always" }}
  {{- end }}
{{- end }}
{{- if $name }}
image: {{ $name }}{{ if $tag }}:{{ $tag }}{{ end }}
imagePullPolicy: {{ $pullPolicy }}
{{- else }}
{{- fail "No valid image configuration found" }}
{{- end }}
{{- end }}
