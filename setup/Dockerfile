ARG MEMOS_IMAGE
FROM ${MEMOS_IMAGE} AS memos

FROM python:3.13-slim@sha256:e48f59cdba69a3cbd9ed2cf0f348d90d45a8d350d98134cf1070bc106ee9ed90

RUN pip install --no-cache-dir boto3==1.42.70 "psycopg[binary]==3.3.3"
RUN mkdir -m 755 /opt/setup
ADD --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /opt/setup/rds-ca.pem
COPY --from=memos /usr/local/memos/memos /usr/local/bin/memos
COPY configure.py /opt/setup/configure.py

USER 10001:10001
WORKDIR /tmp
ENTRYPOINT ["python", "/opt/setup/configure.py"]