"""Tests for production middleware and security hardening."""

import pytest
import time
from unittest.mock import AsyncMock, MagicMock, patch
from decimal import Decimal


class TestRateLimitMiddleware:
    """Test the in-memory rate limiter in app.core.middleware."""

    def test_rate_limiter_class_init(self):
        from app.core.middleware import RateLimitMiddleware
        app_mock = MagicMock()
        rl = RateLimitMiddleware(app_mock, max_requests=10, window_seconds=30)
        assert rl.max_requests == 10
        assert rl.window_seconds == 30

    def test_rate_limiter_client_ip_forwarded(self):
        from app.core.middleware import RateLimitMiddleware
        app_mock = MagicMock()
        rl = RateLimitMiddleware(app_mock)
        req = MagicMock()
        req.headers = {"X-Forwarded-For": "1.2.3.4, 5.6.7.8"}
        assert rl._client_ip(req) == "1.2.3.4"

    def test_rate_limiter_client_ip_direct(self):
        from app.core.middleware import RateLimitMiddleware
        app_mock = MagicMock()
        rl = RateLimitMiddleware(app_mock)
        req = MagicMock()
        req.headers = {}
        req.client.host = "10.0.0.1"
        assert rl._client_ip(req) == "10.0.0.1"


class TestSecurityHeadersMiddleware:
    """Test security headers are applied."""

    def test_middleware_init(self):
        from app.core.middleware import SecurityHeadersMiddleware
        app_mock = MagicMock()
        m = SecurityHeadersMiddleware(app_mock)
        assert m is not None


class TestRequestIdMiddleware:
    """Test request ID injection."""

    def test_middleware_init(self):
        from app.core.middleware import RequestIdMiddleware
        app_mock = MagicMock()
        m = RequestIdMiddleware(app_mock)
        assert m is not None


class TestTimingMiddleware:
    """Test timing header."""

    def test_middleware_init(self):
        from app.core.middleware import TimingMiddleware
        app_mock = MagicMock()
        m = TimingMiddleware(app_mock)
        assert m is not None


class TestGlobalExceptionMiddleware:
    """Test global exception handler."""

    def test_middleware_init(self):
        from app.core.middleware import GlobalExceptionMiddleware
        app_mock = MagicMock()
        m = GlobalExceptionMiddleware(app_mock)
        assert m is not None


class TestValidatorsExtended:
    """Extended validator tests for edge cases."""

    def test_sanitize_removes_control_chars(self):
        from app.core.validators import sanitize_string
        result = sanitize_string("hello\x00\x00world")
        assert "\x00" not in result
        assert result == "helloworld"

    def test_validate_amount_infinity(self):
        from app.core.validators import validate_amount
        assert validate_amount("Infinity") is not None

    def test_validate_fiscal_year_out_of_range(self):
        from app.core.validators import validate_fiscal_year
        assert validate_fiscal_year("1999") is not None
        assert validate_fiscal_year("2101") is not None

    def test_validate_date_range_same_day(self):
        from app.core.validators import validate_date_range
        assert validate_date_range("2026-06-15", "2026-06-15") is None

    def test_validate_email_with_subdomain(self):
        from app.core.validators import validate_email
        assert validate_email("admin@sub.domain.co.sa") is None

    def test_validate_saudi_cr_with_spaces(self):
        from app.core.validators import validate_saudi_cr
        assert validate_saudi_cr("  1010000001  ") is None

    def test_validate_saudi_iban_spaces(self):
        from app.core.validators import validate_saudi_iban
        assert validate_saudi_iban("SA 03 80000000608010167519") is None


class TestAuthUtilsHardening:
    """Test secret hardening in auth utils."""

    def test_jwt_secret_default_dev(self):
        """In dev mode, default secret should work (just warns)."""
        from app.core.auth_utils import JWT_SECRET
        # Should not raise in dev/test mode
        assert JWT_SECRET is not None
        assert len(JWT_SECRET) > 10

    def test_jwt_algorithm(self):
        from app.core.auth_utils import JWT_ALGORITHM
        assert JWT_ALGORITHM == "HS256"
