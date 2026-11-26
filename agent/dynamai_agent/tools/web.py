# SPDX-License-Identifier: GPL-3.0-or-later
"""Free web search (DuckDuckGo) and URL fetch. Fragile; a paid search API is more reliable."""

from __future__ import annotations

import html
import re
from typing import Any
from urllib.parse import urljoin, urlparse

import httpx

from dynamai_agent.config import FETCH_CAP, FETCH_TIMEOUT

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/json,text/plain;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

_TAG = re.compile(r"<[^>]+>")
_WS = re.compile(r"\s+")
_HREF = re.compile(
    r'<a[^>]+class="[^"]*result__a[^"]*"[^>]+href="([^"]+)"[^>]*>(.*?)</a>',
    re.I | re.S,
)
_LITE = re.compile(r'<a[^>]+rel="nofollow"[^>]+href="(https?://[^"]+)"[^>]*>(.*?)</a>', re.I | re.S)


def _plain(text: str, limit: int = 400) -> str:
    text = html.unescape(_TAG.sub(" ", text))
    text = _WS.sub(" ", text).strip()
    return text[:limit]


def _unwrap_duckduckgo(url: str) -> str:
    # html.duckduckgo.com often wraps outbound links as //duckduckgo.com/l/?uddg=...
    if "duckduckgo.com/l/?" in url or url.startswith("//duckduckgo.com/l/?"):
        from urllib.parse import parse_qs, unquote, urlparse as _urlparse

        if url.startswith("//"):
            url = "https:" + url
        qs = parse_qs(_urlparse(url).query)
        if "uddg" in qs:
            return unquote(qs["uddg"][0])
    return url


async def search(args: dict[str, Any]) -> str:
    query = (args.get("query") or "").strip()
    if not query:
        return "error: empty query"
    parts: list[str] = []
    async with httpx.AsyncClient(headers=_HEADERS, follow_redirects=True, timeout=FETCH_TIMEOUT) as client:
        # Official instant-answer API (free, limited: abstracts, not a full web index).
        try:
            instant = await client.get(
                "https://api.duckduckgo.com/",
                params={"q": query, "format": "json", "no_html": "1", "skip_disambig": "1"},
            )
            if instant.status_code == 200:
                data = instant.json()
                abstract = (data.get("AbstractText") or "").strip()
                heading = (data.get("Heading") or "").strip()
                source = (data.get("AbstractURL") or "").strip()
                if abstract:
                    label = heading or "Abstract"
                    parts.append(f"{label}: {abstract}" + (f" ({source})" if source else ""))
                related = data.get("RelatedTopics") or []
                for item in related[:5]:
                    if not isinstance(item, dict):
                        continue
                    text = item.get("Text") or ""
                    url = item.get("FirstURL") or ""
                    if text:
                        parts.append(f"- {text}" + (f" {url}" if url else ""))
        except Exception as exc:
            parts.append(f"(instant-answer lookup failed: {type(exc).__name__})")

        # HTML results for a fuller list. This is unofficial and often 403s from cloud IPs.
        html_ok = False
        for url, pattern in (
            ("https://html.duckduckgo.com/html/", _HREF),
            ("https://lite.duckduckgo.com/lite/", _LITE),
        ):
            try:
                resp = await client.post(url, data={"q": query})
                if resp.status_code != 200 or not resp.text:
                    continue
                seen: set[str] = set()
                for match in pattern.finditer(resp.text):
                    href = _unwrap_duckduckgo(html.unescape(match.group(1)))
                    title = _plain(match.group(2), 160)
                    if not href.startswith("http") or href in seen:
                        continue
                    if "duckduckgo.com" in urlparse(href).netloc:
                        continue
                    seen.add(href)
                    parts.append(f"- {title or href}: {href}")
                    if len(seen) >= 6:
                        break
                if seen:
                    html_ok = True
                    break
            except Exception:
                continue
        if not html_ok and not any(p.startswith("- ") or p.endswith(")") is False for p in parts):
            parts.append(
                "No full web-result list (DuckDuckGo HTML was empty or blocked). "
                "A paid search API (Brave, Tavily, or Bing) would be more reliable from a cloud VM."
            )
    if not parts:
        return "No results."
    return "\n".join(parts)[:8000]


def _extract_text(content_type: str, body: str) -> str:
    if "html" in content_type:
        # Drop scripts/styles then tags.
        body = re.sub(r"(?is)<script[^>]*>.*?</script>", " ", body)
        body = re.sub(r"(?is)<style[^>]*>.*?</style>", " ", body)
        return _plain(body, 12_000)
    return body[:12_000]


async def fetch(args: dict[str, Any]) -> str:
    url = (args.get("url") or "").strip()
    if not url:
        return "error: empty url"
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return "error: only http(s) URLs are allowed"
    try:
        async with httpx.AsyncClient(headers=_HEADERS, follow_redirects=True, timeout=FETCH_TIMEOUT) as client:
            resp = await client.get(url)
            raw = resp.content[: FETCH_CAP + 1]
            truncated = len(raw) > FETCH_CAP
            text = raw[:FETCH_CAP].decode(resp.encoding or "utf-8", errors="replace")
            ctype = resp.headers.get("content-type", "")
            extracted = _extract_text(ctype, text)
            header = f"HTTP {resp.status_code} {resp.url}"
            if truncated:
                header += " [truncated]"
            return f"{header}\n{extracted}" if extracted else header
    except Exception as exc:
        return f"error: {type(exc).__name__}: {exc}"
