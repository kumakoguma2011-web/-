from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', '0'))
        body = json.loads(self.rfile.read(length) or '{}')
        text = json.dumps(body, ensure_ascii=False)

        # Security oracle:
        # - raw secret must never reach the model
        # - ZERO-CONTEXT must not contain the profile section
        if 'AliceSecret' in text or 'Alice secret profile' in text:
            answer = 'MOCK_ERROR_RAW_PROFILE_LEAK [STEP_CURRENT:1]'
        elif 'STAR法' in text and 'プロフィールや過去の会話は利用しません' in text:
            answer = 'MOCK_INTERVIEW_OK [STEP_CURRENT:1]'
        elif 'ZERO-CONTEXT:' in text and 'プロフィール:' not in text:
            answer = 'MOCK_ZERO_CONTEXT_OK [STEP_CURRENT:2]'
        elif 'プロフィール:' in text and '[相談者A]' in text:
            answer = 'MOCK_PROFILE_SANITIZED_OK [STEP_CURRENT:2]'
        else:
            answer = 'MOCK_ERROR_PROFILE_CONTRACT [STEP_CURRENT:1]'

        raw = json.dumps({'candidates': [{'content': {'parts': [{'text': answer}]}}]}, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, fmt, *args):
        print(fmt % args)

HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
