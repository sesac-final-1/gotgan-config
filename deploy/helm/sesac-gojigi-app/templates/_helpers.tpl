{{- define "app.resources" -}}
{{- toYaml (default .root.Values.defaults.resources .svc.resources) -}}
{{- end -}}
