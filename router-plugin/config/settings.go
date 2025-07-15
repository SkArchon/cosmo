package config

import "time"

type ExporterProtocolType string
type ExporterTemporality string

const (
	ExporterOLTPHTTP ExporterProtocolType = "http"
	ExporterOLTPGRPC ExporterProtocolType = "grpc"
)

type StartupConfig struct {
	Telemetry *Telemetry `json:"telemetry,omitempty"`
}

type Telemetry struct {
	Tracing *Tracing `json:"tracing,omitempty"`
}

type Tracing struct {
	Exporters []Exporter `json:"exporters,omitempty"`
}

type Exporter struct {
	Endpoint      string               `json:"endpoint"`
	Exporter      ExporterProtocolType `json:"exporter"`
	BatchTimeout  time.Duration        `json:"batch_timeout"`
	ExportTimeout time.Duration        `json:"export_timeout"`
	Headers       map[string]string    `json:"headers"`
	HTTPPath      string               `json:"http_path"`
}
