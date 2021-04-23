#
# Copyright 2017 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#ARG SPARK_IMAGE=gcr.io/spark-operator/spark:v3.0.0
ARG SPARK_IMAGE=repo-java.open.ch:18080/spark-operator/spark:v3.0.0

#FROM golang:1.15.2-alpine as builder
FROM repo-java.open.ch:18080/golang:1.15.2-alpine as builder

WORKDIR /workspace

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
# curl http://proxy.open.ch:8081/ca/ca.crt -o /usr/local/share/ca-certificates/open.ca.crt && update-ca-certificates
COPY ca.crt /usr/local/share/ca-certificates/open.ca.crt
RUN update-ca-certificates
RUN go mod download

# Copy the go source code
COPY main.go main.go
COPY pkg/ pkg/

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -a -o /usr/bin/spark-operator main.go

FROM ${SPARK_IMAGE}
USER root
COPY --from=builder /usr/bin/spark-operator /usr/bin/
COPY ca.crt /usr/local/share/ca-certificates/open.ca.crt
RUN update-ca-certificates
RUN printf "Acquire::http::Proxy \"http://proxy.open.ch:8080\";\nAcquire::https::Proxy \"http://proxy.open.ch:8080\";" > /etc/apt/apt.conf.d/proxy.conf
RUN apt-get update \
    && apt-get install -y openssl curl tini \
    && rm -rf /var/lib/apt/lists/*
COPY hack/gencerts.sh /usr/bin/

COPY entrypoint.sh /usr/bin/
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
