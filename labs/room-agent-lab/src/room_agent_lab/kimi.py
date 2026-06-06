from __future__ import annotations

import json
import os
import re
import socket
import time
import urllib.error
import urllib.request
from typing import Any


class KimiClient:
    def __init__(
        self,
        api_key: str | None = None,
        model: str | None = None,
        base_url: str | None = None,
        timeout: float = 90.0,
        retries: int = 2,
    ) -> None:
        self.api_key = api_key or _env_first("KIMI_API_KEY", "MOONSHOT_API_KEY", "LLM_API_KEY")
        self.model = model or _env_first("KIMI_MODEL", "MOONSHOT_MODEL", "LLM_MODEL") or "kimi-k2.5"
        self.base_url = (base_url or _env_first("KIMI_BASE_URL", "MOONSHOT_BASE_URL", "LLM_BASE_URL") or "https://api.moonshot.cn/v1").rstrip("/")
        self.timeout = timeout
        self.retries = retries

    def chat_json(self, messages: list[dict[str, str]], temperature: float = 0.2) -> dict[str, Any]:
        if not self.api_key:
            raise RuntimeError("Missing Kimi API key. Set KIMI_API_KEY, MOONSHOT_API_KEY, or LLM_API_KEY.")
        effective_temperature = 0.6 if "k2" in self.model else temperature
        payload: dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": effective_temperature,
            "response_format": {"type": "json_object"},
        }
        if "k2" in self.model:
            payload["thinking"] = {"type": "disabled"}
        content = self._send(payload)["choices"][0]["message"]["content"]
        return _parse_json_object(content)

    def _send(self, payload: dict[str, Any]) -> dict[str, Any]:
        last_error: BaseException | None = None
        for attempt in range(self.retries + 1):
            try:
                request = urllib.request.Request(
                    f"{self.base_url}/chat/completions",
                    data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    method="POST",
                )
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    return json.loads(response.read().decode("utf-8"))
            except urllib.error.HTTPError as error:
                body = error.read().decode("utf-8", errors="replace")
                raise RuntimeError(f"Kimi API HTTP {error.code}: {body[:500]}") from error
            except (socket.timeout, TimeoutError, urllib.error.URLError, RuntimeError) as error:
                last_error = error
                if attempt >= self.retries:
                    break
                time.sleep(1.0 + attempt)
        raise RuntimeError(f"Kimi API request failed: {last_error}") from last_error


def _env_first(*names: str) -> str | None:
    for name in names:
        value = os.environ.get(name)
        if value:
            return value
    return None


def _parse_json_object(content: str) -> dict[str, Any]:
    text = content.strip()
    fenced = re.search(r"```(?:json)?\s*(.*?)\s*```", text, re.S)
    if fenced:
        text = fenced.group(1).strip()
    if not text.startswith("{"):
        match = re.search(r"\{.*\}", text, re.S)
        if match:
            text = match.group(0)
    parsed = json.loads(text)
    if not isinstance(parsed, dict):
        raise ValueError("Expected JSON object from Kimi")
    return parsed
