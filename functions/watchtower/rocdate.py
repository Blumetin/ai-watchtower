import re

OFFSET = 1911
_ROC_PREFIXED = re.compile(r"(?:中華民國|民國)\s*(\d{2,3})\s*年(度)?")
_ROC_YM = re.compile(r"(?<![\d.])(1\d{2})\s*年(?=\s*\d{1,2}\s*月)")
_ROC_FY = re.compile(r"(?<![\d.])(1\d{2})\s*年度")
_ROC_SLASH = re.compile(r"(?<![\d/.])(1\d{2})([/.])(\d{1,2})\2(\d{1,2})(?![\d/.])")


_ROC_RANGE = re.compile(r"(?<![\d.])(1\d{2})\s*([-－–~～至到])\s*(1\d{2})(?=\s*年(?:度|\s*\d{1,2}\s*月))")


def to_gregorian(text: str) -> str:
    text = _ROC_RANGE.sub(lambda m: f"{int(m.group(1)) + OFFSET}{m.group(2)}{int(m.group(3)) + OFFSET}", text)
    text = _ROC_PREFIXED.sub(lambda m: f"{int(m.group(1)) + OFFSET}年{m.group(2) or ''}", text)
    text = _ROC_YM.sub(lambda m: f"{int(m.group(1)) + OFFSET}年", text)
    text = _ROC_FY.sub(lambda m: f"{int(m.group(1)) + OFFSET}年度", text)
    text = _ROC_SLASH.sub(lambda m: f"{int(m.group(1)) + OFFSET}{m.group(2)}{m.group(3)}{m.group(2)}{m.group(4)}", text)
    return text


_OUT_PATTERNS = [re.compile(r"民國"), re.compile(r"1[01]\d\s*年\s*\d{1,2}\s*月"),
                 re.compile(r"\b1[01]\d[/.]\d{1,2}[/.]\d{1,2}\b")]
_OUT_PATTERNS += [re.compile(r"Republic of China calendar|\bMinguo\b|\bROC\s+(?:calendar|year)\b|\bROC\s*1[01]\d\b", re.I),
                  re.compile(r"民国\s*1[01]\d|民国(?:暦|紀元)"),
                  re.compile(r"(?<!\d)1[01]\d\s*年度"), re.compile(r"(?<!\d)1[01]\d\s*[-－–~～]\s*1[01]\d\s*年"),
                  re.compile(r"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)"
                             r"\s+\d{1,2},\s*1[01]\d\b"),
                  re.compile(r"\b1[01]\d\s+(?:annual|fiscal)\b", re.I),
                  re.compile(r"\b1[01]\d(?:st|nd|rd|th)\s+year\b", re.I)]


def roc_in_output(text: str) -> bool:
    return any(p.search(text) for p in _OUT_PATTERNS)
