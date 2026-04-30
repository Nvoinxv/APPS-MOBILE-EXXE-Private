// =============================================================================
// python_syntax_highlighter.dart
// Path: frontend/lib/utils/python_syntax_highlighter.dart
//
// Tokenizer + highlighter Python → TextSpan.
// v2: OOP-aware — dunder methods, class inheritance, type annotations,
//     builtin exceptions, *args/**kwargs, attribute/method-call distinction,
//     known decorator variants, `->` annotation arrow.
//     Semua token baru di-map ke warna existing EditorSyntaxColors
//     (tidak perlu ubah apps_colors_tradingview.dart).
// =============================================================================

import 'package:flutter/material.dart';
import '../style/apps_colors_tradingview.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Token types
// ─────────────────────────────────────────────────────────────────────────────

enum PythonTokenType {
  // ── Baseline ──
  keyword,          // if, for, class, def, return, …
  builtinFunc,      // print, len, range, …
  builtinConst,     // True, False, None, …
  builtinException, // Exception, ValueError, TypeError, … (NEW)

  // ── Definitions ──
  decorator,        // @custom_decorator
  decoratorBuiltin, // @property, @classmethod, @staticmethod, … (NEW)
  className,        // name after `class`
  functionDef,      // name after `def` (regular)
  dunderMethod,     // def __init__, def __repr__, … (NEW)
  dunderAttr,       // __name__, self.__dict__, standalone __xxx__ (NEW)

  // ── Literals ──
  string,
  fstring,
  comment,
  number,

  // ── Punctuation / Operators ──
  operator_,
  annotationArrow,  // -> (NEW)
  punctuation,

  // ── Variables / Params ──
  selfParam,        // self, cls
  param,            // *args, **kwargs names (NEW)
  typehint,         // int, str, Optional, List, …

  // ── Attribute access ──
  attribute,        // obj.attr  (no call) (NEW)
  methodCall,       // obj.method(  (NEW)

  plain,
}

// ─────────────────────────────────────────────────────────────────────────────
//  Token model
// ─────────────────────────────────────────────────────────────────────────────

class PythonToken {
  const PythonToken(this.type, this.value);
  final PythonTokenType type;
  final String value;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tokenizer
// ─────────────────────────────────────────────────────────────────────────────

class PythonTokenizer {
  const PythonTokenizer();

  // ── Vocabulary sets ───────────────────────────────────────────────────────

  static const _keywords = {
    'False', 'None', 'True',
    'and', 'as', 'assert', 'async', 'await',
    'break', 'class', 'continue', 'def', 'del',
    'elif', 'else', 'except', 'finally', 'for',
    'from', 'global', 'if', 'import', 'in',
    'is', 'lambda', 'nonlocal', 'not', 'or',
    'pass', 'raise', 'return', 'try', 'while',
    'with', 'yield',
  };

  static const _builtinFuncs = {
    'abs', 'all', 'any', 'ascii', 'bin', 'bool',
    'breakpoint', 'bytearray', 'bytes', 'callable',
    'chr', 'compile', 'complex', 'delattr', 'dict',
    'dir', 'divmod', 'enumerate', 'eval', 'exec',
    'filter', 'float', 'format', 'frozenset', 'getattr',
    'globals', 'hasattr', 'hash', 'help', 'hex', 'id',
    'input', 'int', 'isinstance', 'issubclass', 'iter',
    'len', 'list', 'locals', 'map', 'max', 'memoryview',
    'min', 'next', 'object', 'oct', 'open', 'ord', 'pow',
    'print', 'property', 'range', 'repr', 'reversed',
    'round', 'set', 'setattr', 'slice', 'sorted',
    'staticmethod', 'str', 'sum', 'super', 'tuple',
    'type', 'vars', 'zip',
  };

  static const _builtinConsts = {
    'True', 'False', 'None', 'NotImplemented', 'Ellipsis',
  };

  // All standard Python exceptions + ABC helpers
  static const _builtinExceptions = {
    // Base
    'BaseException', 'Exception', 'ArithmeticError', 'BufferError',
    'LookupError',
    // Concrete errors
    'AssertionError', 'AttributeError', 'BlockingIOError',
    'BrokenPipeError', 'ChildProcessError', 'ConnectionAbortedError',
    'ConnectionError', 'ConnectionRefusedError', 'ConnectionResetError',
    'EOFError', 'EnvironmentError', 'FileExistsError',
    'FileNotFoundError', 'FloatingPointError', 'GeneratorExit',
    'IOError', 'ImportError', 'IndentationError', 'IndexError',
    'InterruptedError', 'IsADirectoryError', 'KeyError',
    'KeyboardInterrupt', 'MemoryError', 'ModuleNotFoundError',
    'NameError', 'NotADirectoryError', 'NotImplementedError',
    'OSError', 'OverflowError', 'PermissionError',
    'ProcessLookupError', 'RecursionError', 'ReferenceError',
    'RuntimeError', 'StopAsyncIteration', 'StopIteration',
    'SyntaxError', 'SystemError', 'SystemExit', 'TabError',
    'TimeoutError', 'TypeError', 'UnboundLocalError', 'UnicodeDecodeError',
    'UnicodeEncodeError', 'UnicodeError', 'UnicodeTranslateError',
    'ValueError', 'WindowsError', 'ZeroDivisionError',
    // Warnings
    'BytesWarning', 'DeprecationWarning', 'FutureWarning',
    'ImportWarning', 'PendingDeprecationWarning', 'ResourceWarning',
    'RuntimeWarning', 'SyntaxWarning', 'UnicodeWarning',
    'UserWarning', 'Warning',
    // Abstract / Protocol helpers (commonly used as base classes)
    'ABC', 'Protocol',
  };

  // Known built-in decorators → get distinct `decoratorBuiltin` type
  static const _builtinDecorators = {
    '@property', '@staticmethod', '@classmethod', '@abstractmethod',
    '@abstractproperty', '@abstractclassmethod', '@abstractstaticmethod',
    '@dataclass', '@overload', '@final', '@runtime_checkable',
    '@cached_property',
  };

  // All dunder (magic) method names — complete list
  static const _dunders = {
    '__abs__', '__add__', '__aenter__', '__aexit__', '__aiter__',
    '__and__', '__anext__', '__await__', '__bool__', '__bytes__',
    '__call__', '__ceil__', '__class__', '__class_getitem__',
    '__contains__', '__copy__', '__deepcopy__', '__del__', '__delattr__',
    '__delete__', '__delitem__', '__delslice__', '__dict__', '__dir__',
    '__divmod__', '__doc__', '__enter__', '__eq__', '__exit__',
    '__file__', '__float__', '__floor__', '__floordiv__', '__format__',
    '__fspath__', '__ge__', '__get__', '__getattr__', '__getattribute__',
    '__getitem__', '__getnewargs__', '__getslice__', '__getstate__',
    '__gt__', '__hash__', '__hex__', '__iadd__', '__iand__', '__ifloordiv__',
    '__ilshift__', '__imod__', '__imul__', '__index__', '__init__',
    '__init_subclass__', '__instancecheck__', '__int__', '__invert__',
    '__ior__', '__ipow__', '__irshift__', '__isub__', '__iter__',
    '__itruediv__', '__ixor__', '__le__', '__len__', '__length_hint__',
    '__lshift__', '__lt__', '__matmul__', '__missing__', '__mod__',
    '__module__', '__mul__', '__name__', '__ne__', '__neg__',
    '__new__', '__next__', '__oct__', '__or__', '__package__',
    '__pos__', '__pow__', '__prepare__', '__radd__', '__rand__',
    '__rdivmod__', '__reduce__', '__reduce_ex__', '__repr__',
    '__reversed__', '__rfloordiv__', '__rlshift__', '__rmatmul__',
    '__rmod__', '__rmul__', '__ror__', '__round__', '__rpow__',
    '__rrshift__', '__rshift__', '__rsub__', '__rtruediv__', '__rxor__',
    '__set__', '__set_name__', '__setattr__', '__setitem__',
    '__setslice__', '__setstate__', '__sizeof__', '__slots__',
    '__str__', '__sub__', '__subclasshook__', '__truediv__',
    '__trunc__', '__weakref__', '__xor__', '__all__', '__annotations__',
    '__builtins__', '__cached__', '__loader__', '__path__', '__spec__',
    '__version__',
  };

  static const _typehints = {
    'int', 'float', 'str', 'bool', 'bytes', 'complex',
    'list', 'dict', 'tuple', 'set', 'frozenset',
    'Optional', 'Union', 'List', 'Dict', 'Tuple', 'Set', 'FrozenSet',
    'Any', 'Callable', 'Type', 'ClassVar', 'Final',
    'Literal', 'TypeVar', 'Generic', 'Sequence', 'Iterable',
    'Iterator', 'Generator', 'Awaitable', 'Coroutine',
    'AsyncIterable', 'AsyncIterator', 'AsyncGenerator',
    'Mapping', 'MutableMapping', 'MutableSequence', 'MutableSet',
    'NamedTuple', 'TypedDict', 'IO', 'TextIO', 'BinaryIO',
    'Pattern', 'Match', 'Deque', 'DefaultDict', 'OrderedDict',
    'Counter', 'ChainMap', 'Annotated', 'Never', 'NoReturn',
    'ParamSpec', 'TypeAlias', 'TypeGuard', 'Unpack', 'Self',
    'LiteralString', 'Concatenate',
  };

  // ── Main tokenize ─────────────────────────────────────────────────────────

  List<PythonToken> tokenize(String source) {
    final tokens  = <PythonToken>[];
    int i         = 0;
    final n       = source.length;

    // ── Context state ─────────────────────────────────────────────────────

    /// Last token that was '.'
    bool afterDot      = false;
    /// Last significant operator was '->'
    bool afterArrow    = false;
    /// Last keyword was 'def'
    bool afterDef      = false;
    /// Last keyword was 'class'
    bool afterClass    = false;
    /// Inside `class Foo(BaseClass1, BaseClass2):`
    bool inClassParen  = false;
    int  cpDepth       = 0;
    /// Saw `*` right before this ident → *args
    bool starPending   = false;
    /// Saw `**` right before this ident → **kwargs
    bool dstarPending  = false;

    // ── Context helpers ───────────────────────────────────────────────────

    // Last non-plain (non-whitespace) token
    PythonToken? prevSig() {
      for (int k = tokens.length - 1; k >= 0; k--) {
        if (tokens[k].type != PythonTokenType.plain) return tokens[k];
      }
      return null;
    }

    // Whether the char at pos (skipping spaces) is '('
    bool nextIsCall(int pos) {
      while (pos < n && (source[pos] == ' ' || source[pos] == '\t')) pos++;
      return pos < n && source[pos] == '(';
    }

    // Reset flags after consuming a significant identifier token
    void consumeIdent() {
      afterDot = afterArrow = afterDef = afterClass = false;
      starPending = dstarPending = false;
    }

    // ── Main loop ─────────────────────────────────────────────────────────

    while (i < n) {
      final ch = source[i];

      // ── Newline ────────────────────────────────────────────────────────
      if (ch == '\n') {
        tokens.add(const PythonToken(PythonTokenType.plain, '\n'));
        i++;
        // def/class can't span lines bare, arrow can if wrapped
        afterDef = afterClass = afterArrow = afterDot = false;
        starPending = dstarPending = false;
        continue;
      }

      // ── Whitespace ────────────────────────────────────────────────────
      if (ch == ' ' || ch == '\t' || ch == '\r') {
        final s = i;
        while (i < n && (source[i] == ' ' || source[i] == '\t' || source[i] == '\r')) {
          i++;
        }
        tokens.add(PythonToken(PythonTokenType.plain, source.substring(s, i)));
        continue; // preserve context across spaces
      }

      // ── Comment ───────────────────────────────────────────────────────
      if (ch == '#') {
        final s = i;
        while (i < n && source[i] != '\n') i++;
        tokens.add(PythonToken(PythonTokenType.comment, source.substring(s, i)));
        afterDef = afterClass = afterArrow = afterDot = false;
        continue;
      }

      // ── Triple-quoted string (check before single-quote) ──────────────
      if (i + 2 < n) {
        final tri = source.substring(i, i + 3);
        if (tri == '"""' || tri == "'''") {
          final s = i;
          i += 3;
          while (i + 2 < n && source.substring(i, i + 3) != tri) i++;
          i = (i + 2 < n) ? i + 3 : n; // safe advance
          tokens.add(PythonToken(PythonTokenType.string, source.substring(s, i)));
          afterDot = afterArrow = afterDef = afterClass = false;
          continue;
        }
      }

      // ── f-string ──────────────────────────────────────────────────────
      if ((ch == 'f' || ch == 'F') && i + 1 < n &&
          (source[i + 1] == '"' || source[i + 1] == "'")) {
        final s = i;
        final q = source[i + 1];
        i += 2;
        while (i < n && source[i] != q && source[i] != '\n') {
          if (source[i] == '\\') { i++; if (i < n) i++; } else { i++; }
        }
        if (i < n && source[i] == q) i++;
        tokens.add(PythonToken(PythonTokenType.fstring, source.substring(s, i)));
        afterDot = afterArrow = afterDef = afterClass = false;
        continue;
      }

      // ── Regular string ────────────────────────────────────────────────
      if (ch == '"' || ch == "'") {
        final s = i;
        final q = ch;
        i++;
        while (i < n && source[i] != q && source[i] != '\n') {
          if (source[i] == '\\') { i++; if (i < n) i++; } else { i++; }
        }
        if (i < n && source[i] == q) i++;
        tokens.add(PythonToken(PythonTokenType.string, source.substring(s, i)));
        afterDot = afterArrow = afterDef = afterClass = false;
        continue;
      }

      // ── Decorator ─────────────────────────────────────────────────────
      if (ch == '@') {
        final s = i;
        i++;
        while (i < n && RegExp(r'[a-zA-Z0-9_\.]').hasMatch(source[i])) i++;
        final full = source.substring(s, i);
        final type = _builtinDecorators.contains(full)
            ? PythonTokenType.decoratorBuiltin
            : PythonTokenType.decorator;
        tokens.add(PythonToken(type, full));
        afterDot = afterArrow = afterDef = afterClass = false;
        continue;
      }

      // ── Number ────────────────────────────────────────────────────────
      if (RegExp(r'[0-9]').hasMatch(ch) ||
          (ch == '.' && i + 1 < n && RegExp(r'[0-9]').hasMatch(source[i + 1]))) {
        final s = i;
        if (ch == '0' && i + 1 < n && 'xXoObB'.contains(source[i + 1])) {
          i += 2;
          while (i < n && RegExp(r'[0-9a-fA-F_]').hasMatch(source[i])) i++;
        } else {
          while (i < n && RegExp(r'[0-9_\.]').hasMatch(source[i])) i++;
          if (i < n && (source[i] == 'e' || source[i] == 'E')) {
            i++;
            if (i < n && (source[i] == '+' || source[i] == '-')) i++;
            while (i < n && RegExp(r'[0-9_]').hasMatch(source[i])) i++;
          }
          if (i < n && (source[i] == 'j' || source[i] == 'J')) i++;
        }
        tokens.add(PythonToken(PythonTokenType.number, source.substring(s, i)));
        afterDot = afterArrow = false;
        continue;
      }

      // ── Identifier / keyword ──────────────────────────────────────────
      if (RegExp(r'[a-zA-Z_]').hasMatch(ch)) {
        final s    = i;
        while (i < n && RegExp(r'[a-zA-Z0-9_]').hasMatch(source[i])) i++;
        final word = source.substring(s, i);
        final isCallNext = nextIsCall(i);
        final isDunder   = _dunders.contains(word) ||
                           (word.startsWith('__') && word.endsWith('__') && word.length > 4);

        PythonTokenType type;

        // ── After dot: attribute access or method call ─────────────────
        if (afterDot) {
          if (isDunder) {
            type = PythonTokenType.dunderAttr;
          } else if (isCallNext) {
            type = PythonTokenType.methodCall;
          } else {
            type = PythonTokenType.attribute;
          }

        // ── Known constants (self/cls first) ───────────────────────────
        } else if (word == 'self' || word == 'cls') {
          type = PythonTokenType.selfParam;

        } else if (_builtinConsts.contains(word)) {
          type = PythonTokenType.builtinConst;

        // ── Keywords ──────────────────────────────────────────────────
        } else if (_keywords.contains(word)) {
          type = PythonTokenType.keyword;
          // Update contextual flags
          afterDef   = (word == 'def');
          afterClass = (word == 'class');
          tokens.add(PythonToken(type, word));
          if (word != 'def' && word != 'class') {
            afterDef = afterClass = false;
          }
          // Skip standard consumeIdent so def/class flags survive
          afterDot = afterArrow = false;
          starPending = dstarPending = false;
          continue;

        // ── Builtin exceptions (before builtinFuncs to avoid overlap) ──
        } else if (_builtinExceptions.contains(word)) {
          type = PythonTokenType.builtinException;

        // ── Builtin functions ─────────────────────────────────────────
        } else if (_builtinFuncs.contains(word)) {
          type = PythonTokenType.builtinFunc;

        // ── Type hints ────────────────────────────────────────────────
        } else if (_typehints.contains(word) || afterArrow) {
          type = PythonTokenType.typehint;

        // ── Context-dependent: after `def` ────────────────────────────
        } else if (afterDef) {
          type = isDunder
              ? PythonTokenType.dunderMethod
              : PythonTokenType.functionDef;

        // ── Context-dependent: after `class` ──────────────────────────
        } else if (afterClass) {
          type = PythonTokenType.className;

        // ── Context-dependent: inside class(...) inheritance ──────────
        } else if (inClassParen) {
          // Parent class names → treat like builtinException color
          // (same visual as class-name: they ARE class references)
          type = _builtinExceptions.contains(word)
              ? PythonTokenType.builtinException
              : PythonTokenType.typehint;

        // ── *args / **kwargs ──────────────────────────────────────────
        } else if (starPending || dstarPending) {
          type = PythonTokenType.param;

        // ── General: any call looks like a function ────────────────────
        } else if (isCallNext) {
          type = PythonTokenType.builtinFunc;

        // ── Standalone dunder attr ────────────────────────────────────
        } else if (isDunder) {
          type = PythonTokenType.dunderAttr;

        // ── Plain identifier ──────────────────────────────────────────
        } else {
          type = PythonTokenType.plain;
        }

        tokens.add(PythonToken(type, word));

        // Update class-paren context AFTER adding className
        if (type == PythonTokenType.className && nextIsCall(i)) {
          inClassParen = true;
          cpDepth      = 0; // '(' will increment it
        }

        consumeIdent();
        continue;
      }

      // ── Operators ─────────────────────────────────────────────────────

      // '**' — double star
      if (ch == '*' && i + 1 < n && source[i + 1] == '*') {
        i += 2;
        final prev = prevSig();
        if (prev?.value == '(' || prev?.value == ',') dstarPending = true;
        afterDot = afterDef = afterClass = afterArrow = false;
        tokens.add(const PythonToken(PythonTokenType.operator_, '**'));
        continue;
      }

      // '->' annotation arrow
      if (ch == '-' && i + 1 < n && source[i + 1] == '>') {
        i += 2;
        afterArrow = true;
        afterDot = afterDef = afterClass = false;
        starPending = dstarPending = false;
        tokens.add(const PythonToken(PythonTokenType.annotationArrow, '->'));
        continue;
      }

      // Regular operators — '*' may be *args if in param context
      if ('+-*/%=<>!&|^~'.contains(ch)) {
        final s = i;
        i++;
        if (ch == '*') {
          // single star — could be *args
          final prev = prevSig();
          if (prev?.value == '(' || prev?.value == ',') starPending = true;
        }
        if (i < n && '=*/<>'.contains(source[i]) && !(ch == '*')) i++; // compound op
        final op = source.substring(s, i);
        afterDot = afterDef = afterClass = false;
        if (ch != '*') afterArrow = false; // keep arrow context through whitespace only
        tokens.add(PythonToken(PythonTokenType.operator_, op));
        continue;
      }

      // ── Punctuation ───────────────────────────────────────────────────
      if ('()[]{}:,;.'.contains(ch)) {
        if (ch == '.') {
          afterDot   = true;
          afterArrow = afterDef = afterClass = false;
          starPending = dstarPending = false;
        } else {
          if (ch == '(') {
            if (inClassParen) cpDepth++;
          } else if (ch == ')') {
            if (inClassParen) {
              cpDepth--;
              if (cpDepth <= 0) inClassParen = false;
            }
          }
          // Non-dot punctuation resets most context
          afterDot = false;
          if (ch != ':' && ch != ',') {
            // `:` and `,` preserve arrow context (for multi-line annotations)
            afterArrow = false;
          }
          afterDef = afterClass = false;
          if (ch != ',') starPending = dstarPending = false;
        }
        tokens.add(PythonToken(PythonTokenType.punctuation, ch));
        i++;
        continue;
      }

      // ── Fallback ──────────────────────────────────────────────────────
      tokens.add(PythonToken(PythonTokenType.plain, ch));
      i++;
    }

    return tokens;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PythonSyntaxHighlighter  — color/style mapping + simple cache
// ─────────────────────────────────────────────────────────────────────────────

class PythonSyntaxHighlighter {
  const PythonSyntaxHighlighter._();

  static const _tokenizer = PythonTokenizer();

  // 1-entry cache: skips re-tokenize for the same source string
  static String?           _cachedSource;
  static List<PythonToken>? _cachedTokens;

  static List<PythonToken> _getTokens(String source) {
    if (source == _cachedSource && _cachedTokens != null) return _cachedTokens!;
    _cachedSource = source;
    _cachedTokens = _tokenizer.tokenize(source);
    return _cachedTokens!;
  }

  // ── Color mapping ─────────────────────────────────────────────────────────
  // New types reuse existing EditorSyntaxColors fields — no schema change needed.
  static Color _colorFor(PythonTokenType t, EditorSyntaxColors c) => switch (t) {
    PythonTokenType.keyword          => c.keyword,
    PythonTokenType.builtinFunc      => c.builtinFunc,
    PythonTokenType.builtinConst     => c.builtinConst,
    // Exceptions share className color (they ARE classes)
    PythonTokenType.builtinException => c.className,
    PythonTokenType.decorator        => c.decorator,
    // Built-in decorators feel like keywords (property, classmethod, …)
    PythonTokenType.decoratorBuiltin => c.keyword,
    PythonTokenType.className        => c.className,
    PythonTokenType.functionDef      => c.functionDef,
    // Dunder methods: decorator-gold, clearly "magic"
    PythonTokenType.dunderMethod     => c.decorator,
    // Dunder attributes: same family but softer
    PythonTokenType.dunderAttr       => c.decorator,
    PythonTokenType.string           => c.string,
    PythonTokenType.fstring          => c.fstring,
    PythonTokenType.comment          => c.comment,
    PythonTokenType.number           => c.number,
    PythonTokenType.operator_        => c.operator_,
    // Annotation arrow matches operator color
    PythonTokenType.annotationArrow  => c.operator_,
    PythonTokenType.punctuation      => c.punctuation,
    PythonTokenType.selfParam        => c.selfParam,
    // *args/**kwargs: same family as self/cls
    PythonTokenType.param            => c.selfParam,
    PythonTokenType.typehint         => c.typehint,
    // Method calls: same as builtinFunc (it's a function call)
    PythonTokenType.methodCall       => c.builtinFunc,
    // Plain attribute access: slightly tinted but readable
    PythonTokenType.attribute        => c.plain,
    PythonTokenType.plain            => c.plain,
  };

  // ── Weight mapping ────────────────────────────────────────────────────────
  static FontWeight _weightFor(PythonTokenType t) => switch (t) {
    PythonTokenType.keyword          ||
    PythonTokenType.decoratorBuiltin ||
    PythonTokenType.builtinConst     ||
    PythonTokenType.className        ||
    PythonTokenType.builtinException ||
    PythonTokenType.functionDef      ||
    PythonTokenType.dunderMethod     => FontWeight.w600,
    _ => FontWeight.w400,
  };

  // ── Style mapping ─────────────────────────────────────────────────────────
  static FontStyle _fontStyleFor(PythonTokenType t) => switch (t) {
    PythonTokenType.comment          ||
    PythonTokenType.decorator        ||
    PythonTokenType.decoratorBuiltin ||
    PythonTokenType.selfParam        ||
    PythonTokenType.param            ||
    PythonTokenType.dunderMethod     ||
    PythonTokenType.dunderAttr       => FontStyle.italic,
    _ => FontStyle.normal,
  };

  // ── Public API ────────────────────────────────────────────────────────────

  static TextSpan buildTextSpan(
    String source, {
    EditorThemeState? theme,
  }) {
    final t      = theme ?? EditorThemeState();
    final syntax = t.syntax;
    final base   = t.typography.baseStyle.copyWith(color: syntax.plain);
    final tokens = _getTokens(source);

    final spans = tokens.map((tok) => TextSpan(
      text:  tok.value,
      style: base.copyWith(
        color:      _colorFor(tok.type, syntax),
        fontWeight: _weightFor(tok.type),
        fontStyle:  _fontStyleFor(tok.type),
      ),
    )).toList(growable: false);

    return TextSpan(style: base, children: spans);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PythonCodeView  — drop-in read-only widget
// ─────────────────────────────────────────────────────────────────────────────

class PythonCodeView extends StatelessWidget {
  const PythonCodeView({
    super.key,
    required this.source,
    this.theme,
    this.showLineNumbers = true,
    this.activeLineIndex,
  });

  final String            source;
  final EditorThemeState? theme;
  final bool              showLineNumbers;
  final int?              activeLineIndex;

  @override
  Widget build(BuildContext context) {
    final t      = theme ?? EditorThemeState();
    final chrome = t.chrome;
    final lines  = source.split('\n');

    return Container(
      color: chrome.background.withOpacity(t.backgroundOpacity),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLineNumbers)
                  _LineNumberGutter(
                    lineCount:       lines.length,
                    activeLineIndex: activeLineIndex,
                    theme:           t,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12,
                    ),
                    child: SelectableText.rich(
                      PythonSyntaxHighlighter.buildTextSpan(source, theme: t),
                      style: t.typography.baseStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Line number gutter (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _LineNumberGutter extends StatelessWidget {
  const _LineNumberGutter({
    required this.lineCount,
    required this.theme,
    this.activeLineIndex,
  });

  final int              lineCount;
  final EditorThemeState theme;
  final int?             activeLineIndex;

  @override
  Widget build(BuildContext context) {
    final chrome = theme.chrome;
    final typo   = theme.typography;

    return Container(
      color:   chrome.gutterBackground,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: chrome.gutterBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(lineCount, (i) {
          final isActive = i == activeLineIndex;
          return Container(
            height:    typo.fontSize * typo.lineHeight,
            color:     isActive ? chrome.activeLineHighlight : Colors.transparent,
            alignment: Alignment.centerRight,
            padding:   const EdgeInsets.only(right: 2),
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontFamily: typo.fontFamily,
                fontSize:   typo.fontSize,
                height:     typo.lineHeight,
                color: isActive ? chrome.lineNumberActive : chrome.lineNumberDefault,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mixin: PythonHighlighterMixin
// ─────────────────────────────────────────────────────────────────────────────

mixin PythonHighlighterMixin<T extends StatefulWidget> on State<T> {
  EditorThemeState get editorTheme => EditorThemeState();

  TextSpan highlightCode(String code) =>
      PythonSyntaxHighlighter.buildTextSpan(code, theme: editorTheme);
}