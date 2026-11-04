/// Cleans raw LaTeX notation from AI responses into plain readable text.
///
/// Converts patterns like $\frac{2}{4}$ → 2/4, $x^{2}$ → x^2, etc.
String sanitizeLatex(String text) {
  var result = text;

  // \frac{a}{b} → a/b
  result = result.replaceAllMapped(
    RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}'),
    (m) => '${m[1]}/${m[2]}',
  );

  // \sqrt{x} → √x
  result = result.replaceAllMapped(
    RegExp(r'\\sqrt\{([^}]*)\}'),
    (m) => '√${m[1]}',
  );

  // x^{n} → x^n
  result = result.replaceAllMapped(RegExp(r'\^\{([^}]*)\}'), (m) => '^${m[1]}');

  // _{n} → _n (subscript)
  result = result.replaceAllMapped(RegExp(r'_\{([^}]*)\}'), (m) => '_${m[1]}');

  // \times → ×
  result = result.replaceAll(r'\times', '×');

  // \div → ÷
  result = result.replaceAll(r'\div', '÷');

  // \pm → ±
  result = result.replaceAll(r'\pm', '±');

  // \leq \geq \neq → ≤ ≥ ≠
  result = result.replaceAll(r'\leq', '≤');
  result = result.replaceAll(r'\geq', '≥');
  result = result.replaceAll(r'\neq', '≠');

  // \pi → π
  result = result.replaceAll(r'\pi', 'π');

  // \infty → ∞
  result = result.replaceAll(r'\infty', '∞');

  // Strip remaining $ delimiters
  result = result.replaceAll(RegExp(r'\$'), '');

  // Strip \( \) \[ \] delimiters
  result = result.replaceAll(r'\(', '');
  result = result.replaceAll(r'\)', '');
  result = result.replaceAll(r'\[', '');
  result = result.replaceAll(r'\]', '');

  // Remove remaining backslash-commands like \text{...} → contents
  result = result.replaceAllMapped(
    RegExp(r'\\[a-zA-Z]+\{([^}]*)\}'),
    (m) => m[1] ?? '',
  );

  return result;
}
