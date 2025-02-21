static_resources:
  listeners:
  - name: http-dashboard
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 8085
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_dashboard
          access_log:
            name: envoy.access_loggers.file
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
              path: /dev/stdout
          use_remote_address: true
          xff_num_trusted_hops: 0
          http_filters:
          - name: envoy.filters.http.ext_authz
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
              http_service:
                server_uri:
                  uri: /api
                  cluster: admin-dashboard
                  timeout: {{ .externalAuthzTimeout }}
                path_prefix: "/api/internal/token/authorize"
                authorization_request:
                  allowed_headers:
                    patterns:
                    - exact: authorization
                      ignore_case: true
                    - exact: x-client
                      ignore_case: true
                    - exact: x-request-id
                      ignore_case: true
                authorization_response:
                  allowed_upstream_headers:
                    patterns:
                    - exact: authorization
                      ignore_case: true
              failure_mode_allow: false
              status_on_error:
                code: 500
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
  clusters:
  - name: admin-dashboard
    connect_timeout: 720s
    type: strict_dns
    dns_lookup_family: V4_ONLY
    lb_policy: round_robin
    load_assignment:
      cluster_name: admin-dashboard
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: admin-dashboard
                port_value: 80
  {{- if .webDeployed }}
  - name: web
    connect_timeout: 720s
    type: strict_dns
    dns_lookup_family: V4_ONLY
    lb_policy: round_robin
    load_assignment:
      cluster_name: web
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: web
                port_value: 80
  {{- end }}
admin:
  access_log_path: /dev/stdout
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9901

{{- if .raw }}
{{- if eq .global.environment "dev" }}
{{ .raw }}
{{- else }}
{{- fail "Attempting to pass in raw config in an environment that is not DEV!" }}
{{- end }}
{{- end }}
