package grpcconnector

import (
	"time"
)

type GRPCStartupParams struct {
	Telemetry *GRPCTelemetry `json:"telemetry,omitempty"`
}
type GRPCTelemetry struct {
	Tracing *GRPCTracing `json:"tracing,omitempty"`
}
type GRPCTracing struct {
	Exporters []GRPCExporter `json:"exporters,omitempty"`
}
type GRPCExporter struct {
	Endpoint      string            `json:"endpoint"`
	Exporter      string            `json:"exporter"`
	BatchTimeout  time.Duration     `json:"batch_timeout"`
	ExportTimeout time.Duration     `json:"export_timeout"`
	Headers       map[string]string `json:"headers"`
	HTTPPath      string            `json:"http_path"`
}
