from __future__ import annotations

import unittest

from app.services.sms_verification_service import (
    SmsVerificationConfig,
    build_check_parameters,
    build_send_parameters,
    send_response_succeeded,
    verify_response_passed,
)


class SmsVerificationServiceTests(unittest.TestCase):
    def setUp(self):
        self.config = SmsVerificationConfig(
            access_key_id="test-access-key-id",
            access_key_secret="test-access-key-secret",
            region_id="cn-hangzhou",
            scheme_name="默认方案",
            sign_name="测试签名",
            template_code="100001",
            enabled=True,
        )

    def test_send_parameters_request_dynamic_six_digit_code(self):
        params = build_send_parameters("13800000000", self.config)

        self.assertEqual(params["phone_number"], "13800000000")
        self.assertEqual(params["country_code"], "86")
        self.assertEqual(params["scheme_name"], "默认方案")
        self.assertEqual(params["sign_name"], "测试签名")
        self.assertEqual(params["template_code"], "100001")
        self.assertEqual(params["template_param"], '{"code":"##code##","min":"5"}')
        self.assertEqual(params["code_length"], 6)
        self.assertEqual(params["valid_time"], 300)
        self.assertEqual(params["interval"], 60)
        self.assertEqual(params["duplicate_policy"], 1)
        self.assertEqual(params["code_type"], 1)
        self.assertFalse(params["return_verify_code"])

    def test_check_parameters_use_same_scheme_and_phone(self):
        params = build_check_parameters("13800000000", "123456", self.config)

        self.assertEqual(params, {
            "scheme_name": "默认方案",
            "country_code": "86",
            "phone_number": "13800000000",
            "verify_code": "123456",
            "case_auth_policy": 2,
        })

    def test_send_response_requires_ok_and_success(self):
        success = {
            "access_denied_detail": None,
            "message": "成功",
            "request_id": "request-1",
            "model": {
                "verify_code": None,
                "request_id": "model-request-1",
                "out_id": None,
                "biz_id": "biz-1",
            },
            "code": "OK",
            "success": True,
        }
        failed = {**success, "success": False}

        self.assertTrue(send_response_succeeded(success))
        self.assertFalse(send_response_succeeded(failed))

    def test_verify_response_requires_model_pass(self):
        response = {
            "access_denied_detail": None,
            "message": "成功",
            "request_id": "request-2",
            "model": {
                "out_id": None,
                "verify_result": "PASS",
            },
            "code": "OK",
            "success": True,
        }

        self.assertTrue(verify_response_passed(response))
        self.assertFalse(verify_response_passed({
            **response,
            "model": {"out_id": None, "verify_result": "UNKNOWN"},
        }))
        self.assertFalse(verify_response_passed({**response, "code": "ERROR"}))


if __name__ == "__main__":
    unittest.main()
