{{/*
Expand the name of the chart.
*/}}
{{- define "continuum-sso.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "continuum-sso.fullname" -}}
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
Common labels
*/}}
{{- define "continuum-sso.labels" -}}
helm.sh/chart: {{ include "continuum-sso.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: continuum
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Selector labels for a given component
*/}}
{{- define "continuum-sso.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* ======================== OAuth2 Proxy ======================== */}}

{{- define "continuum-sso.oauth2-proxy.fullname" -}}
{{- include "continuum-sso.fullname" . -}}-oauth2-proxy
{{- end }}

{{/*
Generate a list of enabled OAuth2 providers
*/}}
{{- define "continuum-sso.oauth2-proxy.enabledProviders" -}}
{{- $enabled := list -}}
{{- range $name, $provider := .Values.oauth2Proxy.providers -}}
{{- if $provider.enabled -}}
{{- $enabled = append $enabled $name -}}
{{- end -}}
{{- end -}}
{{- join "," $enabled -}}
{{- end }}

{{/* ======================== Infrastructure Service References ======================== */}}

{{/*
Temporal Web UI service name
*/}}
{{- define "continuum-sso.infra.temporal-web" -}}
{{- .Values.infraReleaseName }}-temporal-web
{{- end }}

{{/*
Kafka UI service name
*/}}
{{- define "continuum-sso.infra.kafka-ui" -}}
{{- .Values.infraReleaseName }}-kafka-ui
{{- end }}

{{/*
MinIO service name
*/}}
{{- define "continuum-sso.infra.minio" -}}
{{- .Values.infraReleaseName }}-minio
{{- end }}

{{/*
Mosquitto service name
*/}}
{{- define "continuum-sso.infra.mosquitto" -}}
{{- .Values.infraReleaseName }}-mosquitto
{{- end }}

{{/* ======================== Platform Service References ======================== */}}

{{/*
Landing Page service name
*/}}
{{- define "continuum-sso.platform.landing-page" -}}
{{- .Values.platformReleaseName }}-landing-page
{{- end }}

{{/*
Workbench service name
*/}}
{{- define "continuum-sso.platform.workbench" -}}
{{- .Values.platformReleaseName }}-workbench
{{- end }}

{{/*
API Server service name
*/}}
{{- define "continuum-sso.platform.api-server" -}}
{{- .Values.platformReleaseName }}-api-server
{{- end }}

