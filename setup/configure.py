import json
import os
import secrets
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

import boto3
import psycopg
from psycopg import sql


def read_secret(client, secret_id):
    try:
        return client.get_secret_value(SecretId=secret_id)["SecretString"]
    except client.exceptions.ResourceNotFoundException:
        return None


def prepare_database(client):
    host = os.environ["DB_HOST"]
    app_secret = os.environ["APP_SECRET"]
    admin = json.loads(read_secret(client, os.environ["ADMIN_SECRET"]))
    settings = {
        "host": host,
        "sslmode": "verify-full",
        "sslrootcert": "/opt/setup/rds-ca.pem",
        "connect_timeout": 10,
    }

    with psycopg.connect(
        dbname="postgres",
        user=admin["username"],
        password=admin["password"],
        autocommit=True,
        **settings,
    ) as connection:
        connection.execute("SELECT pg_advisory_lock(314159)")

        dsn = read_secret(client, app_secret)
        if dsn is None:
            password = secrets.token_urlsafe(36)
            dsn = f"postgres://memos_app:{password}@{host}:5432/memos?sslmode=require"
            client.put_secret_value(SecretId=app_secret, SecretString=dsn)

        credentials = urlsplit(dsn)
        if (
            credentials.hostname != host
            or credentials.username != "memos_app"
            or credentials.path != "/memos"
            or not credentials.password
        ):
            raise RuntimeError("Unexpected Memos database connection string")

        password = unquote(credentials.password)
        role_exists = connection.execute(
            "SELECT 1 FROM pg_roles WHERE rolname = 'memos_app'"
        ).fetchone()
        if not role_exists:
            connection.execute(
                sql.SQL("CREATE ROLE memos_app LOGIN PASSWORD {}").format(
                    sql.Literal(password)
                )
            )

        database_exists = connection.execute(
            "SELECT 1 FROM pg_database WHERE datname = 'memos'"
        ).fetchone()
        if not database_exists:
            connection.execute(
                sql.SQL("GRANT memos_app TO {} WITH SET TRUE").format(
                    sql.Identifier(admin["username"])
                )
            )
            connection.execute("CREATE DATABASE memos OWNER memos_app")

        with psycopg.connect(
            dbname="memos", user="memos_app", password=password, **settings
        ):
            pass

    return dsn


def configure_website(client, dsn):
    secret_id = os.environ["WEBSITE_SECRET"]
    password = read_secret(client, secret_id)
    if password is None:
        password = secrets.token_urlsafe(36)
        client.put_secret_value(SecretId=secret_id, SecretString=password)

    config = {
        "instanceSettings": [
            {
                "name": "instance/settings/GENERAL",
                "generalSetting": {"disallowUserRegistration": True},
            },
            {
                "name": "instance/settings/STORAGE",
                "storageSetting": {
                    "defaultStorageId": "database",
                    "storages": [{"id": "database", "type": "DATABASE"}],
                },
            },
        ],
        "users": [
            {
                "name": "users/admin",
                "username": "admin",
                "role": "ADMIN",
                "password": "${env:MEMOS_WEBSITE_PASSWORD}",
            }
        ],
        "lifecycle": [
            {"resource": "users/admin", "preventDestroy": True, "writeOnlyVersion": 1}
        ],
    }

    with tempfile.TemporaryDirectory() as directory:
        Path(directory, "memos.json").write_text(json.dumps(config), encoding="utf-8")
        result = subprocess.run(
            ["memos", "config", "apply", "--config-dir", directory],
            env={
                **os.environ,
                "MEMOS_DATA": "/tmp",
                "MEMOS_DRIVER": "postgres",
                "MEMOS_DSN": dsn,
                "MEMOS_WEBSITE_PASSWORD": password,
            },
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode:
            raise RuntimeError(f"Memos config apply exited with {result.returncode}")


def main():
    client = boto3.client("secretsmanager")
    try:
        dsn = prepare_database(client)
    except Exception as error:
        raise SystemExit(f"PostgreSQL setup failed ({type(error).__name__}).") from None
    print("PostgreSQL database and app login are ready.", flush=True)

    try:
        configure_website(client, dsn)
    except Exception as error:
        detail = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        raise SystemExit(f"Memos website setup failed ({detail}).") from None
    print("Memos website admin and storage are configured.", flush=True)


if __name__ == "__main__":
    main()