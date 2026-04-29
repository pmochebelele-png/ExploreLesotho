import fitz  # PyMuPDF
from PIL import Image
import re
from datetime import datetime

try:
    import pytesseract
except ImportError:
    pytesseract = None

class PDFVerifier:
    def verify_document(self, file_path):
        result = self.verify_pdf(file_path)
        return {
            "valid": result["validation"]["valid"],
            "reasons": result["validation"]["reasons"],
            "details": result,
        }

    def extract_text(self, file_path):
        text = ""

        try:
            doc = fitz.open(file_path)

            for page in doc:
                text += page.get_text()

            # 🔥 IF TEXT IS EMPTY → USE OCR
            if len(text.strip()) < 50:
                text += self.extract_text_ocr(doc)

            return text.lower()

        except Exception as e:
            return str(e)

    # ==========================================
    # 🧠 OCR FUNCTION (NEW)
    # ==========================================
    def extract_text_ocr(self, doc):
        if pytesseract is None:
            return ""

        ocr_text = ""

        for page in doc:
            pix = page.get_pixmap()
            img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)

            ocr_text += pytesseract.image_to_string(img)

        return ocr_text

    # ==========================================
    # 🔍 EXTRACT LICENSE INFO
    # ==========================================
    def extract_license_info(self, text):
        license_number = None
        issue_date = None
        expiry_date = None

        lic_match = re.search(r'(license\s*(no|number)[:\s]*\w+)', text)
        if lic_match:
            license_number = lic_match.group()

        dates = re.findall(r'(\d{2}/\d{2}/\d{4})', text)

        if len(dates) >= 2:
            issue_date = dates[0]
            expiry_date = dates[1]

        return {
            "license_number": license_number,
            "issue_date": issue_date,
            "expiry_date": expiry_date
        }

    # ==========================================
    # ✅ VALIDATE LICENSE
    # ==========================================
    def validate_license(self, info):
        reasons = []
        valid = True

        if not info["license_number"]:
            valid = False
            reasons.append("License number missing")

        if not info["expiry_date"]:
            valid = False
            reasons.append("Expiry date missing")
        else:
            expiry = datetime.strptime(info["expiry_date"], "%d/%m/%Y")
            if expiry < datetime.now():
                valid = False
                reasons.append("License expired")

        return {
            "valid": valid,
            "reasons": reasons if reasons else ["Valid license"]
        }

    def verify_pdf(self, file_path):
        text = self.extract_text(file_path)
        info = self.extract_license_info(text)
        validation = self.validate_license(info)

        return {
            "info": info,
            "validation": validation
        }
