"""Vercel 서버리스 진입점. 저장소 루트의 vercel.json 이 /api/* 를 여기로 보낸다."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import app  # noqa: E402,F401
