package thx.json;

import haxe.ds.Option;

using thx.Arrays;
using thx.Functions;
using thx.Maps;
using thx.Options;

typedef JAssoc = {
  name: String,
  value: JValue
};

enum JValueADT {
  JString(s: String);
  JNum(x: Float);
  JBool(b: Bool);
  JArray(xs: Array<JValue>);
  JObject(xs: Array<JAssoc>);
  JNull;
}

abstract JValue (JValueADT) from JValueADT to JValueADT {
  inline public static function jString(s: String): JValue return JString(s);
  inline public static function jNum(x: Float): JValue return JNum(x);
  inline public static function jBool(b: Bool): JValue return JBool(b);

  public static var jNull(get, null): JValue;
  inline static function get_jNull(): JValue return JNull;

  inline public static function jArray(xs: Array<JValue>): JValue
    return JArray(xs);

  public static function jObject(m: Map<String, JValue>): JValue
    return JObject(m.tuples().map(function(t) return { name: t._0, value: t._1 }));

  @:op(A / B)
  public function getProperty(name: String): JSearch return switch this {
    case JObject(xs): xs.findOption(function(a) return a.name == name).map(function(a) return a.value);
    case _: None;
  };

  @:arrayAccess
  public function getIndex(idx: Int): JSearch return switch this {
    case JArray(xs): if (xs.length > idx) Some(xs[idx]) else None;
    case _: None;
  };
}

abstract JSearch (Option<JValue>) from Option<JValue> to Option<JValue> {
  @:op(A / B)
  public function getProperty(name: String): JSearch 
    return this.flatMap(function(jv) return jv / name);

  @:arrayAccess
  public function getIndex(idx: Int): JSearch 
    return this.flatMap(function(jv) return jv[idx]);
}

