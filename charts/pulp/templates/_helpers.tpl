{{- define "pulp.s3SecretName" -}}
{{- ternary (.Values.storage.s3.secret) (printf "%s-s3-storage" (include "common.names.fullname" .)) (ne .Values.storage.s3.secret "") -}}
{{- end }}