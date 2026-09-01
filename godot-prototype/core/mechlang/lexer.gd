class_name MechLangLexer
## MechLang 词法分析器：文本 → Token 流。
## Token: {type, value, line}  type ∈ WORD/INT/FLOAT/STRING/SYMBOL/NEWLINE/EOF

const T := {
	"WORD": "WORD", "INT": "INT", "FLOAT": "FLOAT", "STRING": "STRING",
	"SYMBOL": "SYMBOL", "NEWLINE": "NEWLINE", "EOF": "EOF",
}

var _src: String = ""
var _pos: int = 0
var _line: int = 1
var _tokens: Array = []

const SYMBOLS2 := ["<=", ">=", "==", "!=", "&&", "||", "+=", "-=", "*=", "/="]
const SYMBOLS1 := "{}:,()[]=+-*/%<>!&|"


func tokenize(src: String) -> Array:
	_src = src
	_pos = 0
	_line = 1
	_tokens = []
	while _pos < _src.length():
		var c := _src[_pos]
		if c == "\n":
			_tokens.append(_make("NEWLINE"))
			_line += 1
			_pos += 1
			continue
		if c == " " or c == "\t" or c == "\r":
			_pos += 1
			continue
		if c == "#":
			# 行注释
			while _pos < _src.length() and _src[_pos] != "\n":
				_pos += 1
			continue
		if _is_word_start(c):
			_tokens.append(_read_word())
			continue
		if c.is_valid_int() or (c == "." and _pos + 1 < _src.length() and _src[_pos + 1].is_valid_int()):
			_tokens.append(_read_number())
			continue
		if c == "\"" or c == "'":
			_tokens.append(_read_string(c))
			continue
		# 双字符符号
		var two := ""
		if _pos + 1 < _src.length():
			two = _src.substr(_pos, 2)
		if two in SYMBOLS2:
			_tokens.append(_make("SYMBOL", two))
			_pos += 2
			continue
		if c in SYMBOLS1:
			_tokens.append(_make("SYMBOL", c))
			_pos += 1
			continue
		# 未知字符 -> 错误 token
		_tokens.append(_make("SYMBOL", c))
		_pos += 1
	_tokens.append(_make("EOF"))
	return _tokens


func _make(type: String, value: Variant = null) -> Dictionary:
	return {"type": type, "value": value, "line": _line}


func _read_word() -> Dictionary:
	var start := _pos
	while _pos < _src.length():
		var ch := _src[_pos]
		if _is_word_char(ch):
			_pos += 1
		else:
			break
	var word := _src.substr(start, _pos - start)
	return _make("WORD", word)


## 标识符起始字符: 字母 / 下划线 / 中文字符等(unicode >= 128)
static func _is_word_start(ch: String) -> bool:
	var u := ch.unicode_at(0)
	return (u >= 65 and u <= 90) or (u >= 97 and u <= 122) or u == 95 or u >= 128


## 标识符字符: 字母 / 数字 / 下划线 / 中文字符等
static func _is_word_char(ch: String) -> bool:
	var u := ch.unicode_at(0)
	return (u >= 65 and u <= 90) or (u >= 97 and u <= 122) \
		or (u >= 48 and u <= 57) or u == 95 or u >= 128


func _read_number() -> Dictionary:
	var start := _pos
	var is_float := false
	while _pos < _src.length():
		var ch := _src[_pos]
		if ch.is_valid_int():
			_pos += 1
		elif ch == "." and not is_float and _pos + 1 < _src.length() and _src[_pos + 1].is_valid_int():
			is_float = true
			_pos += 1
		else:
			break
	var text := _src.substr(start, _pos - start)
	return _make("FLOAT" if is_float else "INT", float(text) if is_float else int(text))


func _read_string(quote: String) -> Dictionary:
	_pos += 1
	var start := _pos
	while _pos < _src.length() and _src[_pos] != quote:
		if _src[_pos] == "\n":
			break
		_pos += 1
	var text := _src.substr(start, _pos - start)
	if _pos < _src.length():
		_pos += 1  # 跳过引号
	return _make("STRING", text)
