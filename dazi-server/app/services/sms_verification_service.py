"""Alibaba Cloud PNVS SMS verification integration.

This module keeps provider-specific request and response details outside the
authentication routes. It intentionally never returns or logs verification
codes.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Protocol


class SmsVerificationError(RuntimeError):
    """Base error for SMS verification operations."""


class SmsConfigurationError(SmsVerificationError):
    """Raised when the PNVS integration is disabled or incomplete."""


class SmsProviderError(SmsVerificationError):
    """Raised when PNVS cannot complete a request."""


class SmsVerificationService(Protocol):
    async def send_code(self, phone: str) -> None:
        """Send a verification code to a normalized phone number."""

    async def verify_code(self, phone: str, code: str) -> bool:
        """Return whether PNVS accepted the submitted code."""


@dataclass(frozen=True)
class SmsVerificationConfig:
    access_key_id: str
    access_key_secret: str
    region_id: str
    scheme_name: str
    sign_name: str
    template_code: str
    enabled: bool


def build_send_parameters(phone: str, config: SmsVerificationConfig) -> dict[str, Any]:
    """Build the documented PNVS request for a dynamic six-digit code."""
    return {
        "scheme_name": config.scheme_name,
        "country_code": "86",
        "phone_number": phone,
        "sign_name": config.sign_name,
        "template_code": config.template_code,
        "template_param": '{"code":"##code##","min":"5"}',
        "code_length": 6,
        "valid_time": 300,
        "duplicate_policy": 1,
        "interval": 60,
        "code_type": 1,
        "return_verify_code": False,
    }


def build_check_parameters(
    phone: str,
    code: str,
    config: SmsVerificationConfig,
) -> dict[str, Any]:
    """Build a PNVS check request using the same scheme as the send request."""
    return {
        "scheme_name": config.scheme_name,
        "country_code": "86",
        "phone_number": phone,
        "verify_code": code,
        "case_auth_policy": 2,
    }


def _field(value: Any, name: str, default: Any = None) -> Any:
    if isinstance(value, dict):
        return value.get(name, default)
    return getattr(value, name, default)


def _response_body(response: Any) -> Any:
    return _field(response, "body", response)


def send_response_succeeded(response: Any) -> bool:
    body = _response_body(response)
    return _field(body, "code") == "OK" and _field(body, "success") is True


def verify_response_passed(response: Any) -> bool:
    body = _response_body(response)
    model = _field(body, "model")
    return (
        _field(body, "code") == "OK"
        and _field(body, "success") is True
        and _field(model, "verify_result") == "PASS"
    )


class AliyunSmsVerificationService:
    """Async adapter for Alibaba Cloud PNVS SMS authentication APIs."""

    endpoint = "dypnsapi.aliyuncs.com"

    def __init__(self, config: SmsVerificationConfig):
        self.config = config
        self._client: Any = None

    def _validate_config(self) -> None:
        required = (
            self.config.access_key_id,
            self.config.access_key_secret,
            self.config.sign_name,
            self.config.template_code,
        )
        if not self.config.enabled or not all(value.strip() for value in required):
            raise SmsConfigurationError("PNVS SMS verification is not configured")

    def _sdk(self):
        try:
            from alibabacloud_dypnsapi20170525 import models as dypns_models
            from alibabacloud_dypnsapi20170525.client import (
                Client as Dypnsapi20170525Client,
            )
            from alibabacloud_tea_openapi import models as open_api_models
            from alibabacloud_tea_util import models as util_models
        except ImportError as exc:
            raise SmsConfigurationError("PNVS Python SDK is not installed") from exc
        return dypns_models, Dypnsapi20170525Client, open_api_models, util_models

    def _get_client(self, client_type: Any, open_api_models: Any) -> Any:
        if self._client is None:
            client_config = open_api_models.Config(
                access_key_id=self.config.access_key_id,
                access_key_secret=self.config.access_key_secret,
                region_id=self.config.region_id,
            )
            client_config.endpoint = self.endpoint
            self._client = client_type(client_config)
        return self._client

    async def send_code(self, phone: str) -> None:
        self._validate_config()
        dypns_models, client_type, open_api_models, util_models = self._sdk()
        client = self._get_client(client_type, open_api_models)
        request = dypns_models.SendSmsVerifyCodeRequest(
            **build_send_parameters(phone, self.config)
        )
        try:
            response = await client.send_sms_verify_code_with_options_async(
                request,
                util_models.RuntimeOptions(),
            )
        except Exception as exc:
            raise SmsProviderError("PNVS send request failed") from exc
        if not send_response_succeeded(response):
            raise SmsProviderError("PNVS rejected send request")

    async def verify_code(self, phone: str, code: str) -> bool:
        self._validate_config()
        dypns_models, client_type, open_api_models, util_models = self._sdk()
        client = self._get_client(client_type, open_api_models)
        request = dypns_models.CheckSmsVerifyCodeRequest(
            **build_check_parameters(phone, code, self.config)
        )
        try:
            response = await client.check_sms_verify_code_with_options_async(
                request,
                util_models.RuntimeOptions(),
            )
        except Exception as exc:
            raise SmsProviderError("PNVS check request failed") from exc
        return verify_response_passed(response)
