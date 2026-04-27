# APEX Backend API Audit

**Files scanned:** 460
**Findings total:** 222

## Summary by rule

| Rule | Severity | Count |
|---|---|---|
| admin-unprotected | 🔴 error | 8 |
| response-shape | 🟡 warn | 10 |
| silent-except | 🟡 warn | 132 |
| traceback-leak | 🔴 error | 72 |

## Findings

### admin-unprotected

- 🔴 **admin-unprotected** — `app/main.py:1936` — GET /admin/users is admin-prefixed but never calls verify_admin(...)
  ```python
  @app.get("/admin/users", tags=["Admin"])
  ```
- 🔴 **admin-unprotected** — `app/main.py:2102` — POST /admin/promote-user is admin-prefixed but never calls verify_admin(...)
  ```python
  @app.post("/admin/promote-user", tags=["Admin"])
  ```
- 🔴 **admin-unprotected** — `app/main.py:2139` — POST /admin/promote/{username} is admin-prefixed but never calls verify_admin(...)
  ```python
  @app.post("/admin/promote/{username}", tags=["Admin"])
  ```
- 🔴 **admin-unprotected** — `app/core/admin_backup_routes.py:59` — POST /admin/backup-now is admin-prefixed but never calls verify_admin(...)
  ```python
  @router.post("/admin/backup-now", tags=["Admin / Backup"])
  ```
- 🔴 **admin-unprotected** — `app/core/admin_backup_routes.py:113` — GET /admin/backup-status is admin-prefixed but never calls verify_admin(...)
  ```python
  @router.get("/admin/backup-status", tags=["Admin / Backup"])
  ```
- 🔴 **admin-unprotected** — `app/phase5/routes/phase5_routes.py:133` — POST /admin/suspend is admin-prefixed but never calls verify_admin(...)
  ```python
  @router.post("/admin/suspend", tags=["Suspension"])
  ```
- 🔴 **admin-unprotected** — `app/phase5/routes/phase5_routes.py:144` — POST /admin/suspend/{sid}/lift is admin-prefixed but never calls verify_admin(...)
  ```python
  @router.post("/admin/suspend/{sid}/lift", tags=["Suspension"])
  ```
- 🔴 **admin-unprotected** — `app/phase5/routes/phase5_routes.py:163` — GET /admin/suspensions is admin-prefixed but never calls verify_admin(...)
  ```python
  @router.get("/admin/suspensions", tags=["Suspension"])
  ```

### response-shape

- 🟡 **response-shape** — `app/main.py:1532` — GET / returns a dict without `success` key
  ```python
  return {
  ```
- 🟡 **response-shape** — `app/main.py:2032` — GET /health returns a dict without `success` key
  ```python
  return {
  ```
- 🟡 **response-shape** — `app/coa_engine/api_routes.py:770` — GET /health returns a dict without `success` key
  ```python
  return {
  ```
- 🟡 **response-shape** — `app/sprint5_analysis/routes/analysis_routes.py:367` — GET /analysis/compare/{run_id_1}/{run_id_2} returns a dict without `success` key
  ```python
  return {
  ```
- 🟡 **response-shape** — `app/sprint2/routes/sprint2_routes.py:494` — POST /coa/debug-classify/{upload_id} returns a dict without `success` key
  ```python
  return {"error": "Upload not found", "upload_id": upload_id}
  ```
- 🟡 **response-shape** — `app/pilot/routes/catalog_routes.py:528` — GET /tenants/{tenant_id}/barcode/{value} returns a dict without `success` key
  ```python
  return {
  ```
- 🟡 **response-shape** — `app/pilot/routes/compliance_routes.py:129` — GET /gosi/rates returns a dict without `success` key
  ```python
  return {
  ```
- 🟡 **response-shape** — `app/pilot/routes/customer_routes.py:285` — GET /customers/{customer_id}/ledger returns a dict without `success` key
  ```python
  return {
  ```
- 🟡 **response-shape** — `app/pilot/routes/gl_routes.py:487` — GET /_debug/entities/{entity_id}/posting-counts returns a dict without `success` key
  ```python
  return {
  ```
- 🟡 **response-shape** — `app/phase1/routes/totp_routes.py:204` — GET /auth/totp/status returns a dict without `success` key
  ```python
  return {
  ```

### silent-except

- 🟡 **silent-except** — `app/main.py:1575` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1583` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1592` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1600` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1606` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1615` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1627` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1662` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1666` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception as _e2:
  ```
- 🟡 **silent-except** — `app/main.py:1676` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception as _e3:
  ```
- 🟡 **silent-except** — `app/main.py:1684` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1692` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1700` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1708` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1843` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1846` — POST /admin/reinit-db catches an exception without logging it
  ```python
  except Exception as _e4:
  ```
- 🟡 **silent-except** — `app/main.py:1865` — GET /admin/stats catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1873` — GET /admin/stats catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1881` — GET /admin/stats catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1889` — GET /admin/stats catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1897` — GET /admin/stats catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1913` — GET /admin/stats catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:1927` — GET /admin/stats catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:2029` — GET /health catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/main.py:2276` — POST /classify catches an exception without logging it
  ```python
  except Exception:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:169` — GET /suggestions/{suggestion_id} catches an exception without logging it
  ```python
  except HTTPException:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:171` — GET /suggestions/{suggestion_id} catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:219` — POST /suggestions/{suggestion_id}/execute catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:229` — POST /suggestions/execute-approved catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:270` — POST /period-close/start catches an exception without logging it
  ```python
  except KeyError as ke:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:272` — POST /period-close/start catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:287` — POST /period-close/tasks/{task_id}/complete catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:299` — GET /period-close/{close_id} catches an exception without logging it
  ```python
  except HTTPException:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:301` — GET /period-close/{close_id} catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:441` — POST /onboarding/complete catches an exception without logging it
  ```python
  except Exception as coa_err:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:466` — POST /onboarding/complete catches an exception without logging it
  ```python
  except Exception as fp_err:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:485` — POST /onboarding/complete catches an exception without logging it
  ```python
  except HTTPException:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:487` — POST /onboarding/complete catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:614` — POST /onboarding/seed-demo catches an exception without logging it
  ```python
  except Exception as _pe:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:629` — POST /onboarding/seed-demo catches an exception without logging it
  ```python
  except HTTPException:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:631` — POST /onboarding/seed-demo catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:664` — POST /universal-journal/query catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:674` — GET /universal-journal/document-flow/{source_type}/{source_id} catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:685` — GET /audit/chain/verify catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:717` — GET /audit/chain/events catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:788` — POST /fixed-assets/schedule catches an exception without logging it
  ```python
  except KeyError as ke:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:790` — POST /fixed-assets/schedule catches an exception without logging it
  ```python
  except HTTPException:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:792` — POST /fixed-assets/schedule catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:839` — POST /audit/benford catches an exception without logging it
  ```python
  except Exception as e:
  ```
- 🟡 **silent-except** — `app/ai/routes.py:859` — POST /audit/je-sample catches an exception without logging it
  ```python
  except Exception as e:
  ```

_(82 more — truncated)_

### traceback-leak

- 🔴 **traceback-leak** — `app/ai/routes.py:172` — GET /suggestions/{suggestion_id} forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:220` — POST /suggestions/{suggestion_id}/execute forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:230` — POST /suggestions/execute-approved forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:271` — POST /period-close/start forwards exception text to the client
  ```python
  raise HTTPException(status_code=400, detail=f"missing field: {ke}")
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:273` — POST /period-close/start forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:288` — POST /period-close/tasks/{task_id}/complete forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:302` — GET /period-close/{close_id} forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:490` — POST /onboarding/complete forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:634` — POST /onboarding/seed-demo forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:665` — POST /universal-journal/query forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:675` — GET /universal-journal/document-flow/{source_type}/{source_id} forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:686` — GET /audit/chain/verify forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:718` — GET /audit/chain/events forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:786` — POST /fixed-assets/schedule forwards exception text to the client
  ```python
  raise HTTPException(status_code=400, detail=f"unknown method: {method}")
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:789` — POST /fixed-assets/schedule forwards exception text to the client
  ```python
  raise HTTPException(status_code=400, detail=f"missing field: {ke}")
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:793` — POST /fixed-assets/schedule forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:840` — POST /audit/benford forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:860` — POST /audit/je-sample forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:897` — POST /consolidation forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:915` — POST /islamic/murabaha forwards exception text to the client
  ```python
  raise HTTPException(status_code=400, detail=f"missing field: {ke}")
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:917` — POST /islamic/murabaha forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:933` — POST /islamic/ijarah forwards exception text to the client
  ```python
  raise HTTPException(status_code=400, detail=f"missing field: {ke}")
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:935` — POST /islamic/ijarah forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:954` — POST /islamic/zakah forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:967` — GET /coa-templates forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/ai/routes.py:982` — GET /coa-templates/{template_id} forwards exception text to the client
  ```python
  raise HTTPException(status_code=500, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/ai_guardrails_routes.py:125` — POST /{row_id}/approve forwards exception text to the client
  ```python
  raise HTTPException(status_code=409, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/bank_feeds_routes.py:98` — POST /connections forwards exception text to the client
  ```python
  raise HTTPException(status_code=400, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/bank_feeds_routes.py:138` — POST /connections/{conn_id}/sync forwards exception text to the client
  ```python
  raise HTTPException(status_code=409, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/bank_feeds_routes.py:140` — POST /connections/{conn_id}/sync forwards exception text to the client
  ```python
  raise HTTPException(status_code=502, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/cashflow_statement_routes.py:85` — POST /cfs/build forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/consolidation_routes.py:110` — POST /consol/build forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/cost_accounting_routes.py:59` — POST /cost/variance/material forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/cost_accounting_routes.py:86` — POST /cost/variance/labour forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/cost_accounting_routes.py:115` — POST /cost/variance/overhead forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/deferred_tax_routes.py:93` — POST /dt/compute forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/extras_routes.py:96` — POST /sbp/compute forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/extras_routes.py:139` — POST /investment-property/compute forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/extras_routes.py:182` — POST /agriculture/compute forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/extras_routes.py:228` — POST /rett/compute forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/extras_routes.py:272` — POST /pillar-two/compute forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/extras_routes.py:318` — POST /vat-group/compute forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/extras_routes.py:374` — POST /job/analyse forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/fin_statements_routes.py:82` — POST /fs/trial-balance forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/fin_statements_routes.py:91` — POST /fs/income-statement forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/fin_statements_routes.py:100` — POST /fs/balance-sheet forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/fin_statements_routes.py:109` — POST /fs/closing-entries forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/fixed_assets_routes.py:100` — POST /fa/build forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/ifrs_extras_routes.py:112` — POST /revenue/recognise forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```
- 🔴 **traceback-leak** — `app/core/ifrs_extras_routes.py:155` — POST /eosb/compute forwards exception text to the client
  ```python
  raise HTTPException(status_code=422, detail=str(e))
  ```

_(22 more — truncated)_
