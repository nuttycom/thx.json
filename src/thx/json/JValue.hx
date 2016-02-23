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

enum JPathADT {
  Property(name: String, tail: JPath);
  Index(idx: Int, tail: JPath);
  Empty;
}

abstract JPath (JPathADT) from JPathADT to JPathADT {
  public function render(): String return switch this {
    case Property(name, xs): 
      if (xs == Empty) name else '${xs.render()}.$name';

    case Index(idx, xs):
      if (xs == Empty) '[$idx]' else '${xs.render()}[$idx]';

    case Empty: "";
  }

  public static var root(get, null): JPath;
  inline static function get_root(): JPath return Empty;

  @:op(A / B)
  public function property(name: String): JPath
    return Property(name, this);
  
  // fun fact: in haXe, multiplication and division have the same precedence,
  // and always associate to the left. So we can use * for array indexing,
  // and avoid a lot of spurious parentheses when creating complex paths.
  @:op(A * B)
  public function index(idx: Int): JPath
    return Index(idx, this);

  @:op(A + B)
  public function append(other: JPath): JPath return switch this {
    case Property(name, xs): Property(name, xs.append(other));
    case Index(idx, xs): Index(idx, xs.append(other));                             
    case Empty: this;
  }

  public function reverse(): JPath {
    function go(path: JPath, acc: JPath): JPath {
      return switch path {
        case Property(name, xs): go(xs, Property(name, acc));
        case Index(idx, xs): go(xs, Index(idx, acc));
        case Empty: acc;
      };
    }

    return go(this, Empty);
  }

  public function toString() {
    return switch this {
      case Property(name, xs): '${xs.toString()}/$name';
      case Index(idx, xs): '${xs.toString()}[$idx]';
      case Empty: "";
    };
  }
}

enum JPathError {
  NoSuchProperty(name: String, object: JValue);
  IndexOutOfRange(idx: Int, array: JValue);
  TypeMismatch(expected: JType, found: JValue);
}

class JPathErrorExtensions {
  public static function toString(error: JPathError): String return switch error {
    case NoSuchProperty(name, object):  'Property $name not found in object ${Render.renderUnsafe(object)}';
    case IndexOutOfRange(idx, array):   'Index $idx out of range in array ${Render.renderUnsafe(array)}';
    case TypeMismatch(expected, found): '${Render.renderUnsafe(found)} is not a value of type $expected';
  }
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

  public function get(path: JPath): Either<JSearchError, JValue> {
    return get_(path.reverse()).run();
  }

  @:op(A / B)
  public function prop(name: String): JSearch return {
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
  public function index(idx: Int): JSearch return {
    path: Index(idx, Empty),
    value: switch this {
      case JArray(xs): 
        if (idx >= 0 && xs.length > idx) Right(xs[idx]) else Left(IndexOutOfRange(idx, this));
      case other: 
        Left(TypeMismatch(JArrayT, other));
    }
  };

  @:op(A * B)
  inline public function altIndex(idx: Int): JSearch return index(idx);

  function get_(path: JPath): JSearch return switch path {
    case Property(name, xs): prop(name).flatMap(function(jv) return jv.get_(xs));
    case Index(idx, xs):     index(idx).flatMap(function(jv) return jv.get_(xs));
    case Empty:              { path: path, value: Right(this) };
  };

  public function toString() {
    return Render.renderUnsafe(this);
  }
}

abstract JSearch ({ path: JPath, value: Either<JPathError, JValue> }) from { path: JPath, value: Either<JPathError, JValue> } {
  inline public function repr(): { path: JPath, value: Either<JPathError, JValue> } return this;

  public function flatMap(f: JValue -> JSearch): JSearch return switch this.value {
    case Left(error): this;
    case Right(jv):   
      var next = f(jv);
      { path: this.path + next.repr().path, value: next.repr().value };
  };

  @:op(A / B)
  public function prop(name: String): JSearch return switch this.value {
    case Left(error): this;
    case Right(jv):   { path: Property(name, this.path), value: (jv / name).repr().value };
  };

  // fun fact: in haXe, multiplication and division have the same precedence,
  // and always associate to the left. So we can use * for array indexing,
  // and avoid a lot of spurious parentheses when creating complex paths.
  @:op(A * B)
  public function index(idx: Int): JSearch return switch this.value {
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
