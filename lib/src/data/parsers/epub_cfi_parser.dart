import 'dart:math';
import 'package:epubx/epubx.dart';
import 'package:equatable/equatable.dart';
import 'package:html/dom.dart';

abstract class CfiResult extends Equatable {
  @override
  List<Object?> get props => [];
}

class CfiFragment extends CfiResult {
  CfiFragment({
    required this.type,
    required this.range,
    required this.path,
  });

  final String type;
  final CfiRange? range;
  final CfiPath? path;

  @override
  List<Object?> get props => [type, range, path];
}

class CfiRange extends CfiResult {
  CfiRange({
    required this.type,
    required this.path,
    required this.localPath,
    required this.range1,
    required this.range2,
  });

  final String type;
  final CfiStep? path;
  final CfiLocalPath? localPath;
  final CfiLocalPath? range1;
  final CfiLocalPath? range2;

  @override
  List<Object?> get props => [type, path, localPath, range1, range2];
}

class CfiPath extends CfiResult {
  CfiPath({
    required this.type,
    required this.path,
    required this.localPath,
  });

  final String type;
  final CfiStep? path;
  final CfiLocalPath? localPath;

  @override
  List<Object?> get props => [type, path, localPath];
}

class CfiLocalPath extends CfiResult {
  CfiLocalPath({required this.steps, required this.termStep});

  final List<CfiStep>? steps;
  final CfiTerminus? termStep;

  @override
  List<Object?> get props => [steps, termStep];
}

class CfiStep extends CfiResult {
  CfiStep({
    required this.type,
    required this.stepLength,
    required this.idAssertion,
  });

  final String type;
  final int stepLength;
  final String? idAssertion;

  @override
  List<Object?> get props => [type, stepLength, idAssertion];
}

class CfiTerminus extends CfiResult {
  CfiTerminus({
    required this.type,
    required this.offsetValue,
    required this.textAssertion,
  });

  final String type;
  final int? offsetValue;
  final CfiTextLocationAssertion? textAssertion;

  @override
  List<Object?> get props => [type, offsetValue, textAssertion];
}

class CfiTextLocationAssertion extends CfiResult {
  CfiTextLocationAssertion({
    required this.type,
    required this.csv,
    required this.parameter,
  });

  final String type;
  final CfiCsv? csv;
  final CfiParameter? parameter;

  @override
  List<Object?> get props => [type, csv, parameter];
}

class CfiParameter extends CfiResult {
  CfiParameter({
    required this.type,
    required this.lHSValue,
    required this.rHSValue,
  });

  final String type;
  final String? lHSValue;
  final String? rHSValue;

  @override
  List<Object?> get props => [type, lHSValue, rHSValue];
}

class CfiCsv extends CfiResult {
  CfiCsv({
    required this.type,
    required this.preAssertion,
    required this.postAssertion,
  });

  final String type;
  final String? preAssertion;
  final String? postAssertion;

  @override
  List<Object?> get props => [type, preAssertion, postAssertion];
}

class ErrorPosition {
  ErrorPosition({required this.line, required this.column});

  final int line;
  final int column;
}

class CfiSyntaxException extends Equatable implements Exception {
  const CfiSyntaxException(
    this.expected,
    this.found,
    this.offset,
    this.line,
    this.column,
  );

  final List<String> expected;
  final String? found;
  final int offset;
  final int line;
  final int column;

  String _buildMessage() {
    String expectedHumanized, foundHumanized;

    switch (expected.length) {
      case 0:
        expectedHumanized = 'end of input';
        break;
      case 1:
        expectedHumanized = expected[0];
        break;
      default:
        expectedHumanized =
            '${expected.sublist(0, expected.length - 1).join(', ')} or ${expected[expected.length - 1]}';
    }

    foundHumanized =
        (found ?? '').isNotEmpty ? EpubCfiParser.quote(found!) : 'end of input';

    return 'Expected $expectedHumanized but $foundHumanized found (line: $line col: $column).';
  }

  @override
  String toString() {
    if (expected.isEmpty) {
      return 'CfiSyntaxException';
    }
    return _buildMessage();
  }

  @override
  List<Object?> get props => [expected, found, offset, line, column];
}

class EpubCfiParser {
  final int reportFailures = 0;
  int rightmostFailuresPos = 0;
  List<String> rightmostFailuresExpected = [];
  int pos = 0;
  late String input;
  String? startRule;

  static String quote(String s) =>
      '"${s.replaceAll(RegExp(r'\\'), '\\\\').replaceAll(RegExp(r'"'), '\\"').replaceAll(RegExp(r'\x08'), '\\b').replaceAll(RegExp(r'\t'), '\\t').replaceAll(RegExp(r'\n'), '\\n').replaceAll(RegExp(r'\f'), '\\f').replaceAll(RegExp(r'\r'), '\\r').replaceAllMapped(RegExp(r'[\x00-\x07\x0B\x0E-\x1F\x80-\uFFFF]'), (Match m) => Uri.encodeFull(m[0]!))}"';

  dynamic parse(String? preInput, String? preStartRule) {
    input = preInput ?? '';
    startRule = preStartRule;

    final parseFunctions = {
      'fragment': _parseFragment,
      'range': _parseRange,
      'path': _parsePath,
      'local_path': _parseLocalPath,
      'indexStep': _parseIndexStep,
      'indirectionStep': _parseIndirectionStep,
      'terminus': _parseTerminus,
      'idAssertion': _parseIdAssertion,
      'textLocationAssertion': _parseTextLocationAssertion,
      'parameter': _parseParameter,
      'csv': _parseCsv,
      'valueNoSpace': _parseValueNoSpace,
      'value': _parseValue,
      'escapedSpecialChars': _parseEscapedSpecialChars,
      'number': _parseNumber,
      'integer': _parseInteger,
      'space': _parseSpace,
      'circumflex': _parseCircumflex,
      'doubleQuote': _parseDoubleQuote,
      'squareBracket': _parseSquareBracket,
      'parentheses': _parseParentheses,
      'comma': _parseComma,
      'semicolon': _parseSemicolon,
      'equal': _parseEqual,
      'character': _parseCharacter
    };

    if (startRule != null) {
      if (parseFunctions[startRule!] == null) {
        throw Exception('Invalid rule name: ${quote(startRule!)}.');
      }
    } else {
      startRule = 'fragment';
    }

    final result = parseFunctions[startRule!]!();

    if (result == null || pos != input.length) {
      final offset = max(pos, rightmostFailuresPos);
      final found = offset < input.length ? input[offset] : null;
      final errorPosition = _computeErrorPosition();

      throw CfiSyntaxException(
        _cleanupExpected(rightmostFailuresExpected),
        found,
        offset,
        errorPosition.line,
        errorPosition.column,
      );
    }

    return result;
  }

  void _matchFailed(String expected) {
    if (pos < rightmostFailuresPos) {
      return;
    }
    if (pos > rightmostFailuresPos) {
      rightmostFailuresPos = pos;
      rightmostFailuresExpected = [];
    }
    rightmostFailuresExpected.add(expected);
  }

  ErrorPosition _computeErrorPosition() {
    int line = 1;
    int column = 1;
    for (int i = 0; i < pos; i++) {
      if (input.codeUnitAt(i) == 10) {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    return ErrorPosition(line: line, column: column);
  }

  List<String> _cleanupExpected(List<String> expected) {
    final uniqueExpected = expected.toSet().toList();
    uniqueExpected.sort();
    return uniqueExpected;
  }

  CfiFragment? _parseFragment() {
    dynamic result0, result1, result2;
    int pos0, pos1;

    pos0 = pos;
    pos1 = pos;
    if ((pos + 8) <= input.length && input.substring(pos, pos + 8) == 'epubcfi(') {
      result0 = 'epubcfi(';
      pos += 8;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('"epubcfi("');
      }
    }
    if (result0 != null) {
      result1 = _parseRange();
      result1 ??= _parsePath();
      if (result1 != null) {
        if (pos < input.length && input.codeUnitAt(pos) == 41) {
          result2 = ')';
          pos++;
        } else {
          result2 = null;
          if (reportFailures == 0) {
            _matchFailed('")"');
          }
        }
        if (result2 != null) {
          result0 = [result0, result1, result2];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((int offset, fragmentVal) => CfiFragment(
            type: 'CFIAST',
            range: fragmentVal is CfiRange ? fragmentVal : null,
            path: fragmentVal is CfiPath ? fragmentVal : null,
          ))(pos0, result0[1]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiRange? _parseRange() {
    dynamic result0, result1, result2, result3, result5;
    String? result4;
    int pos0, pos1;

    pos0 = pos;
    pos1 = pos;
    result0 = _parseIndexStep();
    if (result0 != null) {
      result1 = _parseLocalPath();
      if (result1 != null) {
        if (pos < input.length && input.codeUnitAt(pos) == 44) {
          result2 = ',';
          pos++;
        } else {
          result2 = null;
          if (reportFailures == 0) {
            _matchFailed('","');
          }
        }
        if (result2 != null) {
          result3 = _parseLocalPath();
          if (result3 != null) {
            if (pos < input.length && input.codeUnitAt(pos) == 44) {
              result4 = ',';
              pos++;
            } else {
              result4 = null;
              if (reportFailures == 0) {
                _matchFailed('","');
              }
            }
            if (result4 != null) {
              result5 = _parseLocalPath();
              if (result5 != null) {
                result0 = [result0, result1, result2, result3, result4, result5];
              } else {
                result0 = null;
                pos = pos1;
              }
            } else {
              result0 = null;
              pos = pos1;
            }
          } else {
            result0 = null;
            pos = pos1;
          }
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((int offset, CfiStep? stepVal, CfiLocalPath? localPathVal, CfiLocalPath? rangeLocalPath1Val, CfiLocalPath? rangeLocalPath2Val) => CfiRange(
            type: 'range',
            path: stepVal,
            localPath: localPathVal,
            range1: rangeLocalPath1Val,
            range2: rangeLocalPath2Val,
          ))(pos0, result0[0], result0[1], result0[3], result0[5]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiPath? _parsePath() {
    dynamic result0, result1;
    final int pos0 = pos, pos1 = pos;

    result0 = _parseIndexStep();
    if (result0 != null) {
      result1 = _parseLocalPath();
      if (result1 != null) {
        result0 = [result0, result1];
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((int offset, CfiStep? stepVal, CfiLocalPath? localPathVal) => CfiPath(
            type: 'path',
            path: stepVal,
            localPath: localPathVal,
          ))(pos0, result0[0], result0[1]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiLocalPath? _parseLocalPath() {
    dynamic result0;
    CfiStep? result1;
    CfiTerminus? result2;
    List<CfiStep>? result3;

    final int pos0 = pos, pos1 = pos;

    result1 = _parseIndexStep();
    result1 ??= _parseIndirectionStep();
    if (result1 != null) {
      result0 = [];
      result3 = [];
      while (result1 != null) {
        result3.add(result1);
        result1 = _parseIndexStep();
        result1 ??= _parseIndirectionStep();
      }
    } else {
      result0 = null;
      result3 = null;
    }
    if (result0 != null) {
      result2 = _parseTerminus() ?? CfiTerminus(type: 'textTerminus', offsetValue: null, textAssertion: null);
      result0 = [result3, result2];
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((int offset, List<CfiStep>? localPathStepVal, termStepVal) => CfiLocalPath(steps: localPathStepVal, termStep: termStepVal))(pos0, result0[0], result0[1]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiStep? _parseIndexStep() {
    dynamic result0, result1, result2;
    String? result3, result4;
    final int pos0 = pos, pos1 = pos;
    int pos2;

    if (pos < input.length && input.codeUnitAt(pos) == 47) {
      result0 = '/';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('"/"');
      }
    }
    if (result0 != null) {
      result1 = _parseInteger();
      if (result1 != null) {
        pos2 = pos;
        if (pos < input.length && input.codeUnitAt(pos) == 91) {
          result2 = '[';
          pos++;
        } else {
          result2 = null;
          if (reportFailures == 0) {
            _matchFailed('"["');
          }
        }
        if (result2 != null) {
          result3 = _parseIdAssertion();
          if (result3 != null) {
            if (pos < input.length && input.codeUnitAt(pos) == 93) {
              result4 = ']';
              pos++;
            } else {
              result4 = null;
              if (reportFailures == 0) {
                _matchFailed('"]"');
              }
            }
            if (result4 != null) {
              result2 = [result2, result3, result4];
            } else {
              result2 = null;
              pos = pos2;
            }
          } else {
            result2 = null;
            pos = pos2;
          }
        } else {
          result2 = null;
          pos = pos2;
        }
        result2 = result2 ?? '';
        if (result2 != null) {
          result0 = [result0, result1, result2];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((int offset, String stepLengthVal, assertVal) => CfiStep(
            type: 'indexStep',
            stepLength: int.parse(stepLengthVal),
            idAssertion: assertVal is List && assertVal.length > 1 ? assertVal[1] : null,
          ))(pos0, result0[1], result0[2]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiStep? _parseIndirectionStep() {
    dynamic result0, result1, result2;
    String? result3, result4;
    final int pos0 = pos, pos1 = pos;
    int pos2;

    if ((pos + 2) <= input.length && input.substring(pos, pos + 2) == '!/') {
      result0 = '!/';
      pos += 2;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('"!/"');
      }
    }
    if (result0 != null) {
      result1 = _parseInteger();
      if (result1 != null) {
        pos2 = pos;
        if (pos < input.length && input.codeUnitAt(pos) == 91) {
          result2 = '[';
          pos++;
        } else {
          result2 = null;
          if (reportFailures == 0) {
            _matchFailed('"["');
          }
        }
        if (result2 != null) {
          result3 = _parseIdAssertion();
          if (result3 != null) {
            if (pos < input.length && input.codeUnitAt(pos) == 93) {
              result4 = ']';
              pos++;
            } else {
              result4 = null;
              if (reportFailures == 0) {
                _matchFailed('"]"');
              }
            }
            if (result4 != null) {
              result2 = [result2, result3, result4];
            } else {
              result2 = null;
              pos = pos2;
            }
          } else {
            result2 = null;
            pos = pos2;
          }
        } else {
          result2 = null;
          pos = pos2;
        }
        result2 = result2 ?? '';
        if (result2 != null) {
          result0 = [result0, result1, result2];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((int offset, String stepLengthVal, assertVal) => CfiStep(
            type: 'indirectionStep',
            stepLength: int.parse(stepLengthVal),
            idAssertion: assertVal is List && assertVal.length > 1 ? assertVal[1] : null,
          ))(pos0, result0[1], result0[2]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiTerminus? _parseTerminus() {
    dynamic result0, result1, result2, result3;
    String? result4;
    final int pos0 = pos, pos1 = pos;
    int pos2;

    if (pos < input.length && input.codeUnitAt(pos) == 58) {
      result0 = ':';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('":"');
      }
    }
    if (result0 != null) {
      result1 = _parseInteger();
      if (result1 != null) {
        pos2 = pos;
        if (pos < input.length && input.codeUnitAt(pos) == 91) {
          result2 = '[';
          pos++;
        } else {
          result2 = null;
          if (reportFailures == 0) {
            _matchFailed('"["');
          }
        }
        if (result2 != null) {
          result3 = _parseTextLocationAssertion();
          if (result3 != null) {
            if (pos < input.length && input.codeUnitAt(pos) == 93) {
              result4 = ']';
              pos++;
            } else {
              result4 = null;
              if (reportFailures == 0) {
                _matchFailed('"]"');
              }
            }
            if (result4 != null) {
              result2 = [result2, result3, result4];
            } else {
              result2 = null;
              pos = pos2;
            }
          } else {
            result2 = null;
            pos = pos2;
          }
        } else {
          result2 = null;
          pos = pos2;
        }
        result2 = result2 ?? '';
        if (result2 != null) {
          result0 = [result0, result1, result2];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((int offset, String textOffsetValue, textLocAssertVal) => CfiTerminus(
            type: 'textTerminus',
            offsetValue: int.parse(textOffsetValue),
            textAssertion: (textLocAssertVal is List && textLocAssertVal.isNotEmpty) ? textLocAssertVal[1] : null,
          ))(pos0, result0[1], result0[2]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseIdAssertion() {
    String? result0;
    final int pos0 = pos;

    result0 = _parseValue();
    if (result0 != null) {
      result0 = ((offset, idVal) => idVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiTextLocationAssertion _parseTextLocationAssertion() {
    dynamic result0, result1;
    final int pos0 = pos, pos1 = pos;

    result0 = _parseCsv();
    result0 = result0 ?? CfiCsv(type: 'csv', preAssertion: null, postAssertion: null);
    if (result0 != null) {
      result1 = _parseParameter();
      result1 = result1 ?? CfiParameter(type: 'parameter', lHSValue: null, rHSValue: null);
      if (result1 != null) {
        result0 = [result0, result1];
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((int offset, CfiCsv? csvVal, CfiParameter? paramVal) => CfiTextLocationAssertion(
            type: 'textLocationAssertion',
            csv: csvVal,
            parameter: paramVal,
          ))(pos0, result0[0], result0[1]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiParameter? _parseParameter() {
    dynamic result0;
    String? result1, result2, result3;
    final int pos0 = pos, pos1 = pos;

    if (pos < input.length && input.codeUnitAt(pos) == 59) {
      result0 = ';';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('";"');
      }
    }
    if (result0 != null) {
      result1 = _parseValueNoSpace();
      if (result1 != null) {
        if (pos < input.length && input.codeUnitAt(pos) == 61) {
          result2 = '=';
          pos++;
        } else {
          result2 = null;
          if (reportFailures == 0) {
            _matchFailed('"="');
          }
        }
        if (result2 != null) {
          result3 = _parseValueNoSpace();
          if (result3 != null) {
            result0 = [result0, result1, result2, result3];
          } else {
            result0 = null;
            pos = pos1;
          }
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((offset, paramLHSVal, paramRHSVal) => CfiParameter(
            type: 'parameter',
            lHSValue: paramLHSVal,
            rHSValue: paramRHSVal,
          ))(pos0, result0[1], result0[3]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  CfiCsv _parseCsv() {
    dynamic result0;
    String? result1, result2;
    final int pos0 = pos, pos1 = pos;

    result0 = _parseValue();
    result0 = result0 ?? '';

    if (result0 != null) {
      if (pos < input.length && input.codeUnitAt(pos) == 44) {
        result1 = ',';
        pos++;
      } else {
        result1 = null;
        if (reportFailures == 0) {
          _matchFailed('","');
        }
      }

      result1 = result1 ?? '';
      result2 = _parseValue() ?? '';
      result0 = [result0, result1, result2];
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 != null) {
      result0 = ((offset, preAssertionVal, postAssertionVal) => CfiCsv(
            type: 'csv',
            preAssertion: preAssertionVal,
            postAssertion: postAssertionVal,
          ))(pos0, result0[0], result0[2]);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseValueNoSpace() {
    dynamic result0;
    String? result1;
    final int pos0 = pos;

    result1 = _parseEscapedSpecialChars();
    result1 ??= _parseCharacter();
    if (result1 != null) {
      result0 = <String>[];
      while (result1 != null) {
        result0.add(result1);
        result1 = _parseEscapedSpecialChars();
        result1 ??= _parseCharacter();
      }
    } else {
      result0 = null;
    }
    if (result0 != null) {
      result0 = ((offset, stringVal) => (stringVal as List).join(''))(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseValue() {
    dynamic result0;
    String? result1;
    final int pos0 = pos;

    result1 = _parseEscapedSpecialChars();
    if (result1 == null) {
      result1 = _parseCharacter();
      result1 ??= _parseSpace();
    }
    if (result1 != null) {
      result0 = <String>[];
      while (result1 != null) {
        result0.add(result1);
        result1 = _parseEscapedSpecialChars();
        if (result1 == null) {
          result1 = _parseCharacter();
          result1 ??= _parseSpace();
        }
      }
    } else {
      result0 = null;
    }
    if (result0 != null) {
      result0 = ((offset, stringVal) => (stringVal as List).join(''))(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseEscapedSpecialChars() {
    dynamic result0;
    String? result1;
    int pos0, pos1;

    pos0 = pos;
    pos1 = pos;
    result0 = _parseCircumflex();
    if (result0 != null) {
      result1 = _parseCircumflex();
      if (result1 != null) {
        result0 = [result0, result1];
      } else {
        result0 = null;
        pos = pos1;
      }
    } else {
      result0 = null;
      pos = pos1;
    }
    if (result0 == null) {
      pos1 = pos;
      result0 = _parseCircumflex();
      if (result0 != null) {
        result1 = _parseSquareBracket();
        if (result1 != null) {
          result0 = [result0, result1];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    }
    if (result0 == null) {
      pos1 = pos;
      result0 = _parseCircumflex();
      if (result0 != null) {
        result1 = _parseParentheses();
        if (result1 != null) {
          result0 = [result0, result1];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    }
    if (result0 == null) {
      pos1 = pos;
      result0 = _parseCircumflex();
      if (result0 != null) {
        result1 = _parseComma();
        if (result1 != null) {
          result0 = [result0, result1];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    }
    if (result0 == null) {
      pos1 = pos;
      result0 = _parseCircumflex();
      if (result0 != null) {
        result1 = _parseSemicolon();
        if (result1 != null) {
          result0 = [result0, result1];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    }
    if (result0 == null) {
      pos1 = pos;
      result0 = _parseCircumflex();
      if (result0 != null) {
        result1 = _parseEqual();
        if (result1 != null) {
          result0 = [result0, result1];
        } else {
          result0 = null;
          pos = pos1;
        }
      } else {
        result0 = null;
        pos = pos1;
      }
    }
    if (result0 != null) {
      result0 = ((offset, escVal) => escVal[1])(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseNumber() {
    dynamic result0, result1;
    final int pos0 = pos;

    result1 = _parseInteger();
    if (result1 != null) {
      result0 = <String>[];
      while (result1 != null) {
        result0.add(result1);
        result1 = _parseInteger();
      }
    } else {
      result0 = null;
    }
    if (result0 != null) {
      result0 = ((offset, intVal) => (intVal as List).join(''))(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseInteger() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && RegExp(r'^[0-9]').hasMatch(input[pos])) {
      result0 = input[pos];
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('[0-9]');
      }
    }
    if (result0 != null) {
      result0 = ((offset, digitVal) => digitVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseSpace() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && input.codeUnitAt(pos) == 32) {
      result0 = ' ';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('" "');
      }
    }
    if (result0 != null) {
      result0 = ((offset, spaceVal) => spaceVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseCircumflex() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && input.codeUnitAt(pos) == 94) {
      result0 = '^';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('"^"');
      }
    }
    if (result0 != null) {
      result0 = ((offset, circumflexVal) => circumflexVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseDoubleQuote() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && input.codeUnitAt(pos) == 34) {
      result0 = '"';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('"\\""');
      }
    }
    if (result0 != null) {
      result0 = ((offset, dquoteVal) => dquoteVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseSquareBracket() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && (input.codeUnitAt(pos) == 91 || input.codeUnitAt(pos) == 93)) {
      result0 = input[pos];
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('[\\[\\]]');
      }
    }
    if (result0 != null) {
      result0 = ((offset, bracketVal) => bracketVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseParentheses() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && (input.codeUnitAt(pos) == 40 || input.codeUnitAt(pos) == 41)) {
      result0 = input[pos];
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('[()]');
      }
    }
    if (result0 != null) {
      result0 = ((offset, paraVal) => paraVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseComma() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && input.codeUnitAt(pos) == 44) {
      result0 = ',';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('","');
      }
    }
    if (result0 != null) {
      result0 = ((offset, commaVal) => commaVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseSemicolon() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && input.codeUnitAt(pos) == 59) {
      result0 = ';';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('";"');
      }
    }
    if (result0 != null) {
      result0 = ((offset, semicolonVal) => semicolonVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseEqual() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && input.codeUnitAt(pos) == 61) {
      result0 = '=';
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('"="');
      }
    }
    if (result0 != null) {
      result0 = ((offset, equalVal) => equalVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }

  String? _parseCharacter() {
    String? result0;
    final int pos0 = pos;

    if (pos < input.length && RegExp(r'^[a-zA-Z0-9_\-]').hasMatch(input[pos])) {
      result0 = input[pos];
      pos++;
    } else {
      result0 = null;
      if (reportFailures == 0) {
        _matchFailed('[a-zA-Z0-9_\\-]');
      }
    }
    if (result0 != null) {
      result0 = ((offset, charVal) => charVal)(pos0, result0);
    }
    if (result0 == null) {
      pos = pos0;
    }
    return result0;
  }
}

class EpubCfiGenerator {
  const EpubCfiGenerator();

  String generateCompleteCFI(List<String?> entries) => 'epubcfi(${entries.where((e) => e != null).join()})';

  Future<String> generatePackageDocumentCFIComponent(EpubChapter chapter, EpubPackage? packageDocument) async {
    validatePackageDocument(packageDocument, chapter.Anchor);

    final index = getIdRefIndex(chapter, packageDocument!);
    final pos = getIdRefPosition(index);
    final spineIdRef = index >= 0 ? packageDocument.Spine!.Items![index].IdRef : chapter.Anchor;

    return '/6/$pos[$spineIdRef]!';
  }

  String generateElementCFIComponent(Node? startElement) {
    validateStartElement(startElement);

    final contentDocCFI = createCFIElementSteps(startElement as Element, 'html');

    return contentDocCFI.substring(1, contentDocCFI.length);
  }

  String createCFIElementSteps(Element currentNode, String topLevelElement) {
    int currentNodePosition = 0;

    int index = 0;
    if (currentNode.parent != null) {
      for (var node in currentNode.parent!.children) {
        if (node == currentNode) {
          currentNodePosition = index;
        }
        index++;
      }
    }

    final int cfiPosition = (currentNodePosition + 1) * 2;
    String elementStep;

    if (currentNode.attributes.containsKey('id')) {
      elementStep = '/$cfiPosition[${currentNode.attributes['id']!}]';
    } else {
      elementStep = '/$cfiPosition';
    }

    final parentNode = currentNode.parent;
    if (parentNode == null || parentNode.localName == topLevelElement || currentNode.localName == topLevelElement) {
      if (topLevelElement == 'html') {
        return '!$elementStep';
      } else {
        return elementStep;
      }
    } else {
      return createCFIElementSteps(parentNode, topLevelElement) + elementStep;
    }
  }

  int getIdRefIndex(EpubChapter chapter, EpubPackage packageDocument) {
    final items = packageDocument.Spine?.Items ?? [];
    int index = -1;
    int partIndex = -1;
    String? edRef = chapter.Anchor;

    if (chapter.Anchor == null && chapter.ContentFileName != null) {
      edRef = _fileNameAsChapterName(chapter.ContentFileName!);
    }

    for (var i = 0; i < items.length; i++) {
      if (edRef != null && edRef == items[i].IdRef) {
        index = i;
        break;
      }
      if (edRef != null && items[i].IdRef != null && items[i].IdRef!.contains(edRef)) {
        partIndex = i;
      }
    }

    return index >= 0 ? index : partIndex;
  }

  int getIdRefPosition(int idRefIndex) => (idRefIndex + 1) * 2;

  void validatePackageDocument(EpubPackage? packageDocument, String? idRef) {
    if (packageDocument == null) {
      throw Exception('A package document must be supplied to generate a CFI');
    }
  }

  void validateStartElement(Node? startElement) {
    if (startElement == null) {
      throw Exception('$startElement: CFI target element is null');
    }

    if (startElement.nodeType != Node.ELEMENT_NODE) {
      throw Exception('$startElement: CFI target element is not an HTML element');
    }
  }

  String _fileNameAsChapterName(String path) => path.split('/').last.replaceFirst(RegExp(r'\.[^.]+$'), '');
}

class EpubCfiInterpreter {
  Element? searchLocalPathForHref(Element? htmlElement, CfiLocalPath localPathNode) {
    if (localPathNode.steps == null || localPathNode.steps!.isEmpty) {
      return htmlElement;
    }
    CfiStep nextStepNode;
    Element? currentElement = htmlElement;

    for (int stepNum = 1; stepNum < localPathNode.steps!.length; stepNum++) {
      nextStepNode = localPathNode.steps![stepNum];
      if (nextStepNode.type == 'indexStep') {
        currentElement = interpretIndexStepNode(nextStepNode, currentElement);
      } else if (nextStepNode.type == 'indirectionStep') {
        currentElement = interpretIndirectionStepNode(nextStepNode, currentElement);
      }
    }

    return currentElement;
  }

  Element? interpretIndexStepNode(CfiStep? indexStepNode, Element? currentElement) {
    if (indexStepNode == null || indexStepNode.type != 'indexStep') {
      throw Exception('$indexStepNode: expected index step node');
    }

    final stepTarget = _getNextNode(indexStepNode.stepLength, currentElement);

    if ((indexStepNode.idAssertion ?? '').isNotEmpty) {
      if (stepTarget != null && !_targetIdMatchesIdAssertion(stepTarget, indexStepNode.idAssertion)) {
        throw Exception('${indexStepNode.idAssertion}: ${stepTarget.attributes['id']} Id assertion failed');
      }
    }

    return stepTarget;
  }

  Element? interpretIndirectionStepNode(CfiStep? indirectionStepNode, Element? currentElement) {
    if (indirectionStepNode == null || indirectionStepNode.type != 'indirectionStep') {
      throw Exception('$indirectionStepNode: expected indirection step node');
    }

    final stepTarget = _getNextNode(indirectionStepNode.stepLength, currentElement);

    if (indirectionStepNode.idAssertion != null) {
      if (stepTarget != null && !_targetIdMatchesIdAssertion(stepTarget, indirectionStepNode.idAssertion)) {
        throw Exception('${indirectionStepNode.idAssertion}: ${stepTarget.attributes['id']} Id assertion failed');
      }
    }

    return stepTarget;
  }

  bool _targetIdMatchesIdAssertion(Element foundNode, String? idAssertion) =>
      foundNode.attributes.containsKey('id') && foundNode.attributes['id'] == idAssertion;

  Element? _getNextNode(int cfiStepValue, Element? currentNode) {
    if (cfiStepValue % 2 == 0 && currentNode != null) {
      return _elementNodeStep(cfiStepValue, currentNode);
    }
    return null;
  }

  Element _elementNodeStep(int cfiStepValue, Element currentNode) {
    final int targetNodeIndex = ((cfiStepValue / 2) - 1).toInt();
    final int numElements = currentNode.children.length;

    if (targetNodeIndex < 0 || targetNodeIndex >= numElements) {
      return currentNode;
    }

    return currentNode.children[targetNodeIndex];
  }
}
