import os
import pandas as pd
from docx import Document
import pdfplumber

# ====================== CONFIG ======================
DATA_DIR = "data"
RAW_DIR = os.path.join(DATA_DIR, "raw")

MTICC_DOCX = os.path.join(RAW_DIR, "MTICC DATABASE.docx")
NALA_PDF   = os.path.join(RAW_DIR, "Nala Vendor Data (1).pdf")

OUTPUT_MTICC    = os.path.join(DATA_DIR, "culture_mticc.csv")
OUTPUT_NALA     = os.path.join(DATA_DIR, "culture_nala.csv")
OUTPUT_COMBINED = os.path.join(DATA_DIR, "culture_combined.csv")
# ===================================================

def extract_mticc_docx():
    print("📄 Extracting MTICC DOCX...")
    doc = Document(MTICC_DOCX)
    table = doc.tables[0]
    
    data = []
    headers = None
    
    for row_idx, row in enumerate(table.rows):
        cells = [cell.text.strip() for cell in row.cells]
        
        if row_idx == 0:                          # First row = headers
            headers = cells
            print(f"   → Found {len(headers)} columns: {headers}")
            continue
            
        if not any(cells):                        # Skip empty rows
            continue
            
        data.append(cells)
    
    df = pd.DataFrame(data, columns=headers)
    
    # Clean and standardise
    df = df.dropna(how='all')
    df.columns = ["name_and_surname", "product_range", "items_picture", 
                  "contacts", "location", "extra"] if len(df.columns) == 6 else df.columns
    
    df["category"] = "culture"
    df["data_source"] = "MTICC"
    
    df.to_csv(OUTPUT_MTICC, index=False)
    print(f"✅ MTICC extracted → {OUTPUT_MTICC} ({len(df)} rows)")
    return df


def extract_nala_pdf():
    print("📄 Extracting Nala PDF...")
    with pdfplumber.open(NALA_PDF) as pdf:
        page = pdf.pages[0]
        table = page.extract_table()
        
        if table is None:
            raise ValueError("No table found in Nala PDF")
        
        df = pd.DataFrame(table[1:], columns=table[0])   # skip header
    
    df = df.dropna(how='all')
    df.columns = ["full_name", "business_name"]
    df["category"] = "culture"
    df["data_source"] = "Nala"
    df["location"] = "Maseru"
    
    df.to_csv(OUTPUT_NALA, index=False)
    print(f"✅ Nala extracted → {OUTPUT_NALA} ({len(df)} rows)")
    return df


def combine_culture_data():
    print("🔄 Combining culture datasets...")
    mticc = pd.read_csv(OUTPUT_MTICC)
    nala = pd.read_csv(OUTPUT_NALA)
    
    combined = pd.concat([mticc, nala], ignore_index=True)
    combined.to_csv(OUTPUT_COMBINED, index=False)
    print(f"✅ Combined file created → {OUTPUT_COMBINED} ({len(combined)} total rows)")
    return combined


if __name__ == "__main__":
    print("🚀 Starting culture data extraction...\n")
    
    extract_mticc_docx()
    extract_nala_pdf()
    combine_culture_data()
    
    print("\n🎉 All culture data extracted successfully!")
    print("You should now see three new CSV files in the 'data' folder.")