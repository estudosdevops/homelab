{{- define "addons.appset" -}}
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: addons-generator
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - matrix:
        generators:
          - git:
              repoURL: https://github.com/estudosdevops/homelab.git
              revision: refactor/homelab
              files:
                - path: kubernetes/addons/*/config.yaml
          - clusters: {}
  template:
    metadata:
      name: "{{ `{{ .name }}` }}-{{ `{{ .clusterName }}` }}"
      labels:
        app.kubernetes.io/name: "{{ `{{ .name }}` }}"
        app.kubernetes.io/managed-by: argocd
        app.kubernetes.io/part-of: addons
    spec:
      project: addons
      destination:
        server: "{{ `{{ .server }}` }}"
        namespace: "{{ `{{ .namespace }}` }}"
      source:
        repoURL: https://github.com/estudosdevops/homelab.git
        targetRevision: refactor/homelab
        path: "kubernetes/addons/{{ `{{ .name }}` }}"
        helm:
          valueFiles:
            - values/common.yaml
            - "values/{{ `{{ .clusterName }}` }}.yaml"
          ignoreMissingValueFiles: true
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ApplyOutOfSyncOnly=true
  # Native ArgoCD templatePatch block to dynamically inject extra configs per addon
  templatePatch: |
    metadata:
      name: "{{ `{{ .name }}` }}"
      {{ `{{- if .annotations }}` }}
      annotations:
        {{ `{{- range $k, $v := .annotations }}` }}
        {{ `{{ $k }}` }}: "{{ `{{ $v }}` }}"
        {{ `{{- end }}` }}
      {{ `{{- end }}` }}
    spec:
      syncPolicy:
        {{ `{{- if .extraSyncOptions }}` }}
        syncOptions:
          - CreateNamespace=true
          {{ `{{- range .extraSyncOptions }}` }}
          - {{ `{{ . }}` }}
          {{ `{{- end }}` }}
        {{ `{{- end }}` }}
        {{ `{{- if .retry }}` }}
        retry:
          {{ `{{- toYaml .retry | nindent 10 }}` }}
        {{ `{{- end }}` }}
{{- end -}}
