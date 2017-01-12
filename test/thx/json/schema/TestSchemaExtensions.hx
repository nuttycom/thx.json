package thx.json.schema;

import utest.Assert;

import haxe.ds.Option;
import haxe.Json;
import thx.Either;
using thx.Bools;

import thx.json.JValue;
import thx.json.JValue.*;
import thx.json.JValue.JPath.*;
import thx.json.JValue.JSearch;
using thx.json.schema.SchemaExtensions;

import thx.schema.SchemaF;
import thx.schema.SchemaDSL.*;
import thx.schema.SimpleSchema;
import thx.schema.SimpleSchema.*;
using thx.schema.SchemaFExtensions;


class TSimple {
  public var x: Int;

  public function new(x: Int) {
    this.x = x;
  }

  public static var schema(default, never): Schema<String, TSimple> = 
    object(required("x", int(), function(ts: TSimple) return ts.x).map(TSimple.new));
}

enum TEnum {
  A;
  B;
  C;
}

class TEnums {
  public static var eq(default, never) = function (e0: TEnum, e1: TEnum) return e0 == e1;

  public static var schema: Schema<String, TEnum> = oneOf([
    constAlt("a", A, eq),
    constAlt("b", B, eq),
    constAlt("c", C, eq)
  ]);
}

enum TSum {
  EX(o: TSimple);
  EY(s: String);
  EZ;
}

class TSums {
  public static var schema: Schema<String, TSum> = oneOf([
    alt("ex", TSimple.schema, function(s) return EX(s), function(e: TSum) return switch e { case EX(s): Some(s); case _: None; }),
    alt("ey", string(),       function(s) return EY(s), function(e: TSum) return switch e { case EY(s): Some(s); case _: None; }),
    alt("ez", constant(EZ), function(s) return EZ   , function(e: TSum) return switch e { case EZ:    Some(null); case _: None; })
  ]);
}

class TComplex {
  public var i: Int;
  public var f: Float;
  public var b: Bool;
  public var a: Array<TSimple>;
  public var e: Option<TSum>;

  public function new(i: Int, f: Float, b: Bool, a: Array<TSimple>, e: Option<TSum>) {
    this.i = i; 
    this.f = f;
    this.b = b;
    this.a = a;
    this.e = e;
  }

  public static var schema(default, never): Schema<String, TComplex> = object(
    ap5(
      TComplex.new,
      required("i", int(), function(tc: TComplex) return tc.i), 
      required("f", float(), function(tc: TComplex) return tc.f), 
      required("b", bool(), function(tc: TComplex) return tc.b), 
      required("a", array(TSimple.schema), function(tc: TComplex) return tc.a), 
      optional("e", TSums.schema, function(tc: TComplex) return tc.e)
    )
  );
}

class TestSchemaExtensions {
  public function new() { }

  public function testRender() {
    var rendered = TComplex.schema.renderJSON(new TComplex(1, 2, true, [new TSimple(3), new TSimple(4)], Some(EX(new TSimple(5)))));
    var path = JPath.root / "a" * 1 / "x";
    Assert.same(Right(JNum(4.0)), rendered.get(path));
  }

  public function testOneOf() {
    var rendered = TEnums.schema.renderJSON(B);
    var parsed = TEnums.schema.parseJSON(rendered);
    Assert.same(Right(B), parsed);
  }
}

