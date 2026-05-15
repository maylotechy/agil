from flask import Flask, request, jsonify
import pickle
import numpy as np
import re
import base64
from urllib.parse import urlparse, quote_plus
import vertexai
from vertexai.generative_models import GenerativeModel
import json
import os
import requests
import threading
from datetime import datetime, timedelta

app = Flask(__name__)

# Auto-detect Render Secret File for Vertex AI
if os.path.exists('/etc/secrets/vertex_key.json'):
    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = '/etc/secrets/vertex_key.json'

@app.route('/api/ping', methods=['GET'])
def ping():
    return jsonify({"status": "online", "response": "pong"}), 200

# ────────────────────────────────────────────────────────────────────
#  LAYER 1: PhishTank Blacklist Database
# ────────────────────────────────────────────────────────────────────
PHISHTANK_DB_FILE = "phishtank_db.json"
PHISHTANK_FEED_URL = "http://data.phishtank.com/data/online-valid.json"
PHISHTANK_API_URL = "https://checkurl.phishtank.com/checkurl/"
PHISHTANK_USER_AGENT = "Agil-Security-USM-Thesis-Project"

# In-memory set of known phishing URLs for O(1) lookups
_phishtank_urls: set = set()
_phishtank_last_refresh: str = "Never"
_phishtank_lock = threading.Lock()


def _load_phishtank_db():
    """Load the local PhishTank JSON file into memory."""
    global _phishtank_urls, _phishtank_last_refresh
    try:
        if os.path.exists(PHISHTANK_DB_FILE):
            with open(PHISHTANK_DB_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            urls = set()
            for entry in data:
                url = entry.get("url", "").strip().rstrip("/")
                if url:
                    urls.add(url)
                    urls.add(url.lower())
            with _phishtank_lock:
                _phishtank_urls = urls
                _phishtank_last_refresh = datetime.now().strftime("%Y-%m-%d %H:%M")
            print(f"[PhishTank] Loaded {len(urls)} URLs from local DB.")
        else:
            print("[PhishTank] No local DB found. Will attempt download.")
            _download_phishtank_db()
    except Exception as e:
        print(f"[PhishTank] Error loading local DB: {e}")


def _download_phishtank_db():
    """Download the public PhishTank data feed and save locally."""
    global _phishtank_urls, _phishtank_last_refresh
    try:
        print("[PhishTank] Downloading public data feed...")
        resp = requests.get(
            PHISHTANK_FEED_URL,
            headers={"User-Agent": PHISHTANK_USER_AGENT},
            timeout=120,
        )
        if resp.status_code == 200:
            data = resp.json()
            with open(PHISHTANK_DB_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f)
            urls = set()
            for entry in data:
                url = entry.get("url", "").strip().rstrip("/")
                if url:
                    urls.add(url)
                    urls.add(url.lower())
            with _phishtank_lock:
                _phishtank_urls = urls
                _phishtank_last_refresh = datetime.now().strftime("%Y-%m-%d %H:%M")
            print(f"[PhishTank] Downloaded & loaded {len(urls)} URLs.")
        else:
            print(f"[PhishTank] Download failed: HTTP {resp.status_code}")
    except Exception as e:
        print(f"[PhishTank] Download error: {e}")


def _check_phishtank_local(url: str) -> bool:
    """O(1) lookup against the in-memory PhishTank set."""
    normalized = url.strip().rstrip("/")
    with _phishtank_lock:
        return normalized in _phishtank_urls or normalized.lower() in _phishtank_urls


def _check_phishtank_api(url: str) -> bool:
    """Live API fallback — anonymous, no key needed."""
    try:
        resp = requests.post(
            PHISHTANK_API_URL,
            data={
                "url": quote_plus(url),
                "format": "json",
            },
            headers={"User-Agent": PHISHTANK_USER_AGENT},
            timeout=5,
        )
        if resp.status_code == 200:
            result = resp.json()
            in_db = result.get("results", {}).get("in_database", False)
            verified = result.get("results", {}).get("verified", False)
            return bool(in_db and verified)
    except Exception as e:
        print(f"[PhishTank API] Fallback check failed: {e}")
    return False


# Load PhishTank DB on startup (in background thread to not block)
threading.Thread(target=_load_phishtank_db, daemon=True).start()

# 1. Load your model (Keep name as requested)
model = pickle.load(open("optimized_phishing_model.pkl", "rb"))

# 2. Setup Gemini
vertexai.init(project="ceit-thesis-ragas", location="asia-southeast1")
gemini_model = GenerativeModel("gemini-2.5-flash")


# 3. Global Knowledge / Feedback Rules (Add new rules here to 'train' the AI instantly)
GLOBAL_RULES = """
- Official emails from 'google.com', 'microsoft.com', and 'apple.com' are usually SAFE unless they use suspicious shortlinks (like bit.ly).
- Urgency combined with a link is a HIGH PHISHING indicator.
- Never ask users for passwords or OTPs; any message doing so is PHISHING.
- Messages claiming to be from BDO or GCash that use non-official domains (not bdo.com.ph or gcash.com) are 100% PHISHING.
- Check if the display name matches the actual email address domain.
"""


def extract_features(url):
    """Must match the 10-feature logic from your Colab training"""
    if url is None:
        return [0] * 10  # Prevent processing NoneType

    features = []
    # IP Address check
    ip_pattern = r"(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"
    features.append(-1 if re.search(ip_pattern, url) else 1)

    # URL Length
    features.append(1 if len(url) < 54 else (0 if len(url) <= 75 else -1))

    # Shortening Service
    short_p = r"bit\.ly|goo\.gl|shorte\.st|go2l\.ink|x\.co|ow\.ly|t\.co|tinyurl"
    features.append(-1 if re.search(short_p, url) else 1)

    # At Symbol
    features.append(-1 if "@" in url else 1)

    # Double Slash Redirect
    features.append(-1 if url.rfind("//") > 7 else 1)

    # Prefix-Suffix in Domain
    domain = urlparse(url).netloc
    features.append(-1 if "-" in domain else 1)

    # Subdomain count
    dots = url.count(".")
    features.append(1 if dots <= 2 else (0 if dots == 3 else -1))

    # HTTPS Check
    features.append(1 if url.startswith("https") else -1)

    # Placeholder for feature 9 (matching your 10-feature training)
    features.append(0)

    # HTTPS in Domain
    features.append(-1 if "https" in domain else 1)

    return features


def _clean_ai_text(text):
    """Strip markdown formatting (* ** _ bullet symbols) from AI responses."""
    # 1. Convert any list markers (* or -) at the start of a line to a clean bullet
    text = re.sub(r'(?m)^[\*\-\u2022]\s+', '\u2022 ', text)
    # 2. Remove markdown bold symbols
    text = text.replace('**', '')
    # 3. Collapse extra blank lines
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def _analyze_text(raw_input):
    """Shared 3-layer analysis: PhishTank → ML → Gemini."""
    url_pattern = r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+[/\w\.-]*'
    found_urls = re.findall(url_pattern, raw_input)
    target_to_test = found_urls[0] if found_urls else raw_input

    # ─── LAYER 1: PhishTank Blacklist (fast) ────────────────────────
    pt_local = _check_phishtank_local(target_to_test)
    pt_api = False
    if not pt_local:
        pt_api = _check_phishtank_api(target_to_test)

    phishtank_match = pt_local or pt_api

    if phishtank_match:
        source = "Local DB" if pt_local else "Live API"
        print(f"[PhishTank] MATCH via {source}: {target_to_test}")
        return {
            "is_phishing": True,
            "confidence": 1.0,
            "result_label": "BLACKLISTED PHISHING",
            "explanation": (
                f"This URL has been confirmed as a phishing site by the "
                f"PhishTank global database ({source} match).\n\n"
                f"1. The Verdict: This is a verified phishing link reported "
                f"by the global cybersecurity community.\n"
                f"2. The Evidence:\n"
                f"\u2022 URL is listed in PhishTank's verified phishing database\n"
                f"\u2022 Multiple community members have confirmed this is malicious\n"
                f"\u2022 No further AI analysis is needed — this is a known threat\n"
                f"3. The Recommendation: Do NOT click this link. Delete the "
                f"message immediately and block the sender."
            ),
            "api_status": f"PhishTank Blacklist ({source})",
            "phishtank_match": True,
            "target_url": target_to_test,
        }

    # ─── LAYER 2: Local ML Classifier ───────────────────────────────
    features_list = extract_features(target_to_test)
    features_arr = np.array(features_list).reshape(1, -1)
    ml_is_phishing = bool(model.predict(features_arr)[0] == -1)

    # ─── LAYER 3: Gemini LLM Reasoning ──────────────────────────────
    try:
        prompt = (
            f"Analyze this message or URL based on these rules:\n"
            f"{GLOBAL_RULES}\n\n"
            f"Input: {raw_input}\n\n"
            f"Provide your analysis using Progressive Disclosure format. Keep it extremely short, concise, and do NOT use any emojis:\n"
            f"1. The Verdict: (One short sentence)\n"
            f"2. The Evidence: (1-2 short bullet points)\n"
            f"3. The Recommendation: (One short sentence)\n\n"
            f"At the very end, on its own line, write exactly one of:\n"
            f"VERDICT: PHISHING\nVERDICT: SAFE"
        )
        response = gemini_model.generate_content(prompt)
        raw_text = str(response.text).strip()

        verdict_match = re.search(
            r'VERDICT:\s*(PHISHING|SAFE)', raw_text, re.IGNORECASE)
        if verdict_match:
            gemini_is_phishing = verdict_match.group(1).upper() == 'PHISHING'
            gemini_explanation = re.sub(
                r'\n?VERDICT:\s*(PHISHING|SAFE)\.?\s*$', '',
                raw_text, flags=re.IGNORECASE).strip()
            
            if ml_is_phishing and gemini_is_phishing:
                result_label = "PHISHING DETECTED"
                is_phishing = True
            elif ml_is_phishing and not gemini_is_phishing:
                result_label = "POTENTIAL THREAT"
                is_phishing = True
            elif not ml_is_phishing and gemini_is_phishing:
                result_label = "SUSPICIOUS (AI WARNING)"
                is_phishing = True
            else:
                result_label = "SECURE"
                is_phishing = False
            
            explanation = gemini_explanation
        else:
            is_phishing = ml_is_phishing
            result_label = "PHISHING DETECTED" if is_phishing else "SECURE"
            explanation = raw_text

        explanation = _clean_ai_text(explanation)
        api_status = "ML + Gemini Consensus"
    except Exception as e:
        print(f"Gemini API Error: {e}")
        is_phishing = ml_is_phishing
        result_label = "PHISHING DETECTED" if is_phishing else "SECURE"
        explanation = ("High-risk patterns detected by local ML classifier."
                       if is_phishing else "No threats found.")
        api_status = "Local ML Only"

    confidence = float(0.95 if is_phishing else 0.05)

    return {
        "is_phishing": is_phishing,
        "confidence": confidence,
        "result_label": result_label,
        "explanation": explanation,
        "api_status": api_status,
        "phishtank_match": False,
        "ml_match": ml_is_phishing,
        "target_url": target_to_test,
    }


# ────────────────────────────────────────────────────────────────────
#  Health check — Flutter app uses this to verify backend is alive
# ────────────────────────────────────────────────────────────────────
@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"})


# ────────────────────────────────────────────────────────────────────
#  Original /scan endpoint (kept for backward compatibility)
# ────────────────────────────────────────────────────────────────────
@app.route('/scan', methods=['POST'])
def scan_url():
    data = request.json
    # Handles both 'url' from background and 'message' from manual paste
    raw_input = data.get("url") or data.get("message")

    if not raw_input:
        return jsonify({"status": "Error", "explanation": "No text received"}), 400

    result = _analyze_text(raw_input)

    return jsonify({
        "status": result["result_label"],
        "explanation": result["explanation"],
        "risk_score": result["confidence"],
        "provider": result["api_status"],
        "phishtank_match": result.get("phishtank_match", False),
        "ml_match": result.get("ml_match", False),
    })


# ────────────────────────────────────────────────────────────────────
#  NEW: /predict — matches the Flutter ApiClient contract
#  Expects:  {"text": "..."}
#  Returns:  {"is_scam": bool, "confidence": float, "explanation": str}
# ────────────────────────────────────────────────────────────────────
@app.route('/predict', methods=['POST'])
def predict():
    data = request.json
    raw_input = data.get("text")

    if not raw_input:
        return jsonify({"error": "Missing 'text' field"}), 400

    result = _analyze_text(raw_input)

    return jsonify({
        "is_scam": result["is_phishing"],
        "confidence": result["confidence"],
        "explanation": result["explanation"],
        "provider": result["api_status"],
        "phishtank_match": result.get("phishtank_match", False),
        "ml_match": result.get("ml_match", False),
    })


# ────────────────────────────────────────────────────────────────────
#  NEW: /screenshot — generates a safe snapshot of a suspicious URL
#  Expects:  {"url": "https://..."}
#  Returns:  {"image_64": "<base64 encoded PNG>"}
#
#  Uses Selenium to render the page in a sandboxed headless browser.
#  Falls back to a placeholder image if Selenium is not available.
# ────────────────────────────────────────────────────────────────────
@app.route('/screenshot', methods=['POST'])
def screenshot():
    data = request.json
    target_url = data.get("url")

    if not target_url:
        return jsonify({"error": "Missing 'url' field"}), 400

    try:
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
        from selenium.webdriver.chrome.service import Service

        chrome_options = Options()
        chrome_options.add_argument("--headless=new")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--window-size=1280,900")
        # Block all JavaScript for safety
        chrome_options.add_experimental_option("prefs", {
            "profile.managed_default_content_settings.javascript": 2
        })

        driver = webdriver.Chrome(options=chrome_options)
        driver.set_page_load_timeout(15)

        try:
            driver.get(target_url)
            # Take screenshot as PNG bytes
            screenshot_png = driver.get_screenshot_as_png()
            image_b64 = base64.b64encode(screenshot_png).decode("utf-8")
        finally:
            driver.quit()

        return jsonify({"image_64": image_b64})

    except ImportError:
        print("Selenium not installed — returning placeholder screenshot")
        return _placeholder_screenshot()
    except Exception as e:
        print(f"Screenshot error: {e}")
        return _placeholder_screenshot()


def _placeholder_screenshot():
    """Generates a minimal placeholder PNG image as base64 when Selenium is unavailable."""
    try:
        from PIL import Image, ImageDraw, ImageFont
        import io

        img = Image.new("RGB", (1280, 900), color=(20, 20, 30))
        draw = ImageDraw.Draw(img)

        # Try to use a nicer font, fall back to default
        try:
            font_large = ImageFont.truetype("arial.ttf", 36)
            font_small = ImageFont.truetype("arial.ttf", 20)
        except:
            font_large = ImageFont.load_default()
            font_small = font_large

        draw.text((440, 380), "⚠ SANDBOX PREVIEW", fill=(255, 80, 80), font=font_large)
        draw.text((400, 440), "Selenium not configured — install it for live screenshots", fill=(180, 180, 180), font=font_small)

        buf = io.BytesIO()
        img.save(buf, format="PNG")
        image_b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

        return jsonify({"image_64": image_b64})
    except ImportError:
        # Pillow not installed either — return a minimal 1x1 red pixel PNG
        minimal_png_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
        return jsonify({"image_64": minimal_png_b64})



# ────────────────────────────────────────────────────────────────────
#  /chat — Gemini-powered security chatbot
#  Expects:  {"message": "...", "history": [{"role":"user","content":"..."}]}
#  Returns:  {"reply": "..."}
# ────────────────────────────────────────────────────────────────────
@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    message = data.get("message", "")
    history = data.get("history", [])

    if not message:
        return jsonify({"error": "Missing 'message' field"}), 400

    system_prompt = (
        "You are PhishGuard AI, a cybersecurity expert. Follow these safety rules:\n"
        f"{GLOBAL_RULES}\n"
        "Help users identify scams and stay safe. Keep responses extremely short, concise, and do NOT use any emojis. "
        "When listing items, put each item on a new line and start it with a bullet point (\u2022). "
        "Do not use markdown bold formatting. "
    )

    # Build conversation string (last 6 turns for context)
    conversation = system_prompt + "\n\n"
    for h in history[-6:]:
        role = "User" if h.get("role") == "user" else "PhishGuard AI"
        conversation += f"{role}: {h.get('content', '')}\n"
    conversation += f"User: {message}\nPhishGuard AI:"

    try:
        response = gemini_model.generate_content(conversation)
        return jsonify({"reply": _clean_ai_text(response.text)})
    except Exception as e:
        print(f"Chat Gemini Error: {e}")
        return jsonify({"reply": "I'm having trouble connecting right now. Please try again."}), 200


# ────────────────────────────────────────────────────────────────────
#  /news — Multi-feed: global + PH e-wallet (EN) + Filipino (FIL)
#  Returns:  {"articles": [{title,summary,url,published,source,lang}]}
# ────────────────────────────────────────────────────────────────────
@app.route('/news', methods=['GET'])
def news():
    try:
        import feedparser
        import html as html_lib

        FEEDS = [
            {"url": "https://news.google.com/rss/search?q=phishing+scam+cybersecurity&hl=en-US&gl=US&ceid=US:en", "lang": "EN"},
            {"url": "https://news.google.com/rss/search?q=GCash+Maya+BDO+scam+phishing+Philippines&hl=en-PH&gl=PH&ceid=PH:en", "lang": "EN"},
            {"url": "https://news.google.com/rss/search?q=GCash+scam+Maya+phishing+Pilipinas&hl=fil&gl=PH&ceid=PH:fil", "lang": "FIL"},
        ]

        seen = set()
        articles = []

        for feed_cfg in FEEDS:
            feed = feedparser.parse(feed_cfg["url"])
            for entry in feed.entries[:20]:
                url = entry.get("link", "")
                if not url or url in seen:
                    continue
                seen.add(url)

                source = entry.get("source", {})
                source_name = source.get("title", "News") if isinstance(source, dict) else "News"

                title = entry.get("title", "No title")
                suffix = f" - {source_name}"
                if title.endswith(suffix):
                    title = title[: -len(suffix)].strip()

                raw_summary = entry.get("summary", "")
                clean_summary = re.sub(r'<[^>]+>', '', raw_summary)
                clean_summary = html_lib.unescape(clean_summary).strip()[:250]

                articles.append({
                    "title":     title,
                    "summary":   clean_summary,
                    "url":       url,
                    "published": entry.get("published", ""),
                    "source":    source_name,
                    "lang":      feed_cfg["lang"],
                })

        return jsonify({"articles": articles})
    except Exception as e:
        print(f"News error: {e}")
        return jsonify({"articles": [], "error": str(e)}), 500


@app.route('/feedback', methods=['POST'])
def feedback():
    data = request.json
    try:
        with open("feedback_data.jsonl", "a") as f:
            f.write(json.dumps(data) + "\n")
        return jsonify({"status": "received"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/get-feedback-data', methods=['GET'])
def get_feedback():
    """Route to view collected feedback for thesis evaluation."""
    # Password check
    pwd = request.args.get('pass')
    if pwd != 'tomi':
        return jsonify({"error": "Unauthorized access."}), 401

    if not os.path.exists("feedback_data.jsonl"):
        return jsonify({"message": "No feedback collected yet."}), 404
    
    try:
        with open("feedback_data.jsonl", "r") as f:
            lines = f.readlines()
        data = [json.loads(line) for line in lines]
        return jsonify({
            "total_count": len(data),
            "feedback": data
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ────────────────────────────────────────────────────────────────────
#  /refresh-phishtank — manually trigger PhishTank DB refresh
#  Returns:  {"status": "...", "url_count": int, "last_refresh": str}
# ────────────────────────────────────────────────────────────────────
@app.route('/refresh-phishtank', methods=['GET'])
def refresh_phishtank():
    try:
        _download_phishtank_db()
        with _phishtank_lock:
            count = len(_phishtank_urls)
            ts = _phishtank_last_refresh
        return jsonify({
            "status": "refreshed",
            "url_count": count,
            "last_refresh": ts,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ────────────────────────────────────────────────────────────────────
#  /phishtank-status — check PhishTank DB status
# ────────────────────────────────────────────────────────────────────
@app.route('/phishtank-status', methods=['GET'])
def phishtank_status():
    with _phishtank_lock:
        return jsonify({
            "url_count": len(_phishtank_urls),
            "last_refresh": _phishtank_last_refresh,
            "db_file_exists": os.path.exists(PHISHTANK_DB_FILE),
        })


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

