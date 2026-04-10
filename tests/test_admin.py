"""
APEX Platform -- Admin endpoint tests
"""


def test_admin_without_secret_returns_403(client):
    response = client.post("/admin/reinit-db")
    assert response.status_code == 403


def test_admin_with_valid_header(client):
    response = client.post(
        "/admin/reinit-db",
        headers={"X-Admin-Secret": "test-admin"},
    )
    assert response.status_code == 200


def test_admin_with_valid_query_param(client):
    response = client.post("/admin/reinit-db?secret=test-admin")
    assert response.status_code == 200


def test_admin_with_wrong_secret_returns_403(client):
    response = client.post(
        "/admin/reinit-db",
        headers={"X-Admin-Secret": "wrong-secret"},
    )
    assert response.status_code == 403
