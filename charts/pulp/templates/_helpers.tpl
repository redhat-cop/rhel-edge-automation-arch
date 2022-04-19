{{- define "pulp.s3SecretName" -}}
{{- ternary (.Values.storage.s3.secret) (printf "%s-s3-storage" (include "common.names.fullname" .)) (ne .Values.storage.s3.secret "") -}}
{{- end }}

{{/*
Create the image path for the passed in image field
*/}}
{{- define "pulp.image" -}}
{{- if eq (substr 0 7 .version) "sha256:" -}}
{{- printf "%s/%s@%s" .registry .repository .version -}}
{{- else -}}
{{- printf "%s/%s:%s" .registry .repository .version -}}
{{- end -}}
{{- end -}}