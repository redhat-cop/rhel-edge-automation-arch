
{{/*
Generates the RHEL labels and annotations that depend on the used RHEL version
*/}}

{{- define "kubevirtLabel" -}}
    {{- if eq $.Values.osDistribution "rhel" }}
        {{- printf "os.template.kubevirt.io/rhel%s: 'true'" .Values.rhel.version }}
    {{- else if eq $.Values.osDistribution "fedora" }}
            {{- printf "os.template.kubevirt.io/fedora%s: 'true'" .Values.fedora.version.major }}
    {{- end }}
{{- end }}

{{- define "kubevirtAnnotation" -}}
    {{- if eq $.Values.osDistribution "rhel" }}
        {{- printf "name.os.template.kubevirt.io/rhel%s: Red Hat Enterprise Linux 8.0 or higher\n" .Values.rhel.version }}
        {{- printf "description: RHEL %s With Image Builder" .Values.rhel.version}}
    {{- else if eq $.Values.osDistribution "fedora" }}
            {{- printf "name.os.template.kubevirt.io/fedora%[1]s: Fedora Linux %[1]s or higher\n" .Values.fedora.version.major }} 
            {{- printf "description: Fedora %s With Image Builder" .Values.fedora.version.major}}
    {{- end }}
{{- end }}


{{- define "imageBuilderSource" -}}
    {{- if eq $.Values.osDistribution "rhel" }}
        {{- printf "rhel-%s-x86_64-kvm.qcow2" .Values.rhel.version }}
    {{- else if eq $.Values.osDistribution "fedora" }}
            {{- printf "Fedora-Cloud-Base-%s-%s.%s.qcow2" .Values.fedora.version.major .Values.fedora.version.minor .Values.fedora.arch }}
    {{- end}}
{{- end}}