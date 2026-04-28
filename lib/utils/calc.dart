/// Tiny safe arithmetic evaluator for amount fields.
/// Supports + - * / and decimals (both `,` and `.` as decimal separator).
/// Returns null if expression is invalid.
double? evalAmount(String input) {
  final s = input.replaceAll(' ', '').replaceAll(',', '.');
  if (s.isEmpty) return null;
  // Reject anything outside digits/operators/decimal point
  if (!RegExp(r'^[0-9+\-*/.()]+$').hasMatch(s)) return null;
  try {
    return _eval(_tokenize(s));
  } catch (_) {
    return null;
  }
}

class _Tok {
  final String type; // num, op, lp, rp
  final String? op;
  final double? num;
  _Tok.num(this.num) : type = 'num', op = null;
  _Tok.op(this.op) : type = 'op', num = null;
  _Tok.lp() : type = 'lp', op = null, num = null;
  _Tok.rp() : type = 'rp', op = null, num = null;
}

List<_Tok> _tokenize(String s) {
  final out = <_Tok>[];
  final n = s.length;
  var i = 0;
  while (i < n) {
    final c = s[i];
    if (c == '(') { out.add(_Tok.lp()); i++; continue; }
    if (c == ')') { out.add(_Tok.rp()); i++; continue; }
    if ('+-*/'.contains(c)) {
      // unary minus at start or after operator/lp -> treat as 0 - x
      final prev = out.isEmpty ? null : out.last;
      if (c == '-' && (prev == null || prev.type == 'op' || prev.type == 'lp')) {
        out.add(_Tok.num(0));
      }
      out.add(_Tok.op(c));
      i++;
      continue;
    }
    if (RegExp(r'[0-9.]').hasMatch(c)) {
      final start = i;
      while (i < n && RegExp(r'[0-9.]').hasMatch(s[i])) {
        i++;
      }
      out.add(_Tok.num(double.parse(s.substring(start, i))));
      continue;
    }
    throw const FormatException('bad char');
  }
  return out;
}

double _eval(List<_Tok> tokens) {
  // Shunting-yard to RPN
  final out = <_Tok>[];
  final ops = <_Tok>[];
  int prec(String op) => (op == '+' || op == '-') ? 1 : 2;
  for (final t in tokens) {
    if (t.type == 'num') {
      out.add(t);
    } else if (t.type == 'op') {
      while (ops.isNotEmpty && ops.last.type == 'op' && prec(ops.last.op!) >= prec(t.op!)) {
        out.add(ops.removeLast());
      }
      ops.add(t);
    } else if (t.type == 'lp') {
      ops.add(t);
    } else if (t.type == 'rp') {
      while (ops.isNotEmpty && ops.last.type != 'lp') {
        out.add(ops.removeLast());
      }
      if (ops.isEmpty) throw const FormatException('paren');
      ops.removeLast();
    }
  }
  while (ops.isNotEmpty) {
    final o = ops.removeLast();
    if (o.type == 'lp') throw const FormatException('paren');
    out.add(o);
  }
  // Evaluate RPN
  final st = <double>[];
  for (final t in out) {
    if (t.type == 'num') {
      st.add(t.num!);
    } else {
      if (st.length < 2) throw const FormatException('arity');
      final b = st.removeLast();
      final a = st.removeLast();
      switch (t.op) {
        case '+': st.add(a + b); break;
        case '-': st.add(a - b); break;
        case '*': st.add(a * b); break;
        case '/':
          if (b == 0) throw const FormatException('div0');
          st.add(a / b); break;
      }
    }
  }
  if (st.length != 1) throw const FormatException('result');
  return st.single;
}
