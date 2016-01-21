package thx.json;

import haxe.ds.Option;
import thx.Either;
import thx.json.schema.JType;

using thx.Arrays;
using thx.Eithers;
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

enum JPath {
  Property(name: String, tail: JPath);
  Index(idx: Int, tail: JPath);
  Empty;
}

enum JPathError {
  NoSuchProperty(name: String, object: JValue);
  IndexOutOfRange(idx: Int, array: JValue);
  TypeMismatch(expected: JType, found: JValue);
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
  public function getProperty(name: String): JSearch return {
    path : Property(name, Empty),
    value: switch this {
      case JObject(xs): 
        switch xs.findOption(function(a) return a.name == name) {
          case Some(a): Right(a.value);
          case None:    Left(NoSuchProperty(name, this));
        };

      case other: 
        Left(TypeMismatch(JObjT, other));
    }
  };

  @:arrayAccess
  public function getIndex(idx: Int): JSearch return {
    path: Index(idx, Empty),
    value: switch this {
      case JArray(xs): 
        if (idx >= 0 && xs.length > idx) Right(xs[idx]) else Left(IndexOutOfRange(idx, this));
      case other: 
        Left(TypeMismatch(JArrayT, other));
    }
  };
}

abstract JSearch ({ path: JPath, value: Either<JPathError, JValue> }) from { path: JPath, value: Either<JPathError, JValue> } {
  inline public function repr(): { path: JPath, value: Either<JPathError, JValue> } return this;

  @:op(A / B)
  public function getProperty(name: String): JSearch return switch this.value {
    case Left(error): this;
    case Right(jv):   { path: Property(name, this.path), value: (jv / name).repr().value };
  };

  @:arrayAccess
  public function getIndex(idx: Int): JSearch return switch this.value {
    case Left(error): this;
    case Right(jv):   { path: Index(idx, this.path), value: jv[idx].repr().value };
  };

  @:to
  public function run(): Either<JSearchError, JValue> 
    return this.value.leftMap(function(e) return { path: this.path, error: e });
}

typedef JSearchError = {
  path: JPath,
  error: JPathError
};
