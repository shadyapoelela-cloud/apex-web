"""
APEX Ingestion Service — قراءة الملفات وتطبيع البيانات
═══════════════════════════════════════════════════════════

يقرأ ميزان المراجعة من Excel ويحوّل كل صف إلى normalized row
يدعم النموذج الجديد (10 أعمدة) والقديم
"""

from typing import Optional
from openpyxl import load_workbook


class TrialBalanceReader:
    """
    Reads a trial balance Excel file and returns normalized rows.
    Supports both old format (tab + name + D + L) and new format (10 columns).
    """

    def read(self, filepath: str) -> dict:
        """
        Read trial balance and return:
        {
            "rows": [...],
            "meta": { company_name, period, ... },
            "format": "new_10col" | "old",
            "warnings": [...]
        }
        """
        wb = load_workbook(filepath, read_only=True, data_only=True)
        ws = wb.active
        warnings = []

        # Detect format by checking header row
        format_type = self._detect_format(ws)

        # Read company meta from rows 1-6
        meta = self._read_meta(ws)

        # Read data rows
        if format_type == "new_10col":
            rows = self._read_new_format(ws, warnings)
        else:
            rows = self._read_old_format(ws, warnings)

        wb.close()

        return {
            "rows": rows,
            "meta": meta,
            "format": format_type,
            "row_count": len(rows),
            "warnings": warnings,
        }

    def _detect_format(self, ws) -> str:
        """Detect if this is the new 10-column template or old format."""
        # Check row 7 or 8 for column count
        for row in ws.iter_rows(min_row=7, max_row=8, values_only=True):
            if row and len(row) >= 10:
                # Check if column structure matches new format
                # New: A=code, B=main_tab, C=sub_tab, D=name, E-J=numbers
                return "new_10col"
            break
        return "old"

    def _read_meta(self, ws) -> dict:
        """Read company info from header rows 1-6."""
        meta = {
            "company_name": "",
            "period": "",
            "currency": "SAR",
        }
        for row in ws.iter_rows(min_row=1, max_row=6, values_only=True):
            if not row:
                continue
            for cell in row:
                if cell and isinstance(cell, str):
                    text = cell.strip()
                    if any(kw in text for kw in ["شركة", "مؤسسة", "مجموعة", "Company"]):
                        meta["company_name"] = text
                    if any(kw in text for kw in ["2024", "2025", "2026", "السنة", "الفترة"]):
                        meta["period"] = text
        return meta

    def _read_new_format(self, ws, warnings: list) -> list:
        """
        Read new 10-column format:
        A=code, B=main_tab, C=sub_tab, D=account_name,
        E=open_debit, F=open_credit, G=mov_debit, H=mov_credit,
        I=close_debit, J=close_credit
        """
        rows = []
        for row_data in ws.iter_rows(min_row=9, values_only=True):  # Data starts row 9
            if not row_data or len(row_data) < 8:
                continue

            main_tab = row_data[1]
            sub_tab = row_data[2]
            name = row_data[3]

            if not name or not str(name).strip():
                continue

            code = str(row_data[0]).strip() if row_data[0] else ""
            tab_raw = str(main_tab).strip() if main_tab else ""
            sub = str(sub_tab).strip() if sub_tab else ""
            name_clean = str(name).strip()

            open_d = self._to_float(row_data[4])
            open_c = self._to_float(row_data[5])
            mov_d = self._to_float(row_data[6])
            mov_c = self._to_float(row_data[7])

            # Calculate net balance
            net = (open_d - open_c) + (mov_d - mov_c)

            rows.append({
                "code": code,
                "tab": tab_raw,
                "sub_tab": sub,
                "name": name_clean,
                "open_debit": open_d,
                "open_credit": open_c,
                "movement_debit": mov_d,
                "movement_credit": mov_c,
                "close_debit": max(net, 0),
                "close_credit": abs(min(net, 0)),
                "net_balance": net,
            })

        if not rows:
            warnings.append("لم يتم العثور على بيانات في الملف")

        return rows

    def _read_old_format(self, ws, warnings: list) -> list:
        """
        Read old format:
        B=tab, C=name, D=open_debit, L=adj_balance
        """
        rows = []
        for row_data in ws.iter_rows(min_row=7, values_only=True):
            if not row_data:
                continue

            tab = row_data[1] if len(row_data) > 1 else None
            name = row_data[2] if len(row_data) > 2 else None

            if not tab or not name:
                continue

            tab_clean = str(tab).strip()
            name_clean = str(name).strip()
            open_d = self._to_float(row_data[3]) if len(row_data) > 3 else 0.0

            # Old format: column L (index 11) has adjusted balance
            adj = self._to_float(row_data[11]) if len(row_data) > 11 else open_d

            # Determine net balance from adjusted value
            net = adj

            rows.append({
                "code": "",
                "tab": tab_clean,
                "sub_tab": "",
                "name": name_clean,
                "open_debit": open_d,
                "open_credit": 0.0,
                "movement_debit": 0.0,
                "movement_credit": 0.0,
                "close_debit": max(net, 0),
                "close_credit": abs(min(net, 0)),
                "net_balance": net,
            })

        if not rows:
            warnings.append("لم يتم العثور على بيانات في الملف")

        return rows

    @staticmethod
    def _to_float(v) -> float:
        if isinstance(v, (int, float)):
            return float(v)
        if isinstance(v, str):
            try:
                return float(v.replace(",", "").strip())
            except (ValueError, AttributeError):
                pass
        return 0.0
