import traceback
import json
from app import _analyze_text

try:
    print("Testing safe text...")
    res = _analyze_text("Hello, this is a safe message without any links.")
    print("Result:", res)
    
    print("\nTesting phishing text...")
    res = _analyze_text("Click here: https://secure-paypa1.com/login")
    print("Result:", res)
except Exception as e:
    print("\nCRAHSED!")
    traceback.print_exc()
