{{/*
Expand the name of the chart.
*/}}
{{- define "homelab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "homelab.fullname" -}}
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
{{- define "homelab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "homelab.labels" -}}
app.kubernetes.io/managed-by: argocd
app.kubernetes.io/part-of: homelab
{{- end }}

{{/*
Selector labels
*/}}
{{- define "homelab.selectorLabels" -}}
app.kubernetes.io/name: {{ include "homelab.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
===================================================================
ADDON VALIDATION FUNCTIONS
===================================================================
*/}}

{{/*
Validate if addon configuration exists
Usage: {{ include "homelab.validateAddon" (list $addonName $context) }}
*/}}
{{- define "homelab.validateAddon" -}}
{{- $addonName := index . 0 -}}
{{- $context := index . 1 -}}

{{- $addonFile := printf "addons/%s/values.yaml" $addonName -}}
{{- if not ($context.Files.Get $addonFile) -}}
{{- fail (printf "Addon '%s' não encontrado no diretório addons/" $addonName) -}}
{{- end -}}
{{- end -}}

{{/*
Validate required fields
Usage: {{ include "homelab.validateRequired" (list $addonName) }}
*/}}
{{- define "homelab.validateRequired" -}}
{{- $addonName := index . 0 -}}
{{- if not $addonName -}}
{{- fail "Nome do addon é obrigatório" -}}
{{- end -}}
{{- end -}}

{{/*
Validate namespace conflicts between addons
Usage: {{ include "homelab.validateNamespace" (list $namespace $addonName $enabledAddons $context) }}
*/}}
{{- define "homelab.validateNamespace" -}}
{{- $namespace := index . 0 -}}
{{- $currentAddon := index . 1 -}}
{{- $enabledAddons := index . 2 -}}
{{- $context := index . 3 -}}

{{- range $otherAddonName := $enabledAddons -}}
{{- if ne $otherAddonName $currentAddon -}}
{{- $otherAddonPath := printf "addons/%s/values.yaml" $otherAddonName -}}
{{- $otherAddonConfig := $context.Files.Get $otherAddonPath | fromYaml -}}
{{- $otherNamespace := dig "destination" "namespace" $otherAddonName $otherAddonConfig -}}
{{- if eq $otherNamespace $namespace -}}
{{- fail (printf "Conflito de namespace: '%s' usado por '%s' e '%s'" $namespace $currentAddon $otherAddonName) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get addon configuration with fallbacks
Usage: {{ include "homelab.getAddonConfig" (list $addonName $context "fallbackNamespace") | fromYaml }}
*/}}
{{- define "homelab.getAddonConfig" -}}
{{- $addonName := index . 0 -}}
{{- $context := index . 1 -}}
{{- $fallbackNamespace := index . 2 | default $addonName -}}

{{/* Validate addon exists */}}
{{- include "homelab.validateAddon" (list $addonName $context) -}}

{{/* Load addon configuration */}}
{{- $addonFile := printf "addons/%s/values.yaml" $addonName -}}
{{- $addonConfig := $context.Files.Get $addonFile | fromYaml -}}

{{/* Apply fallbacks */}}
{{- if not $addonConfig.destination -}}
{{- $_ := set $addonConfig "destination" (dict) -}}
{{- end -}}
{{- if not $addonConfig.destination.namespace -}}
{{- $_ := set $addonConfig.destination "namespace" $fallbackNamespace -}}
{{- end -}}

{{- if not $addonConfig.project -}}
{{- $_ := set $addonConfig "project" $context.Values.global.project -}}
{{- end -}}

{{- toYaml $addonConfig -}}
{{- end -}}
