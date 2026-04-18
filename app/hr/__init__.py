"""APEX HR module — Saudi/UAE payroll-aware employee management.

Models:
  • Employee         — personal + employment + bank + GOSI info
  • LeaveRequest     — annual / sick / unpaid / Hajj leave with approval
  • PayrollRun       — monthly payroll period for a tenant
  • Payslip          — per-employee payroll result (net, deductions, WPS ref)

Services (to be added incrementally):
  • gosi_calculator  — 10% / 12% (GCC) on capped salary base
  • wps_generator    — Ministry of Labor CSV/SIF format
  • eosb_calculator  — End of Service Benefit per Saudi/UAE labor law
  • leave_balance    — compute accrued/used per leave type

This scaffold establishes the DB schema + basic CRUD routes. Business
calculators are wired in separately.
"""
