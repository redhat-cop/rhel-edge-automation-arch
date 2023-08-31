{{- define "imageBuilderReplicas" }}
{{- $replicas := 0 }}
{{- range $pool := .Values.imageBuilderPools }}
{{- $replicas = add $replicas $pool.replicas }}
{{- end }}
{{- printf "%d" $replicas }}
{{- end }}
