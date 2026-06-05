from __future__ import annotations

import json
import os
import re
import socket
import time
import urllib.error
import urllib.request
from typing import Any, Callable


Transport = Callable[[str, dict[str, str], dict[str, Any], float], dict[str, Any]]


class KimiBackend:
    """OpenAI-compatible Kimi/Moonshot chat-completions backend."""

    def __init__(
        self,
        prompt: str = "",
        api_key: str | None = None,
        model: str | None = None,
        base_url: str | None = None,
        timeout: float = 90.0,
        retries: int = 2,
        transport: Transport | None = None,
    ):
        self.prompt = prompt
        self.api_key = api_key or _env_first("KIMI_API_KEY", "MOONSHOT_API_KEY", "LLM_API_KEY")
        self.model = model or _env_first("KIMI_MODEL", "MOONSHOT_MODEL", "LLM_MODEL") or "kimi-k2.5"
        self.base_url = (base_url or _env_first("KIMI_BASE_URL", "MOONSHOT_BASE_URL", "LLM_BASE_URL") or "https://api.moonshot.cn/v1").rstrip("/")
        self.timeout = timeout
        self.retries = retries
        self.transport = transport or _post_json

    def decide(self, messages: list[dict[str, str]], state: dict[str, Any]) -> dict[str, Any]:
        if not self.api_key:
            raise RuntimeError("Missing Kimi API key. Set KIMI_API_KEY, MOONSHOT_API_KEY, or LLM_API_KEY.")

        payload = {
            "model": self.model,
            "temperature": 0.6 if "k2" in self.model else 0.1,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": self.prompt},
                {"role": "system", "content": "当前对话状态 JSON：\n" + json.dumps(_jsonable_state(state), ensure_ascii=False)},
                *messages,
            ],
        }
        if "k2" in self.model:
            payload["thinking"] = {"type": "disabled"}
        response = self._send(payload)
        content = response["choices"][0]["message"]["content"]
        return _parse_json_content(content)

    def _send(self, payload: dict[str, Any]) -> dict[str, Any]:
        last_error: BaseException | None = None
        for attempt in range(self.retries + 1):
            try:
                return self.transport(
                    f"{self.base_url}/chat/completions",
                    {
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    payload,
                    self.timeout,
                )
            except (socket.timeout, TimeoutError, urllib.error.URLError) as error:
                last_error = error
                if attempt >= self.retries:
                    break
                time.sleep(0.5 * (attempt + 1))
        raise RuntimeError(f"Kimi API request failed after {self.retries + 1} attempts: {last_error}") from last_error


def _env_first(*names: str) -> str | None:
    for name in names:
        value = os.environ.get(name)
        if value:
            return value
    return None


def _jsonable_state(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): _jsonable_state(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_jsonable_state(item) for item in value]
    if isinstance(value, set):
        return sorted(str(item) for item in value)
    return value


def _parse_json_content(content: str) -> dict[str, Any]:
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
        raise ValueError("Kimi response JSON must be an object")
    return parsed


def _post_json(url: str, headers: dict[str, str], payload: dict[str, Any], timeout: float) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Kimi API HTTP {error.code}: {body[:500]}") from error
