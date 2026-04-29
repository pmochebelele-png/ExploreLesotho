import pdfplumber
import pandas as pd
import os
import json
from pathlib import Path

print("="*70)
print("📄 EXTRACTING DATA FROM YOUR PDF REPORTS")
print("="*70)

dataset_path = r"C:\Users\SUBLIME TECHNOLOGIES\Downloads\Dataset"

# List all PDFs
pdf_files = [f for f in os.listdir(dataset_path) if f.endswith('.pdf')]

print(f"\n📁 Found {len(pdf_files)} PDF files:")
for pdf in pdf_files:
    print(f"   - {pdf}")

# Extract data from each PDF
all_tables = []
all_text = []

for pdf_file in pdf_files:
    print(f"\n📖 Processing: {pdf_file}")
    file_path = os.path.join(dataset_path, pdf_file)
    
    try:
        with pdfplumber.open(file_path) as pdf:
            # Extract all text
            text = ""
            for page in pdf.pages:
                text += page.extract_text()
            all_text.append({
                'filename': pdf_file,
                'content': text
            })
            
            # Extract tables
            for page_num, page in enumerate(pdf.pages):
                tables = page.extract_tables()
                for table in tables:
                    if table and len(table) > 1:
                        df = pd.DataFrame(table[1:], columns=table[0] if table[0] else None)
                        all_tables.append({
                            'filename': pdf_file,
                            'page': page_num + 1,
                            'data': df
                        })
                        print(f"   ✅ Found table on page {page_num + 1}")
    
    except Exception as e:
        print(f"   ❌ Error: {e}")

# Save extracted text
if all_text:
    with open('extracted_text.json', 'w', encoding='utf-8') as f:
        json.dump(all_text, f, indent=2)
    print(f"\n💾 Saved extracted text to extracted_text.json")

# Save extracted tables
if all_tables:
    for i, table_data in enumerate(all_tables):
        filename = f"extracted_table_{i}_{table_data['filename']}_{table_data['page']}.csv"
        table_data['data'].to_csv(filename, index=False)
        print(f"💾 Saved table to {filename}")

print("\n" + "="*70)
print("✅ Extraction complete!")
print("="*70)