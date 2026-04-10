{{/*
Expand the name of the chart.
*/}}
{{- define "continuum-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "continuum-platform.fullname" -}}
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
{{- define "continuum-platform.labels" -}}
helm.sh/chart: {{ include "continuum-platform.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: continuum
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "continuum-platform.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* ======================== Infra service references ======================== */}}

{{- define "continuum-platform.infra.temporal.address" -}}
{{- .Values.infra.temporal.host -}}:{{- .Values.infra.temporal.port -}}
{{- end }}

{{- define "continuum-platform.infra.db.url" -}}
jdbc:postgresql://{{ .Values.infra.postgresql.host }}:{{ .Values.infra.postgresql.port }}/{{ .Values.infra.postgresql.database }}
{{- end }}

{{- define "continuum-platform.infra.mosquitto.uri" -}}
tcp://{{ .Values.infra.mosquitto.host }}:{{ .Values.infra.mosquitto.port }}
{{- end }}

{{/* ======================== Secret names ======================== */}}

{{- define "continuum-platform.postgresql.secretName" -}}
{{- if .Values.secrets.existingPostgresqlSecret -}}
{{- .Values.secrets.existingPostgresqlSecret -}}
{{- else -}}
{{- include "continuum-platform.fullname" . -}}-postgresql-secret
{{- end -}}
{{- end }}

{{- define "continuum-platform.minio.secretName" -}}
{{- if .Values.secrets.existingMinioSecret -}}
{{- .Values.secrets.existingMinioSecret -}}
{{- else -}}
{{- include "continuum-platform.fullname" . -}}-minio-secret
{{- end -}}
{{- end }}

{{/* ======================== Component fullnames ======================== */}}

{{- define "continuum-platform.api-server.fullname" -}}
{{- include "continuum-platform.fullname" . -}}-api-server
{{- end }}

{{- define "continuum-platform.orchestration-service.fullname" -}}
{{- include "continuum-platform.fullname" . -}}-orchestration-service
{{- end }}

{{- define "continuum-platform.message-bridge.fullname" -}}
{{- include "continuum-platform.fullname" . -}}-message-bridge
{{- end }}

{{- define "continuum-platform.feature-base.fullname" -}}
{{- include "continuum-platform.fullname" . -}}-feature-base
{{- end }}

{{- define "continuum-platform.feature-cheminformatics.fullname" -}}
{{- include "continuum-platform.fullname" . -}}-feature-cheminformatics
{{- end }}

{{- define "continuum-platform.cluster-manager.fullname" -}}
{{- include "continuum-platform.fullname" . -}}-cluster-manager
{{- end }}

{{- define "continuum-platform.cloud-gateway.fullname" -}}
{{- include "continuum-platform.fullname" . -}}-cloud-gateway
{{- end }}


