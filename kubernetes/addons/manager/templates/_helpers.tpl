{{/*
Common labels applied to every generated ApplicationSet.
*/}}
{{- define "addon-factory.labels" -}}
app.kubernetes.io/name: {{ .Values.addonName }}
app.kubernetes.io/managed-by: argocd
app.kubernetes.io/part-of: addons
{{- end -}}
