{{/*
Determines the location of the Helm chart path
*/}}
{{- define "application-manager.chartPath" -}}
{{- if .chart.path }}
{{- printf "%s" .chart.path }}
{{- else if .Values.common.chartPath }}
{{- printf "%s" .Values.common.chartPath }}
{{- else }}
{{- printf "%s/%s" "charts" .chart.name }}
{{- end }}
{{- end }}

{{/*
Determines the location of the Helm chart repository path
*/}}
{{- define "application-manager.chartRepoPath" -}}
{{- if .chart.chart }}
{{- printf "%s" .chart.chart }}
{{- else if .Values.common.chart }}
{{- printf "%s" .Values.common.chart }}
{{- else }}
{{- print "" }}
{{- end }}
{{- end }}

{{/*
Determines the location of the Helm chart path
*/}}
{{- define "application-manager.destinationNamespace" -}}
{{- if .chart.destinationNamespace }}
{{- printf "%s" .chart.destinationNamespace }}
{{- else if .Values.common.destinationNamespace }}
{{- printf "%s" .Values.common.destinationNamespace }}
{{- else }}
{{- printf "%s" .Release.Namespace }}
{{- end }}
{{- end }}