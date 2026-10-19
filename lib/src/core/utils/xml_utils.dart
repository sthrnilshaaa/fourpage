/// XML parsing helper functions.
library;

import 'package:xml/xml.dart';

class XmlUtils {
  XmlUtils._();

  /// Gets the first child element matching local name, ignoring namespace prefix.
  static XmlElement? findDirectChild(XmlElement parent, String localName) {
    for (final child in parent.childElements) {
      if (child.name.local.toLowerCase() == localName.toLowerCase()) {
        return child;
      }
    }
    return null;
  }

  /// Finds all descendant elements matching local name, ignoring namespace prefix.
  static Iterable<XmlElement> findDescendants(XmlElement parent, String localName) {
    return parent.findAllElements('*').where(
      (element) => element.name.local.toLowerCase() == localName.toLowerCase(),
    );
  }

  /// Gets attribute value safely, case-insensitively checking attribute names.
  static String? getAttribute(XmlElement element, String attributeName) {
    for (final attr in element.attributes) {
      if (attr.name.local.toLowerCase() == attributeName.toLowerCase()) {
        return attr.value;
      }
    }
    return null;
  }

  /// Extracts text content of an element.
  static String getTextContent(XmlElement element) {
    return element.innerText.trim();
  }
}
