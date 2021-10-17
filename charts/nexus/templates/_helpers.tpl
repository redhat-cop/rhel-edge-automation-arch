{{/*
Create the name for the Nexus Setup Job.
*/}}
{{- define "nexus.setupJobName" -}}
{{- printf "%s-setup" (include "common.names.fullname" .) }}
{{- end }}