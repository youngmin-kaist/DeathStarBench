{{- define "hotelreservation.templates.service-config.json" }}
{
    "consulAddress": "consul-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}:8500",
    "jaegerAddress": "jaeger-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}:6831",
    "FrontendPort": "5000",
    "GeoPort": "8083",
    "GeoIP": "geo-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}",
    "GeoMongoAddress": "mongodb-geo-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}:27018",
    "ProfilePort": "8081",
    "ProfileIP": "profile-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}",
    "ProfileMongoAddress": "mongodb-profile-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}:27019",
    "ProfileMemcAddress": {{ include "hotel-reservation.generateMemcAddr" (list . .Values.global.memcached.HACount "memcached-profile" 11213)}},
    "RatePort": "8084",
    "RateIP": "rate-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}",
    "RateMongoAddress": "mongodb-rate-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}:27020",
    "RateMemcAddress": {{ include "hotel-reservation.generateMemcAddr" (list . .Values.global.memcached.HACount "memcached-rate" 11212)}},
    "RecommendPort": "8085",
    "RecommendIP": "recommendation-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}",
    "RecommendMongoAddress": "mongodb-recommendation-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}:27021",
    "ReservePort": "8087",
    "ReserveIP": "reservation-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}",
    "ReserveMongoAddress": "mongodb-reservation-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}:27022",
    "ReserveMemcAddress": {{ include "hotel-reservation.generateMemcAddr" (list . .Values.global.memcached.HACount "memcached-reserve" 11214)}},
    "SearchPort": "8082",
    "SearchIP": "search-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}",
    "UserPort": "8086",
    "UserIP": "user-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}",
    "UserMongoAddress": "mongodb-user-{{ include "hotel-reservation.fullname" . }}.{{ .Release.Namespace }}.svc.{{ .Values.global.serviceDnsDomain }}:27023"
}
{{- end }}

