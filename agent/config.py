import boto3
import json
import logging
import os

logger = logging.getLogger(__name__)

_loaded = False


def load_secrets(region: str = "ap-northeast-2") -> None:
    """Secrets Manager의 economic-reporter 시크릿을 os.environ에 주입."""
    global _loaded
    if _loaded:
        return
    try:
        client = boto3.client("secretsmanager", region_name=region)
        value = client.get_secret_value(SecretId="economic-reporter")
        secrets = json.loads(value["SecretString"])
        for k, v in secrets.items():
            if k not in os.environ:
                os.environ[k] = v
        _loaded = True
        logger.info("Secrets loaded from Secrets Manager")
    except Exception as e:
        logger.warning("Failed to load secrets from Secrets Manager: %s", e)
