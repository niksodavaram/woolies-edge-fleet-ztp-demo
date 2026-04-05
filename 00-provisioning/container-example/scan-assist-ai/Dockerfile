# OpenShift-friendly container: UBI base, non-root, arbitrary UID
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.4

LABEL name="scan-assist-ai" \
      summary="Scan Assist AI inference service for store edge" \
      description="CPU/GPU-agnostic inference microservice." \
      io.k8s.display-name="Scan Assist AI" \
      io.openshift.non-root=true

RUN microdnf install -y python3 python3-pip && \
    pip3 install --no-cache-dir gunicorn uvicorn fastapi && \
    microdnf clean all && \
    rm -rf /var/cache/yum

RUN useradd -u 1001 -r -g 0 -d /opt/app -s /sbin/nologin scanassist && \
    mkdir -p /opt/app && chown -R 1001:0 /opt/app

WORKDIR /opt/app
COPY app/ /opt/app/

USER 1001

EXPOSE 8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "main:app"]