{{/*
Expand the name of the chart.
*/}}
{{- define "continuum-infra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "continuum-infra.fullname" -}}
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
{{- define "continuum-infra.labels" -}}
helm.sh/chart: {{ include "continuum-infra.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: continuum
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/*
Selector labels for a given component
*/}}
{{- define "continuum-infra.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Full label set for a resource belonging to a given component, with global and
per-service overrides layered on top.
Merge precedence (highest wins): extra > global.labels > component + base labels.
Usage: {{ include "continuum-infra.componentLabels" (dict "context" $ "component" "kafka" "extra" .Values.kafka.labels) | nindent 4 }}
*/}}
{{- define "continuum-infra.componentLabels" -}}
{{- $result := dict -}}
{{- $result = mergeOverwrite $result (dict "app.kubernetes.io/component" .component) -}}
{{- $result = mergeOverwrite $result (include "continuum-infra.labels" .context | fromYaml) -}}
{{- $result = mergeOverwrite $result (.context.Values.global.labels | default dict) -}}
{{- $result = mergeOverwrite $result (.extra | default dict) -}}
{{- toYaml $result -}}
{{- end }}

{{/*
Full annotation set for a resource, with global and per-service overrides
layered on top. Renders to nothing if there are no annotations to set.
Merge precedence (highest wins): extra > global.annotations.
Usage: {{- with (include "continuum-infra.componentAnnotations" (dict "context" $ "extra" .Values.kafka.annotations)) }}
annotations:
  {{- nindent 4 . }}
{{- end }}
*/}}
{{- define "continuum-infra.componentAnnotations" -}}
{{- $result := dict -}}
{{- $result = mergeOverwrite $result (.context.Values.global.annotations | default dict) -}}
{{- $result = mergeOverwrite $result (.extra | default dict) -}}
{{- if $result -}}
{{ toYaml $result }}
{{- end -}}
{{- end }}

{{/* ======================== Component fullnames ======================== */}}

{{- define "continuum-infra.postgresql.fullname" -}}
{{- include "continuum-infra.fullname" . -}}-postgresql
{{- end }}

{{- define "continuum-infra.kafka.fullname" -}}
{{- include "continuum-infra.fullname" . -}}-kafka
{{- end }}

{{- define "continuum-infra.schema-registry.fullname" -}}
{{- include "continuum-infra.fullname" . -}}-schema-registry
{{- end }}

{{- define "continuum-infra.kafka-ui.fullname" -}}
{{- include "continuum-infra.fullname" . -}}-kafka-ui
{{- end }}

{{- define "continuum-infra.mosquitto.fullname" -}}
{{- include "continuum-infra.fullname" . -}}-mosquitto
{{- end }}

{{- define "continuum-infra.minio.fullname" -}}
{{- include "continuum-infra.fullname" . -}}-minio
{{- end }}

{{/* ======================== Secret names ======================== */}}

{{- define "continuum-infra.postgresql.secretName" -}}
{{- if .Values.postgresql.auth.existingSecret -}}
{{- .Values.postgresql.auth.existingSecret -}}
{{- else -}}
{{- include "continuum-infra.postgresql.fullname" . -}}-secret
{{- end -}}
{{- end }}

{{- define "continuum-infra.minio.secretName" -}}
{{- if .Values.minio.auth.existingSecret -}}
{{- .Values.minio.auth.existingSecret -}}
{{- else -}}
{{- include "continuum-infra.minio.fullname" . -}}-secret
{{- end -}}
{{- end }}

{{/* ======================== Kafka broker list ======================== */}}

{{/*
Generate the Kafka bootstrap server list for internal clients.
Format: PLAINTEXT://kafka-0.kafka-headless:19092,PLAINTEXT://kafka-1.kafka-headless:19092,...
*/}}
{{- define "continuum-infra.kafka.brokerList" -}}
{{- $fullname := include "continuum-infra.kafka.fullname" . -}}
{{- $replicas := int .Values.kafka.replicas -}}
{{- $brokers := list -}}
{{- range $i := until $replicas -}}
{{- $brokers = append $brokers (printf "PLAINTEXT://%s-%d.%s-headless:19092" $fullname $i $fullname) -}}
{{- end -}}
{{- join "," $brokers -}}
{{- end }}

