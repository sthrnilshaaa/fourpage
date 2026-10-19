import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:xml/xml_events.dart' as xmle;

void defaultLinksCallback(String link) {}

class HTML {
  static TextSpan toTextSpan(
    BuildContext context,
    String htmlContent, {
    Function linksCallback = defaultLinksCallback,
    TextStyle? defaultStyle,
  }) {
    final parser = HtmlParserInternal(
      context,
      htmlContent,
      linksCallback: linksCallback,
      defaultStyle: defaultStyle,
    );
    return TextSpan(text: "", children: parser.parse());
  }

  static RichText toRichText(
    BuildContext context,
    String htmlContent, {
    Function linksCallback = defaultLinksCallback,
    TextStyle? defaultStyle,
  }) {
    return RichText(
      text: toTextSpan(
        context,
        htmlContent,
        linksCallback: linksCallback,
        defaultStyle: defaultStyle,
      ),
    );
  }
}

class _Tag {
  String name;
  String styles;

  _Tag(this.name, this.styles);
}

class HtmlParserInternal {
  final _stack = [];
  dynamic _events;
  late Function _linksCallback;
  final TextStyle? _defaultStyle;

  HtmlParserInternal(
    BuildContext context,
    String data, {
    Function linksCallback = defaultLinksCallback,
    TextStyle? defaultStyle,
  }) : _defaultStyle = defaultStyle {
    final unescapedData = HtmlUnescape().convert(data);
    _events = xmle.parseEvents(unescapedData);
    _linksCallback = linksCallback;
  }

  TextSpan _getTextSpan(String text, String style) {
    var rules = style.split(";").where((item) => item.trim().isNotEmpty);
    TextStyle textStyle = _defaultStyle ?? const TextStyle(color: Color(0xff000000));

    var isLink = false;
    var link = "";
    for (String rule in rules) {
      if (!rule.contains(":")) continue;
      final parts = rule.split(":");
      String name = parts[0].trim();
      String value = parts[1].trim();
      switch (name) {
        case "color":
          textStyle = StyleGenUtils.addFontColor(textStyle, value);
          break;
        case "background":
          textStyle = StyleGenUtils.addBgColor(textStyle, value);
          break;
        case "font-weight":
          textStyle = StyleGenUtils.addFontWeight(textStyle, value);
          break;
        case "font-style":
          textStyle = StyleGenUtils.addFontStyle(textStyle, value);
          break;
        case "font-size":
          textStyle = StyleGenUtils.addFontSize(textStyle, value);
          break;
        case "text-decoration":
          textStyle = StyleGenUtils.addTextDecoration(textStyle, value);
          break;
        case "font-family":
          textStyle = StyleGenUtils.addFontFamily(textStyle, value);
          break;
        case "visit_link":
          isLink = true;
          link = TextGenUtils.getLink(value);
          break;
      }
    }

    if (isLink) {
      return TextSpan(
        style: textStyle,
        text: text,
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            _linksCallback(link);
          },
      );
    }
    return TextSpan(style: textStyle, text: text);
  }

  TextSpan _handleText(String text) {
    text = TextGenUtils.strip(text);
    if (text.isEmpty) return const TextSpan(text: "");
    var style = "";
    for (var tag in _stack) {
      style += "${tag.styles};";
    }
    return _getTextSpan(text, style);
  }

  List<TextSpan> parse() {
    List<TextSpan> spans = List.empty(growable: true);
    _events.forEach((event) {
      if (event is xmle.XmlStartElementEvent) {
        if (!event.isSelfClosing) {
          var styles = "";
          if (event.name == 'b' || event.name == 'strong' || event.name == 'th') {
            styles = "font-weight: bold;";
          } else if (event.name == 'i' ||
              event.name == 'em' ||
              event.name == 'cite' ||
              event.name == 'dfn' ||
              event.name == 'var' ||
              event.name == 'address') {
            styles = "font-style: italic;";
          } else if (event.name == 'u') {
            styles = "text-decoration: underline;";
          } else if (event.name == 'strike' ||
              event.name == 'del' ||
              event.name == 's') {
            styles = "text-decoration: line-through;";
          } else if (event.name == 'h1') {
            styles = "font-weight: bold; font-size: 1.85em;";
          } else if (event.name == 'h2') {
            styles = "font-weight: bold; font-size: 1.5em;";
          } else if (event.name == 'h3') {
            styles = "font-weight: bold; font-size: 1.25em;";
          } else if (event.name == 'h4') {
            styles = "font-weight: bold; font-size: 1.1em;";
          } else if (event.name == 'h5') {
            styles = "font-weight: bold; font-size: 1.0em;";
          } else if (event.name == 'h6') {
            styles = "font-weight: bold; font-size: 0.9em;";
          } else if (event.name == 'a') {
            styles = "visit_link:__#TO_GET#__;text-decoration: underline; color: #0000ff";
          } else if (event.name == 'blockquote') {
            styles = "font-style: italic;";
          } else if (event.name == 'code' ||
              event.name == 'kbd' ||
              event.name == 'samp' ||
              event.name == 'pre') {
            styles = "font-family: monospace;";
          } else if (event.name == 'small') {
            styles = "font-size: 0.8em;";
          } else if (event.name == 'sub' || event.name == 'sup') {
            styles = "font-size: 0.75em;";
          }

          if (event.name == 'tgYellow') {
            styles = 'background:#FFFF00';
          } else if (event.name == 'tgCyan') {
            styles = 'background:#00FFFF';
          } else if (event.name == 'tgPink') {
            styles = 'background:#FF69B4';
          } else if (event.name == 'tgGreen') {
            styles = 'background:#90EE90';
          } else if (event.name == 'tgOrange') {
            styles = 'background:#FFA07A';
          } else if (event.name == 'tgLilac') {
            styles = 'background:#DDA0DD';
          }

          for (var attribute in event.attributes) {
            if (attribute.name == "style") {
              styles = "$styles;${attribute.value}";
            } else if (attribute.name == "href") {
              styles = styles.replaceFirst(
                r"__#TO_GET#__",
                attribute.value.replaceAll(r":", "__#COLON#__"),
              );
            }
          }

          _stack.add(_Tag(event.name, styles));
        } else {
          if (event.name == "br") {
            spans.add(const TextSpan(text: "\n"));
          }
        }
      }

      if (event is xmle.XmlEndElementEvent) {
        dynamic top;
        if (_stack.isNotEmpty) {
          top = _stack.removeLast();
        }
        if (top != null && top.name != event.name) {
          return;
        }
        if (event.name == "p" ||
            event.name == "h1" ||
            event.name == "h2" ||
            event.name == "h3" ||
            event.name == "h4" ||
            event.name == "h5" ||
            event.name == "h6" ||
            event.name == "blockquote") {
          spans.add(const TextSpan(text: "\n"));
        }
      }

      if (event is xmle.XmlTextEvent) {
        final currentSpan = _handleText(event.value);
        if (currentSpan.text != null && currentSpan.text!.isNotEmpty) {
          spans.add(currentSpan);
        }
      }
    });

    return spans;
  }
}

class TextGenUtils {
  static String strip(String text) {
    var hasSpaceAfter = false;
    var hasSpaceBefore = false;
    if (text.startsWith(" ")) {
      hasSpaceBefore = true;
    }
    if (text.endsWith(" ")) {
      hasSpaceAfter = true;
    }
    text = text.trim();
    if (hasSpaceBefore) text = " $text";
    if (hasSpaceAfter) text = "$text ";
    return text;
  }

  static String getLink(String value) {
    return value.replaceAll(r"__#COLON#__", ":");
  }
}

class StyleGenUtils {
  static TextStyle addFontWeight(TextStyle textStyle, String value) {
    final cleanValue = value.toLowerCase().trim();
    final List<String> supportedNumValues = [
      "100", "200", "300", "400", "500", "600", "700", "800", "900"
    ];
    if (supportedNumValues.contains(cleanValue)) {
      return textStyle.copyWith(
        fontWeight: FontWeight.values[supportedNumValues.indexOf(cleanValue)],
      );
    }
    switch (cleanValue) {
      case "normal":
        return textStyle.copyWith(fontWeight: FontWeight.normal);
      case "bold":
      case "bolder":
        return textStyle.copyWith(fontWeight: FontWeight.bold);
      case "lighter":
        return textStyle.copyWith(fontWeight: FontWeight.w300);
      default:
        return textStyle;
    }
  }

  static int _convertColor(String value) {
    var colorHex = 0xff000000;
    if (value.startsWith("#")) {
      if (value.length == 7) {
        colorHex = int.parse(value.replaceAll(r"#", "0xff"));
      } else if (value.length == 9) {
        colorHex = int.parse(value.replaceAll(r"#", "0x"));
      } else if (value.length == 4) {
        value = value.replaceFirst(r"#", "");
        value = value.split("").map((c) => "$c$c").join();
        colorHex = int.parse("0xff$value");
      }
    } else {
      value = value.toLowerCase();
      if (CSSColors.values.containsKey(value) && CSSColors.values[value] != null) {
        return CSSColors.values[value]!;
      }
    }
    return colorHex;
  }

  static TextStyle addFontColor(TextStyle textStyle, String value) {
    return textStyle.copyWith(color: Color(_convertColor(value)));
  }

  static TextStyle addBgColor(TextStyle textStyle, String value) {
    Paint p = Paint();
    p.color = Color(_convertColor(value));
    return textStyle.copyWith(background: p);
  }

  static TextStyle addFontStyle(TextStyle textStyle, String value) {
    final cleanValue = value.toLowerCase().trim();
    if (cleanValue == "italic" || cleanValue == "oblique") {
      return textStyle.copyWith(fontStyle: FontStyle.italic);
    } else if (cleanValue == "normal") {
      return textStyle.copyWith(fontStyle: FontStyle.normal);
    }
    return textStyle;
  }

  static TextStyle addFontFamily(TextStyle textStyle, String value) {
    if (textStyle.fontFamily != null && textStyle.fontFamily!.isNotEmpty) {
      return textStyle;
    }
    return textStyle.copyWith(fontFamily: value);
  }

  static TextStyle addFontSize(TextStyle textStyle, String value) {
    final cleanValue = value.toLowerCase().trim();
    final baseFontSize = textStyle.fontSize ?? 16.0;
    double number = baseFontSize;

    try {
      if (cleanValue.endsWith("px")) {
        number = double.parse(cleanValue.replaceAll("px", "").trim());
      } else if (cleanValue.endsWith("rem")) {
        number = baseFontSize * double.parse(cleanValue.replaceAll("rem", "").trim());
      } else if (cleanValue.endsWith("em")) {
        number = baseFontSize * double.parse(cleanValue.replaceAll("em", "").trim());
      } else if (cleanValue.endsWith("%")) {
        final pct = double.parse(cleanValue.replaceAll("%", "").trim());
        number = baseFontSize * (pct / 100.0);
      } else if (cleanValue.endsWith("pt")) {
        final pt = double.parse(cleanValue.replaceAll("pt", "").trim());
        number = pt * 1.333; // 1pt = 1.333px in standard CSS
      } else {
        switch (cleanValue) {
          case "xx-small":
            number = baseFontSize * 0.6;
            break;
          case "x-small":
            number = baseFontSize * 0.75;
            break;
          case "small":
          case "smaller":
            number = baseFontSize * 0.85;
            break;
          case "medium":
            number = baseFontSize;
            break;
          case "large":
          case "larger":
            number = baseFontSize * 1.2;
            break;
          case "x-large":
            number = baseFontSize * 1.5;
            break;
          case "xx-large":
            number = baseFontSize * 2.0;
            break;
          default:
            final parsed = double.tryParse(cleanValue);
            if (parsed != null) number = parsed;
            break;
        }
      }
    } catch (_) {
      number = baseFontSize;
    }

    return textStyle.copyWith(fontSize: number);
  }

  static TextStyle addTextDecoration(TextStyle textStyle, String value) {
    if (value.contains("underline")) {
      textStyle = textStyle.copyWith(decoration: TextDecoration.underline);
    }
    if (value.contains("overline")) {
      textStyle = textStyle.copyWith(decoration: TextDecoration.overline);
    }
    if (value.contains("none")) {
      return textStyle.copyWith(decoration: TextDecoration.none);
    }
    if (value.contains("line-through")) {
      textStyle = textStyle.copyWith(decoration: TextDecoration.lineThrough);
    }
    if (value.contains("dotted")) {
      textStyle = textStyle.copyWith(decorationStyle: TextDecorationStyle.dotted);
    } else if (value.contains("dashed")) {
      textStyle = textStyle.copyWith(decorationStyle: TextDecorationStyle.dashed);
    } else if (value.contains("wavy")) {
      textStyle = textStyle.copyWith(decorationStyle: TextDecorationStyle.wavy);
    }
    return textStyle;
  }
}

class CSSColors {
  static Map<String, int> values = {
    "aliceblue": 0xFFF0F8FF,
    "antiquewhite": 0xFFFAEBD7,
    "aqua": 0xFF00FFFF,
    "aquamarine": 0xFF7FFFD4,
    "azure": 0xFFF0FFFF,
    "beige": 0xFFF5F5DC,
    "bisque": 0xFFFFE4C4,
    "black": 0xFF000000,
    "blanchedalmond": 0xFFFFEBCD,
    "blue": 0xFF0000FF,
    "blueviolet": 0xFF8A2BE2,
    "brown": 0xFFA52A2A,
    "burlywood": 0xFFDEB887,
    "cadetblue": 0xFF5F9EA0,
    "chartreuse": 0xFF7FFF00,
    "chocolate": 0xFFD2691E,
    "coral": 0xFFFF7F50,
    "cornflowerblue": 0xFF6495ED,
    "cornsilk": 0xFFFFF8DC,
    "crimson": 0xFFDC143C,
    "cyan": 0xFF00FFFF,
    "darkblue": 0xFF00008B,
    "darkcyan": 0xFF008B8B,
    "darkgoldenrod": 0xFFB8860B,
    "darkgray": 0xFFA9A9A9,
    "darkgreen": 0xFF006400,
    "darkgrey": 0xFFA9A9A9,
    "darkkhaki": 0xFFBDB76B,
    "darkmagenta": 0xFF8B008B,
    "darkolivegreen": 0xFF556B2F,
    "darkorange": 0xFFFF8C00,
    "darkorchid": 0xFF9932CC,
    "darkred": 0xFF8B0000,
    "darksalmon": 0xFFE9967A,
    "darkseagreen": 0xFF8FBC8F,
    "darkslateblue": 0xFF483D8B,
    "darkslategray": 0xFF2F4F4F,
    "darkslategrey": 0xFF2F4F4F,
    "darkturquoise": 0xFF00CED1,
    "darkviolet": 0xFF9400D3,
    "deeppink": 0xFFFF1493,
    "deepskyblue": 0xFF00BFFF,
    "dimgray": 0xFF696969,
    "dimgrey": 0xFF696969,
    "dodgerblue": 0xFF1E90FF,
    "firebrick": 0xFFB22222,
    "floralwhite": 0xFFFFFAF0,
    "forestgreen": 0xFF228B22,
    "fuchsia": 0xFFFF00FF,
    "gainsboro": 0xFFDCDCDC,
    "ghostwhite": 0xFFF8F8FF,
    "gold": 0xFFFFD700,
    "goldenrod": 0xFFDAA520,
    "gray": 0xFF808080,
    "green": 0xFF008000,
    "greenyellow": 0xFFADFF2F,
    "grey": 0xFF808080,
    "honeydew": 0xFFF0FFF0,
    "hotpink": 0xFFFF69B4,
    "indianred": 0xFFCD5C5C,
    "indigo": 0xFF4B0082,
    "ivory": 0xFFFFFFF0,
    "khaki": 0xFFF0E68C,
    "lavender": 0xFFE6E6FA,
    "lavenderblush": 0xFFFFF0F5,
    "lawngreen": 0xFF7CFC00,
    "lemonchiffon": 0xFFFFFACD,
    "lightblue": 0xFFADD8E6,
    "lightcoral": 0xFFF08080,
    "lightcyan": 0xFFE0FFFF,
    "lightgoldenrodyellow": 0xFFFAFAD2,
    "lightgray": 0xFFD3D3D3,
    "lightgreen": 0xFF90EE90,
    "lightgrey": 0xFFD3D3D3,
    "lightpink": 0xFFFFB6C1,
    "lightsalmon": 0xFFFFA07A,
    "lightseagreen": 0xFF20B2AA,
    "lightskyblue": 0xFF87CEFA,
    "lightslategray": 0xFF778899,
    "lightslategrey": 0xFF778899,
    "lightsteelblue": 0xFFB0C4DE,
    "lightyellow": 0xFFFFFFE0,
    "lime": 0xFF00FF00,
    "limegreen": 0xFF32CD32,
    "linen": 0xFFFAF0E6,
    "magenta": 0xFFFF00FF,
    "maroon": 0xFF800000,
    "mediumaquamarine": 0xFF66CDAA,
    "mediumblue": 0xFF0000CD,
    "mediumorchid": 0xFFBA55D3,
    "mediumpurple": 0xFF9370DB,
    "mediumseagreen": 0xFF3CB371,
    "mediumslateblue": 0xFF7B68EE,
    "mediumspringgreen": 0xFF00FA9A,
    "mediumturquoise": 0xFF48D1CC,
    "mediumvioletred": 0xFFC71585,
    "midnightBlue": 0xFF191970,
    "mintcream": 0xFFF5FFFA,
    "mistyrose": 0xFFFFE4E1,
    "moccasin": 0xFFFFE4B5,
    "navajowhite": 0xFFFFDEAD,
    "navy": 0xFF000080,
    "oldlace": 0xFFFDF5E6,
    "olive": 0xFF808000,
    "olivedrab": 0xFF6B8E23,
    "orange": 0xFFFFA500,
    "orangered": 0xFFFF4500,
    "orchid": 0xFFDA70D6,
    "palegoldenrod": 0xFFEEE8AA,
    "palegreen": 0xFF98FB98,
    "paleturquoise": 0xFFAFEEEE,
    "palevioletred": 0xFFDB7093,
    "papayawhip": 0xFFFFEFD5,
    "peachpuff": 0xFFFFDAB9,
    "peru": 0xFFCD853F,
    "pink": 0xFFFFC0CB,
    "plum": 0xFFDDA0DD,
    "powderblue": 0xFFB0E0E6,
    "purple": 0xFF800080,
    "rebeccapurple": 0xFF663399,
    "red": 0xFFFF0000,
    "rosybrown": 0xFFBC8F8F,
    "royalblue": 0xFF4169E1,
    "saddlebrown": 0xFF8B4513,
    "salmon": 0xFFFA8072,
    "sandybrown": 0xFFF4A460,
    "seagreen": 0xFF2E8B57,
    "seashell": 0xFFFFF5EE,
    "sienna": 0xFFA0522D,
    "silver": 0xFFC0C0C0,
    "skyblue": 0xFF87CEEB,
    "slateblue": 0xFF6A5ACD,
    "slategray": 0xFF708090,
    "slategrey": 0xFF708090,
    "snow": 0xFFFFFAFA,
    "springgreen": 0xFF00FF7F,
    "steelblue": 0xFF4682B4,
    "tan": 0xFFD2B48C,
    "teal": 0xFF008080,
    "thistle": 0xFFD8BFD8,
    "tomato": 0xFFFF6347,
    "turquoise": 0xFF40E0D0,
    "violet": 0xFFEE82EE,
    "wheat": 0xFFF5DEB3,
    "white": 0xFFFFFFFF,
    "whitesmoke": 0xFFF5F5F5,
    "yellow": 0xFFFFFF00,
    "yellowgreen": 0xFF9ACD32
  };
}
