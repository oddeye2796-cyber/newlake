"""KS X 9101 표준 영문명 → 레이크 물리명(snake_case).

v1.0 최종본 테이블정의서는 물리명을 표준 PascalCase 그대로(큰따옴표 식별자) 권장하지만,
레이크는 처음부터 snake_case 로 만들어 왔다. 온톨로지(ksx:physicalTable)와 카탈로그가 이 변환으로 이어 준다.
"""
import re


def snake(name: str) -> str:
    s = re.sub(r"([A-Z])(ID)(?=$|[A-Z])", r"\1_\2", name)       # BOMID → BOM_ID (약어 뒤 ID)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", s)
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    return s.lower().replace("__", "_")
