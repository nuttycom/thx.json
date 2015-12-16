package thx.json;

import haxe.ds.Option;
import thx.json.JValue;

class Render {
  /**
   * Rendering of primitive JSON values (strings, numbers, 
   * booleans, and nulls) to JSON strings is undefined, 
   * thus this returns Option<String> to account for the
   * possibility that the rendering may be undefined.
   */
  public static function render(jv: JValue): Option<String> {
    return switch jv {
      case JArray(_) | JObject(_) : Some(renderUnsafe(jv));
      case _: None;
    };
  }

  /**
   * Render a JValue to a string that may or may not be a valid
   * JSON value. Use render instead unless you're using this for
   * lower-level tooling that doesn't actually involve the JSON spec.
   */
  public static function renderUnsafe(jv: JValue): String {
    function renderAssoc(a: JAssoc): String
      return '${a.name}:${renderUnsafe(a.value)}'; 

    return switch jv {
      case JString(s): quote(s);
      case JNum(x): Std.string(x);
      case JBool(b):   Std.string(b);
      case JArray(xs): '[${xs.map(renderUnsafe).join(",")}]';
      case JObject(xs): '{${xs.map(renderAssoc).join(",")}}';
      case JNull: "null";
    };
  }

  public static function quote(string: String): String {
    if (string == null || string.length == 0) {
      return "\"\"";
    }

    var sb = new StringBuf();
    sb.addChar(34); // leading "

    for (i in 0...string.length) {
      var c = string.charCodeAt(i);
      switch (c) {
      case 92 | 34 | 47: // [\"/]
        sb.add("\\");
        sb.addChar(c);
      case 8:  // \b
        sb.add("\\b");
      case 9: // \t
        sb.add("\\t");
      case 10: // \n
        sb.add("\\n");
      case 12: // \f
        sb.add("\\f");
      case 13: // \r
        sb.add("\\r");
      case _:
        if (c < 32) {
          sb.add('\\u${StringTools.hex(c, 4)}');
        } else {
          sb.addChar(c);
        }
      }
    }

    sb.addChar(34); // trailing "
    return sb.toString();
  }
}
